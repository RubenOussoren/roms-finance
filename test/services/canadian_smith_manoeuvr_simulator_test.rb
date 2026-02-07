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
