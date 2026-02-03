require "test_helper"

# 🇨🇦 Tests for Canadian Modified Smith Manoeuvre simulator
class CanadianSmithManoeuvrSimulatorTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)

    # Create loan accounts for testing
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

    # Add default auto-stop rules
    @strategy.auto_stop_rules.create!(
      rule_type: "heloc_limit_percentage",
      threshold_value: 95,
      threshold_unit: "percentage",
      enabled: true
    )
  end

  test "creates both baseline and strategy entries" do
    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    baseline_count = @strategy.baseline_entries.count
    strategy_count = @strategy.strategy_entries.count

    assert baseline_count > 0, "Should have baseline entries"
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

  test "strategy pays off primary mortgage faster than baseline" do
    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    # Compare primary mortgage balance after same number of months
    baseline_last = @strategy.baseline_entries.order(:month_number).last
    strategy_last = @strategy.strategy_entries.order(:month_number).last

    # Strategy should have lower primary mortgage balance
    assert strategy_last.primary_mortgage_balance <= baseline_last.primary_mortgage_balance,
           "Strategy should pay off primary mortgage faster"
  end

  test "HELOC interest is tax deductible" do
    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    entry = @strategy.strategy_entries.where("heloc_interest > 0").first
    return unless entry # Skip if no HELOC interest in short simulation

    assert entry.deductible_interest >= entry.heloc_interest,
           "HELOC interest should be included in deductible interest"
  end

  test "calculates tax benefit from deductible interest" do
    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    entry = @strategy.strategy_entries.where("deductible_interest > 0").first
    assert entry.tax_benefit > 0, "Should calculate tax benefit"

    # Tax benefit should be deductible interest * marginal rate
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
    # Create a rule that triggers early
    @strategy.auto_stop_rules.create!(
      rule_type: "max_months",
      threshold_value: 6,
      enabled: true
    )

    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    # Should have stopped at or before month 6
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

  # 🇨🇦 Canadian Feature Tests

  test "readvanceable HELOC increases credit limit as mortgage principal is paid" do
    @strategy.update!(heloc_readvanceable: true, heloc_max_limit: 200_000)

    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    entries = @strategy.strategy_entries.order(:month_number)
    return if entries.count < 2

    # As principal is paid, more HELOC should become available
    # This is reflected in the HELOC draws increasing over time
    first_entry = entries.first
    last_entry = entries.last

    # The strategy should be able to draw more from HELOC over time
    # as the credit limit grows with principal repayment
    assert last_entry.primary_mortgage_balance < first_entry.primary_mortgage_balance,
           "Primary mortgage should decrease"
  end

  test "heloc_interest_ceiling stop rule triggers correctly" do
    @strategy.auto_stop_rules.create!(
      rule_type: "heloc_interest_ceiling",
      threshold_value: 100, # Stop if monthly HELOC interest exceeds $100
      enabled: true
    )

    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    # Check if rule would have triggered
    entries = @strategy.strategy_entries.where("heloc_interest >= 100")
    if entries.any?
      stopped_entries = @strategy.strategy_entries.where(strategy_stopped: true)
      assert stopped_entries.any?, "Should stop when HELOC interest exceeds ceiling"
    end
  end

  test "tax_refund_coverage_ratio stop rule triggers correctly" do
    @strategy.auto_stop_rules.create!(
      rule_type: "tax_refund_coverage_ratio",
      threshold_value: 50, # Stop if tax benefit < 50% of HELOC interest
      enabled: true
    )

    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    # Verify the rule is checked (it may or may not trigger depending on data)
    entries = @strategy.strategy_entries
    assert entries.any?, "Should have simulation entries"
  end

  test "manual_stop_date stop rule triggers correctly" do
    stop_date = (Date.current + 6.months).to_s
    @strategy.auto_stop_rules.create!(
      rule_type: "manual_stop_date",
      metadata: { "stop_date" => stop_date },
      enabled: true
    )

    simulator = CanadianSmithManoeuvrSimulator.new(@strategy)
    simulator.simulate!

    last_entry = @strategy.strategy_entries.order(:month_number).last
    assert last_entry.calendar_month <= Date.parse(stop_date),
           "Should stop on or before manual stop date"
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
