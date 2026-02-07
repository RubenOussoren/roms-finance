require "test_helper"

class BaselineSimulatorTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)

    # Create loan accounts for testing
    @primary_mortgage = create_loan_account(@family, "Primary Mortgage", 400000, 5.0, 300)
    @rental_mortgage = create_loan_account(@family, "Rental Mortgage", 200000, 5.5, 240)

    @strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "Baseline Test",
      strategy_type: "baseline",
      primary_mortgage: @primary_mortgage,
      rental_mortgage: @rental_mortgage,
      rental_income: 2500,
      rental_expenses: 500,
      simulation_months: 24
    )
  end

  test "creates ledger entries for simulation period" do
    simulator = BaselineSimulator.new(@strategy)
    simulator.simulate!

    assert @strategy.ledger_entries.count > 0
    assert @strategy.ledger_entries.count <= 24
  end

  test "all entries have scenario_type baseline" do
    simulator = BaselineSimulator.new(@strategy)
    simulator.simulate!

    assert @strategy.ledger_entries.all? { |e| e.scenario_type == "baseline" }
  end

  test "primary mortgage balance decreases over time" do
    simulator = BaselineSimulator.new(@strategy)
    simulator.simulate!

    entries = @strategy.baseline_entries.order(:month_number)
    first_balance = entries.first.primary_mortgage_balance
    last_balance = entries.last.primary_mortgage_balance

    assert last_balance < first_balance, "Balance should decrease over time"
  end

  test "entries use post-payment balances" do
    simulator = BaselineSimulator.new(@strategy)
    simulator.simulate!

    entries = @strategy.baseline_entries.order(:month_number).to_a
    return if entries.size < 2

    # For consecutive entries, current balance should equal
    # previous balance minus current principal payment
    (1...entries.size).each do |i|
      prev = entries[i - 1]
      curr = entries[i]

      expected = prev.primary_mortgage_balance - curr.primary_mortgage_principal
      assert_in_delta expected, curr.primary_mortgage_balance, 0.01,
        "Month #{curr.month_number}: balance should be prev - principal"
    end
  end

  test "no heloc usage in baseline" do
    simulator = BaselineSimulator.new(@strategy)
    simulator.simulate!

    @strategy.baseline_entries.each do |entry|
      assert_equal 0, entry.heloc_draw
      assert_equal 0, entry.heloc_balance
    end
  end

  test "no prepayment in baseline" do
    simulator = BaselineSimulator.new(@strategy)
    simulator.simulate!

    @strategy.baseline_entries.each do |entry|
      assert_equal 0, entry.primary_mortgage_prepayment
    end
  end

  test "rental mortgage interest is deductible" do
    simulator = BaselineSimulator.new(@strategy)
    simulator.simulate!

    entry = @strategy.baseline_entries.first
    assert entry.deductible_interest > 0, "Rental mortgage interest should be deductible"
    assert_in_delta entry.rental_mortgage_interest, entry.deductible_interest, 0.01
  end

  test "primary mortgage interest is not deductible" do
    simulator = BaselineSimulator.new(@strategy)
    simulator.simulate!

    entry = @strategy.baseline_entries.first
    assert entry.non_deductible_interest > 0, "Primary mortgage interest should be non-deductible"
    assert_in_delta entry.primary_mortgage_interest, entry.non_deductible_interest, 0.01
  end

  test "handles strategy with no accounts gracefully" do
    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "Empty Strategy",
      strategy_type: "baseline",
      rental_income: 0,
      rental_expenses: 0,
      simulation_months: 12
    )

    simulator = BaselineSimulator.new(strategy)
    simulator.simulate!

    assert strategy.ledger_entries.count > 0
  end

  test "supports mortgage renewal at periodic intervals" do
    loan = @primary_mortgage.accountable
    loan.update!(renewal_date: Date.current + 1.day, renewal_term_months: 12, renewal_rate: 6.0)

    @strategy.update!(simulation_months: 24)

    simulator = BaselineSimulator.new(@strategy)
    simulator.simulate!

    entries = @strategy.baseline_entries.order(:month_number).to_a
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
end
