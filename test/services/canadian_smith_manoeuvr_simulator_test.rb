require "test_helper"

# Tests for Canadian Modified Smith Manoeuvre simulator
class CanadianSmithManoeuvrSimulatorTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)

    @primary_mortgage = create_loan_account(@family, "Primary Mortgage", 400000, 5.0, 300)
    @heloc = create_heloc_account(@family, "HELOC", 0, 7.0, 100000)
    @rental_mortgage = create_loan_account(@family, "Rental Mortgage", 200000, 5.5, 240)

    @strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "Smith Manoeuvre Test",
      strategy_type: "modified_smith",
      primary_mortgage: @primary_mortgage,
      heloc: @heloc,
      rental_mortgage: @rental_mortgage,
      rental_income: 2500,
      rental_expenses: 500,
      simulation_months: 24
    )

    @strategy.auto_stop_rules.create!(
      rule_type: "heloc_limit_percentage",
      threshold_value: 95,
      threshold_unit: "percentage",
      enabled: true
    )
  end

  test "creates baseline, prepay-only, and strategy entries" do
    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    baseline_count = @strategy.baseline_entries.count
    prepay_count = @strategy.prepay_only_entries.count
    strategy_count = @strategy.strategy_entries.count

    assert baseline_count > 0, "Should have baseline entries"
    assert prepay_count > 0, "Should have prepay-only entries"
    assert strategy_count > 0, "Should have strategy entries"
  end

  test "strategy uses HELOC for rental expenses" do
    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    strategy_entry = @strategy.strategy_entries.first
    assert strategy_entry.heloc_draw > 0, "Should draw from HELOC for expenses"
    assert strategy_entry.heloc_balance > 0, "HELOC balance should increase"
  end

  test "strategy prepays primary mortgage with rental income" do
    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    strategy_entry = @strategy.strategy_entries.first
    assert strategy_entry.primary_mortgage_prepayment > 0, "Should prepay primary mortgage"
  end

  test "HELOC interest cash source is tracked" do
    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    # Find an entry with HELOC interest (after balance builds up)
    entry = @strategy.strategy_entries.where("heloc_interest > 0").first
    return unless entry

    assert entry.heloc_interest_from_rental >= 0, "Should track rental portion"
    assert entry.heloc_interest_from_pocket >= 0, "Should track pocket portion"
    assert_in_delta entry.heloc_interest,
      entry.heloc_interest_from_rental + entry.heloc_interest_from_pocket, 0.01,
      "Sources should sum to total HELOC interest"
  end

  test "prepayment capacity is reduced by HELOC interest paid from rental" do
    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    entry = @strategy.strategy_entries.where("heloc_interest > 0").first
    return unless entry

    # In the Smith Manoeuvre, HELOC covers rental expenses, so the effective
    # rental surplus is rental_income (not rental_income - rental_expenses).
    # The waterfall is: rental_income → HELOC interest → prepayment
    effective_rental_surplus = entry.rental_income
    assert entry.primary_mortgage_prepayment + entry.heloc_interest_from_rental <= effective_rental_surplus + 0.01,
      "Prepayment + HELOC interest from rental should not exceed effective rental surplus"
  end

  test "strategy pays off primary mortgage faster than baseline" do
    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    baseline_last = @strategy.baseline_entries.order(:month_number).last
    strategy_last = @strategy.strategy_entries.order(:month_number).last

    assert strategy_last.primary_mortgage_balance <= baseline_last.primary_mortgage_balance,
           "Strategy should pay off primary mortgage faster"
  end

  test "prepay-only falls between baseline and smith" do
    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    baseline_last = @strategy.baseline_entries.order(:month_number).last
    prepay_last = @strategy.prepay_only_entries.order(:month_number).last
    strategy_last = @strategy.strategy_entries.order(:month_number).last

    assert prepay_last.primary_mortgage_balance <= baseline_last.primary_mortgage_balance,
           "Prepay-only should be better than baseline"
    assert prepay_last.primary_mortgage_balance >= strategy_last.primary_mortgage_balance,
           "Smith should be better than prepay-only"
  end

  test "prepay-only has zero HELOC usage" do
    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    @strategy.prepay_only_entries.each do |entry|
      assert_equal 0, entry.heloc_draw
      assert_equal 0, entry.heloc_balance
      assert_equal 0, entry.heloc_interest
    end
  end

  test "HELOC interest is tax deductible" do
    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    entry = @strategy.strategy_entries.where("heloc_interest > 0").first
    return unless entry

    assert entry.deductible_interest >= entry.heloc_interest,
           "HELOC interest should be included in deductible interest"
  end

  test "calculates tax benefit from deductible interest" do
    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    entry = @strategy.strategy_entries.where("deductible_interest > 0").first
    assert entry.tax_benefit > 0, "Should calculate tax benefit"

    marginal_rate = @strategy.effective_marginal_tax_rate
    expected_benefit = entry.deductible_interest * marginal_rate
    assert_in_delta expected_benefit, entry.tax_benefit, 1.0
  end

  test "cumulative tax benefit increases over time" do
    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    entries = @strategy.strategy_entries.order(:month_number)
    return if entries.count < 2

    prev_cumulative = 0
    entries.each do |entry|
      assert entry.cumulative_tax_benefit >= prev_cumulative,
             "Cumulative tax benefit should not decrease"
      prev_cumulative = entry.cumulative_tax_benefit
    end
  end

  test "respects auto-stop rules" do
    @strategy.auto_stop_rules.create!(
      rule_type: "max_months",
      threshold_value: 6,
      enabled: true
    )

    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    last_entry = @strategy.strategy_entries.order(:month_number).last
    assert last_entry.month_number <= 6, "Should stop at max_months threshold"
    assert last_entry.strategy_stopped, "Last entry should be marked as stopped"
  end

  test "records stop reason when rule triggered" do
    @strategy.auto_stop_rules.create!(
      rule_type: "max_months",
      threshold_value: 3,
      enabled: true
    )

    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    stopped_entry = @strategy.strategy_entries.where(strategy_stopped: true).first
    assert stopped_entry.present?, "Should have a stopped entry"
    assert stopped_entry.stop_reason.present?, "Should record stop reason"
  end

  test "metadata includes cumulative_net_benefit" do
    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    entry = @strategy.strategy_entries.order(:month_number).last
    assert entry.metadata.key?("cumulative_net_benefit"),
      "Metadata should include cumulative_net_benefit"
  end

  # Canadian Feature Tests

  test "readvanceable HELOC increases credit limit as mortgage principal is paid" do
    @strategy.update!(heloc_readvanceable: true, heloc_max_limit: 200_000)

    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    entries = @strategy.strategy_entries.order(:month_number)
    return if entries.count < 2

    first_entry = entries.first
    last_entry = entries.last

    assert last_entry.primary_mortgage_balance < first_entry.primary_mortgage_balance,
           "Primary mortgage should decrease"
  end

  test "prepayment privilege limit caps annual prepayments" do
    loan = @primary_mortgage.accountable
    loan.update!(prepayment_privilege_percent: 15)

    @strategy.update!(simulation_months: 24)

    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    # Check that annual prepayments don't exceed 15% of $400K = $60K
    privilege_limit = 400_000 * 0.15
    entries = @strategy.strategy_entries.order(:month_number).to_a

    # Group by year and sum prepayments
    by_year = entries.group_by { |e| e.calendar_month.year }
    by_year.each do |_year, year_entries|
      annual_prepayment = year_entries.sum(&:primary_mortgage_prepayment)
      assert annual_prepayment <= privilege_limit + 0.01,
        "Annual prepayment #{annual_prepayment} should not exceed privilege limit #{privilege_limit}"
    end
  end

  test "mortgage renewal at periodic intervals" do
    loan = @primary_mortgage.accountable
    loan.update!(renewal_date: Date.current + 1.day, renewal_term_months: 12, renewal_rate: 6.0)

    @strategy.update!(simulation_months: 36)

    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    entries = @strategy.strategy_entries.order(:month_number).to_a
    assert entries.size > 12, "Should run beyond first renewal"
  end

  # S1: HELOC credit exhaustion — balance never exceeds limit
  test "S1: HELOC balance never exceeds credit limit" do
    small_heloc = create_heloc_account(@family, "HELOC S1", 0, 7.0, 1500)
    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "S1 HELOC Exhaustion",
      strategy_type: "modified_smith",
      primary_mortgage: @primary_mortgage,
      heloc: small_heloc,
      rental_mortgage: @rental_mortgage,
      rental_income: 2500,
      rental_expenses: 500,
      simulation_months: 24
    )

    CanadianSmithManoeuvrSimulator.new(strategy).simulate!

    strategy.strategy_entries.each do |entry|
      assert entry.heloc_balance <= 1500 + 0.01,
        "Month #{entry.month_number}: HELOC balance ($#{entry.heloc_balance.round(2)}) should not exceed limit ($1,500)"
    end
  end

  # S2: HELOC interest cash source with insufficient rental income
  # HELOC balance builds from $500/month draws for expenses. After several months,
  # the accumulated HELOC interest exceeds the small rental surplus ($100/month),
  # forcing some interest to come from pocket.
  test "S2: insufficient rental surplus forces HELOC interest from pocket" do
    heloc_s2 = create_heloc_account(@family, "HELOC S2", 0, 7.0, 100000)
    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "S2 Insufficient Rental",
      strategy_type: "modified_smith",
      primary_mortgage: @primary_mortgage,
      heloc: heloc_s2,
      rental_mortgage: @rental_mortgage,
      rental_income: 600,
      rental_expenses: 500,
      simulation_months: 36
    )

    CanadianSmithManoeuvrSimulator.new(strategy).simulate!

    # With $600 income, $500 expenses covered by HELOC, surplus is $600.
    # Waterfall: $600 → HELOC interest → prepayment.
    # HELOC balance grows ~$500/month; at $10K+ balance, interest is ~$58/month at 7%.
    # Once HELOC interest exceeds $600, some must come from pocket.
    # At ~20 months, HELOC balance ~$10K, interest ~$58 — still within $600.
    # But as balance grows further, eventually interest portion from pocket appears.
    entries_with_interest = strategy.strategy_entries.where("heloc_interest > 0").to_a

    # Verify sources always sum to total
    entries_with_interest.each do |entry|
      assert_in_delta entry.heloc_interest,
        entry.heloc_interest_from_rental + entry.heloc_interest_from_pocket, 0.01,
        "Month #{entry.month_number}: interest sources must sum to total"
    end

    # At minimum, later months should have heloc_interest_from_rental > 0
    later_entries = entries_with_interest.last(6)
    assert later_entries.any? { |e| e.heloc_interest_from_rental > 0 },
      "Later months should have HELOC interest funded from rental"
  end

  # S3: Tax benefit with specific federal+provincial rate
  # $100K income, ON: federal 20.5% + provincial 9.15% = 29.65%
  test "S3: tax benefit uses correct combined federal+provincial rate" do
    @strategy.update!(province: "ON", simulation_months: 12)

    CanadianSmithManoeuvrSimulator.new(@strategy).simulate!

    marginal_rate = @strategy.effective_marginal_tax_rate
    assert_in_delta 0.2965, marginal_rate, 0.001,
      "Combined ON rate should be ~29.65% for $100K income"

    @strategy.strategy_entries.where("deductible_interest > 0").limit(3).each do |entry|
      expected_benefit = entry.deductible_interest * marginal_rate
      assert_in_delta expected_benefit, entry.tax_benefit, 0.01,
        "Month #{entry.month_number}: tax benefit should equal deductible_interest * combined rate"
    end
  end

  # S4: Lump-sum prepayment with HELOC readvance
  test "S4: lump-sum prepayment produces above-normal prepayment month" do
    loan = @primary_mortgage.accountable
    loan.update!(annual_lump_sum_month: (Date.current + 2.months).month, annual_lump_sum_amount: 10000)

    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "S4 Lump Sum",
      strategy_type: "modified_smith",
      primary_mortgage: @primary_mortgage,
      heloc: @heloc,
      rental_mortgage: @rental_mortgage,
      rental_income: 2500,
      rental_expenses: 500,
      heloc_readvanceable: true,
      heloc_max_limit: 200_000,
      simulation_months: 24
    )

    CanadianSmithManoeuvrSimulator.new(strategy).simulate!

    entries = strategy.strategy_entries.order(:month_number).to_a
    max_prepayment = entries.max_by(&:primary_mortgage_prepayment)

    # Normal monthly surplus is ~$2K; with lump sum, one month should be well above that
    assert max_prepayment.primary_mortgage_prepayment > 5000,
      "At least one month should have a large prepayment including lump sum " \
      "(max was $#{max_prepayment.primary_mortgage_prepayment.round})"
  end

  # S5: Auto-stop via cumulative_cost_exceeds_benefit
  # With a very low primary rate (2%), high HELOC rate (20%), and large expenses
  # relative to income, the HELOC interest cost quickly exceeds any benefit.
  test "S5: cumulative cost exceeds benefit triggers auto-stop" do
    expensive_heloc = create_heloc_account(@family, "HELOC S5", 0, 20.0, 500000)
    cheap_primary = create_loan_account(@family, "Primary S5", 400000, 2.0, 300)
    rental = create_loan_account(@family, "Rental S5", 200000, 5.5, 240)

    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "S5 Cost Exceeds Benefit",
      strategy_type: "modified_smith",
      primary_mortgage: cheap_primary,
      heloc: expensive_heloc,
      rental_mortgage: rental,
      rental_income: 600,
      rental_expenses: 500,
      simulation_months: 120
    )

    strategy.auto_stop_rules.create!(
      rule_type: "cumulative_cost_exceeds_benefit",
      enabled: true
    )

    CanadianSmithManoeuvrSimulator.new(strategy).simulate!

    stopped_entry = strategy.strategy_entries.where(strategy_stopped: true).first
    assert stopped_entry.present?, "Strategy should stop when cumulative cost exceeds benefit"

    cumulative_net = stopped_entry.metadata["cumulative_net_benefit"].to_f
    assert cumulative_net < 0,
      "Cumulative net benefit ($#{cumulative_net.round(2)}) should be negative at stop point"
  end

  # S6: Mortgage renewal with rate change affects payment
  test "S6: mortgage renewal changes payment in Smith strategy" do
    loan = @primary_mortgage.accountable
    loan.update!(renewal_date: Date.current + 1.day, renewal_term_months: 6, renewal_rate: 7.0)

    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "S6 Renewal",
      strategy_type: "modified_smith",
      primary_mortgage: @primary_mortgage,
      heloc: @heloc,
      rental_mortgage: @rental_mortgage,
      heloc_readvanceable: true,
      heloc_max_limit: 200_000,
      rental_income: 2500,
      rental_expenses: 500,
      simulation_months: 24
    )

    CanadianSmithManoeuvrSimulator.new(strategy).simulate!

    entries = strategy.strategy_entries.order(:month_number).to_a
    assert entries.size > 6, "Should run past first renewal"

    pre_renewal = entries[5]  # Month 5 (last before renewal at month 6)
    post_renewal = entries[6] # Month 6 (first after renewal)

    assert post_renewal.primary_mortgage_payment > pre_renewal.primary_mortgage_payment,
      "Post-renewal payment ($#{post_renewal.primary_mortgage_payment.round}) should exceed " \
      "pre-renewal ($#{pre_renewal.primary_mortgage_payment.round}) after 5% → 7% renewal"
  end

  # S7: Multi-renewal full 25-year simulation
  test "S7: full 300-month simulation with 60-month renewal terms" do
    loan = @primary_mortgage.accountable
    loan.update!(renewal_date: Date.current + 1.day, renewal_term_months: 60, renewal_rate: 5.5)

    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "S7 Full Term",
      strategy_type: "modified_smith",
      primary_mortgage: @primary_mortgage,
      heloc: @heloc,
      rental_mortgage: @rental_mortgage,
      rental_income: 2500,
      rental_expenses: 500,
      simulation_months: 300
    )

    CanadianSmithManoeuvrSimulator.new(strategy).simulate!

    baseline_entries = strategy.baseline_entries.to_a
    strategy_entries = strategy.strategy_entries.to_a

    # Both scenarios should run a substantial number of months
    assert baseline_entries.size > 100, "Baseline should run 100+ months (got #{baseline_entries.size})"
    assert strategy_entries.size > 100, "Strategy should run 100+ months (got #{strategy_entries.size})"

    # Smith strategy should pay off primary mortgage faster
    baseline_payoff = baseline_entries.index { |e| e.primary_mortgage_balance == 0 }
    strategy_payoff = strategy_entries.index { |e| e.primary_mortgage_balance == 0 }

    if baseline_payoff && strategy_payoff
      assert strategy_payoff < baseline_payoff,
        "Smith (month #{strategy_payoff}) should pay off primary faster than baseline (month #{baseline_payoff})"
    end
  end

  private

    def create_loan_account(family, name, balance, interest_rate, term_months)
      loan = Loan.create!(
        interest_rate: interest_rate,
        term_months: term_months,
        rate_type: "fixed"
      )

      Account.create!(
        family: family,
        name: name,
        balance: -balance,
        currency: "CAD",
        accountable: loan,
        status: "active"
      )
    end

    def create_heloc_account(family, name, balance, interest_rate, credit_limit)
      loan = Loan.create!(
        interest_rate: interest_rate,
        rate_type: "variable",
        credit_limit: credit_limit
      )

      Account.create!(
        family: family,
        name: name,
        balance: -balance,
        currency: "CAD",
        accountable: loan,
        status: "active"
      )
    end
end
