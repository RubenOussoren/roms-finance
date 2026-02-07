require "test_helper"

class DebtSimulatorEdgeCasesTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
  end

  # E1: Zero rental income — all HELOC interest must come from pocket
  test "zero rental income forces all HELOC interest from pocket" do
    primary = create_loan_account(@family, "Primary E1", 400000, 5.0, 300)
    heloc = create_heloc_account(@family, "HELOC E1", 0, 7.0, 100000)
    rental = create_loan_account(@family, "Rental E1", 200000, 5.5, 240)

    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "E1 Zero Rental",
      strategy_type: "modified_smith",
      primary_mortgage: primary,
      heloc: heloc,
      rental_mortgage: rental,
      rental_income: 0,
      rental_expenses: 0,
      simulation_months: 12
    )

    CanadianSmithManoeuvrSimulator.new(strategy).simulate!

    strategy.strategy_entries.each do |entry|
      assert_equal 0, entry.primary_mortgage_prepayment,
        "Month #{entry.month_number}: no prepayment with zero rental income"
    end

    entries_with_heloc_interest = strategy.strategy_entries.where("heloc_interest > 0")
    entries_with_heloc_interest.each do |entry|
      assert_in_delta entry.heloc_interest, entry.heloc_interest_from_pocket, 0.01,
        "Month #{entry.month_number}: all HELOC interest should come from pocket"
      assert_in_delta 0, entry.heloc_interest_from_rental, 0.01,
        "Month #{entry.month_number}: no HELOC interest from rental"
    end
  end

  # E2: Very high HELOC rate triggers heloc_interest_exceeds_benefit auto-stop
  test "very high HELOC rate triggers heloc_interest_exceeds_benefit stop" do
    primary = create_loan_account(@family, "Primary E2", 100000, 3.0, 300)
    heloc = create_heloc_account(@family, "HELOC E2", 20000, 25.0, 100000)
    rental = create_loan_account(@family, "Rental E2", 50000, 3.0, 240)

    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "E2 High HELOC Rate",
      strategy_type: "modified_smith",
      primary_mortgage: primary,
      heloc: heloc,
      rental_mortgage: rental,
      rental_income: 1000,
      rental_expenses: 500,
      simulation_months: 120
    )

    strategy.auto_stop_rules.create!(
      rule_type: "heloc_interest_exceeds_benefit",
      enabled: true
    )

    CanadianSmithManoeuvrSimulator.new(strategy).simulate!

    stopped_entry = strategy.strategy_entries.where(strategy_stopped: true).first
    assert stopped_entry.present?, "Should stop due to high HELOC interest"
    assert stopped_entry.heloc_interest > stopped_entry.tax_benefit,
      "HELOC interest (#{stopped_entry.heloc_interest}) should exceed tax benefit (#{stopped_entry.tax_benefit}) at stop"
  end

  # E3: Zero balance mortgage — should produce entries with all zeros, no errors
  test "zero balance mortgage produces zero-value entries without error" do
    primary = create_loan_account(@family, "Primary E3", 0, 5.0, 300)
    rental = create_loan_account(@family, "Rental E3", 0, 5.5, 240)

    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "E3 Zero Balance",
      strategy_type: "baseline",
      primary_mortgage: primary,
      rental_mortgage: rental,
      rental_income: 0,
      rental_expenses: 0,
      simulation_months: 6
    )

    BaselineSimulator.new(strategy).simulate!

    entries = strategy.baseline_entries.to_a
    assert entries.size >= 1, "Should create at least one entry"

    entries.each do |entry|
      assert_equal 0, entry.primary_mortgage_balance
      assert_equal 0, entry.primary_mortgage_interest
      assert_equal 0, entry.primary_mortgage_principal
      assert_equal 0, entry.rental_mortgage_balance
      assert_equal 0, entry.rental_mortgage_interest
    end
  end

  # E4: Single month simulation — exactly 1 entry at month_number 0
  test "single month simulation produces exactly one entry at month zero" do
    primary = create_loan_account(@family, "Primary E4", 400000, 5.0, 300)
    rental = create_loan_account(@family, "Rental E4", 200000, 5.5, 240)

    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "E4 Single Month",
      strategy_type: "baseline",
      primary_mortgage: primary,
      rental_mortgage: rental,
      rental_income: 2500,
      rental_expenses: 500,
      simulation_months: 1
    )

    BaselineSimulator.new(strategy).simulate!

    entries = strategy.baseline_entries.to_a
    assert_equal 1, entries.size, "Should have exactly 1 entry"
    assert_equal 0, entries.first.month_number, "Entry should be month 0"
  end

  # E5: Zero rental surplus — all prepayments should be zero in prepay-only
  test "zero rental surplus produces zero prepayments in prepay-only" do
    primary = create_loan_account(@family, "Primary E5", 400000, 5.0, 300)
    heloc = create_heloc_account(@family, "HELOC E5", 0, 7.0, 100000)
    rental = create_loan_account(@family, "Rental E5", 200000, 5.5, 240)

    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "E5 Zero Surplus",
      strategy_type: "modified_smith",
      primary_mortgage: primary,
      heloc: heloc,
      rental_mortgage: rental,
      rental_income: 500,
      rental_expenses: 500,
      simulation_months: 12
    )

    PrepayOnlySimulator.new(strategy).simulate!

    strategy.ledger_entries.where(scenario_type: "prepay_only").each do |entry|
      assert_equal 0, entry.primary_mortgage_prepayment,
        "Month #{entry.month_number}: prepayment should be zero with zero surplus"
    end
  end

  # E6: Zero surplus Smith — HELOC still draws for expenses (converts non-deductible to deductible)
  test "zero surplus Smith still draws HELOC for expenses" do
    primary = create_loan_account(@family, "Primary E6", 400000, 5.0, 300)
    heloc = create_heloc_account(@family, "HELOC E6", 0, 7.0, 100000)
    rental = create_loan_account(@family, "Rental E6", 200000, 5.5, 240)

    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "E6 Zero Surplus Smith",
      strategy_type: "modified_smith",
      primary_mortgage: primary,
      heloc: heloc,
      rental_mortgage: rental,
      rental_income: 500,
      rental_expenses: 500,
      simulation_months: 12
    )

    CanadianSmithManoeuvrSimulator.new(strategy).simulate!

    first_entry = strategy.strategy_entries.first
    assert_equal 500, first_entry.heloc_draw,
      "HELOC should draw $500 for rental expenses even with zero surplus"
    assert first_entry.heloc_balance > 0,
      "HELOC balance should increase from expense draws"
  end

  # E7: Negative rental surplus — no negative prepayments or HELOC draws
  test "negative rental surplus produces no negative prepayments or draws" do
    primary = create_loan_account(@family, "Primary E7", 400000, 5.0, 300)
    heloc = create_heloc_account(@family, "HELOC E7", 0, 7.0, 100000)
    rental = create_loan_account(@family, "Rental E7", 200000, 5.5, 240)

    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "E7 Negative Surplus",
      strategy_type: "modified_smith",
      primary_mortgage: primary,
      heloc: heloc,
      rental_mortgage: rental,
      rental_income: 300,
      rental_expenses: 500,
      simulation_months: 12
    )

    # Run all three scenarios
    BaselineSimulator.new(strategy).simulate!
    PrepayOnlySimulator.new(strategy).simulate!
    CanadianSmithManoeuvrSimulator.new(strategy).simulate!

    strategy.ledger_entries.each do |entry|
      assert entry.primary_mortgage_prepayment >= 0,
        "#{entry.scenario_type} month #{entry.month_number}: prepayment should not be negative"
      assert entry.heloc_draw >= 0,
        "#{entry.scenario_type} month #{entry.month_number}: HELOC draw should not be negative"
      assert entry.heloc_balance >= 0,
        "#{entry.scenario_type} month #{entry.month_number}: HELOC balance should not be negative"
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
