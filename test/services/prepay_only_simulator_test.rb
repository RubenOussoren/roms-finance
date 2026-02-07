require "test_helper"

class PrepayOnlySimulatorTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)

    @primary_mortgage = create_loan_account(@family, "Primary Mortgage", 400000, 5.0, 300)
    @heloc = create_heloc_account(@family, "HELOC", 0, 7.0, 100000)
    @rental_mortgage = create_loan_account(@family, "Rental Mortgage", 200000, 5.5, 240)

    @strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "Prepay Only Test",
      strategy_type: "modified_smith",
      primary_mortgage: @primary_mortgage,
      heloc: @heloc,
      rental_mortgage: @rental_mortgage,
      rental_income: 2500,
      rental_expenses: 500,
      simulation_months: 24
    )
  end

  test "creates ledger entries for simulation period" do
    simulator = PrepayOnlySimulator.new(@strategy)
    simulator.simulate!

    entries = @strategy.ledger_entries.where(scenario_type: "prepay_only")
    assert entries.count > 0, "Should create ledger entries"
    assert entries.count <= 24, "Should not exceed simulation months"
  end

  test "all entries have scenario_type prepay_only" do
    simulator = PrepayOnlySimulator.new(@strategy)
    simulator.simulate!

    assert @strategy.ledger_entries.all? { |e| e.scenario_type == "prepay_only" }
  end

  test "applies rental surplus as prepayment" do
    simulator = PrepayOnlySimulator.new(@strategy)
    simulator.simulate!

    entry = @strategy.ledger_entries.where(scenario_type: "prepay_only").order(:month_number).first
    rental_surplus = @strategy.rental_income - @strategy.rental_expenses

    assert entry.primary_mortgage_prepayment > 0, "Should prepay primary mortgage"
    assert entry.primary_mortgage_prepayment <= rental_surplus,
      "Prepayment should not exceed rental surplus"
  end

  test "zero HELOC usage" do
    simulator = PrepayOnlySimulator.new(@strategy)
    simulator.simulate!

    @strategy.ledger_entries.where(scenario_type: "prepay_only").each do |entry|
      assert_equal 0, entry.heloc_draw, "Should have zero HELOC draws"
      assert_equal 0, entry.heloc_balance, "Should have zero HELOC balance"
      assert_equal 0, entry.heloc_interest, "Should have zero HELOC interest"
    end
  end

  test "primary mortgage pays down faster than baseline" do
    # Run both baseline and prepay-only
    BaselineSimulator.new(@strategy).simulate!
    PrepayOnlySimulator.new(@strategy).simulate!

    baseline_last = @strategy.ledger_entries.where(scenario_type: "baseline").order(:month_number).last
    prepay_last = @strategy.ledger_entries.where(scenario_type: "prepay_only").order(:month_number).last

    assert prepay_last.primary_mortgage_balance < baseline_last.primary_mortgage_balance,
      "Prepay-only should pay down primary mortgage faster than baseline"
  end

  test "respects prepayment privilege limits" do
    loan = @primary_mortgage.accountable
    loan.update!(prepayment_privilege_percent: 15)

    simulator = PrepayOnlySimulator.new(@strategy)
    simulator.simulate!

    privilege_limit = 400_000 * 0.15
    entries = @strategy.ledger_entries.where(scenario_type: "prepay_only").order(:month_number).to_a

    by_year = entries.group_by { |e| e.calendar_month.year }
    by_year.each do |_year, year_entries|
      annual_prepayment = year_entries.sum(&:primary_mortgage_prepayment)
      assert annual_prepayment <= privilege_limit + 0.01,
        "Annual prepayment #{annual_prepayment} should not exceed privilege limit #{privilege_limit}"
    end
  end

  test "no prepayment after primary mortgage is paid off" do
    # Use a small mortgage to ensure it gets paid off quickly
    small_mortgage = create_loan_account(@family, "Small Mortgage", 5000, 5.0, 300)
    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "Small Prepay Test",
      strategy_type: "modified_smith",
      primary_mortgage: small_mortgage,
      heloc: create_heloc_account(@family, "HELOC2", 0, 7.0, 100000),
      rental_mortgage: @rental_mortgage,
      rental_income: 2500,
      rental_expenses: 500,
      simulation_months: 12
    )

    PrepayOnlySimulator.new(strategy).simulate!

    entries = strategy.ledger_entries
      .where(scenario_type: "prepay_only")
      .order(:month_number).to_a

    # Find the first month where primary is paid off
    paid_off_month = entries.index { |e| e.primary_mortgage_balance == 0 }
    assert paid_off_month.present?, "Primary should be paid off within 12 months"

    # Entries AFTER the payoff month should have zero prepayment
    entries[(paid_off_month + 1)..].each do |entry|
      assert_equal 0, entry.primary_mortgage_prepayment,
        "No prepayment after mortgage is already paid off (month #{entry.month_number})"
    end
  end

  # P1: Prepayment reduces total interest (quantified)
  test "P1: prepayment quantifiably reduces total interest versus baseline" do
    @strategy.update!(simulation_months: 120)

    BaselineSimulator.new(@strategy).simulate!
    PrepayOnlySimulator.new(@strategy).simulate!

    baseline_interest = @strategy.baseline_entries.sum(&:primary_mortgage_interest)
    prepay_interest = @strategy.ledger_entries.where(scenario_type: "prepay_only").sum(&:primary_mortgage_interest)

    assert baseline_interest > prepay_interest,
      "Baseline interest ($#{baseline_interest.round}) should exceed prepay interest ($#{prepay_interest.round})"

    savings = baseline_interest - prepay_interest
    assert savings > 5000,
      "Interest savings ($#{savings.round}) should exceed $5,000 over 120 months with $2K surplus"
  end

  # P2: Controlled $500/month prepayment
  test "P2: controlled surplus produces exact first-month prepayment" do
    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "P2 Controlled Surplus",
      strategy_type: "modified_smith",
      primary_mortgage: @primary_mortgage,
      heloc: @heloc,
      rental_mortgage: @rental_mortgage,
      rental_income: 1000,
      rental_expenses: 500,
      simulation_months: 12
    )

    PrepayOnlySimulator.new(strategy).simulate!

    first_entry = strategy.ledger_entries.where(scenario_type: "prepay_only").order(:month_number).first
    assert_in_delta 500, first_entry.primary_mortgage_prepayment, 0.01,
      "First-month prepayment should equal exact rental surplus of $500"
  end

  # P3: Prepayment caps at remaining balance (small mortgage)
  test "P3: prepayment caps at remaining balance for small mortgage" do
    tiny_mortgage = create_loan_account(@family, "Tiny P3", 3000, 5.0, 300)
    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "P3 Cap at Balance",
      strategy_type: "modified_smith",
      primary_mortgage: tiny_mortgage,
      heloc: @heloc,
      rental_mortgage: @rental_mortgage,
      rental_income: 2500,
      rental_expenses: 500,
      simulation_months: 12
    )

    PrepayOnlySimulator.new(strategy).simulate!

    entries = strategy.ledger_entries.where(scenario_type: "prepay_only").order(:month_number).to_a

    # Balance should never go negative
    entries.each do |entry|
      assert entry.primary_mortgage_balance >= 0,
        "Month #{entry.month_number}: balance should never be negative"
    end

    # Mortgage should be paid off within a few months
    paid_off = entries.index { |e| e.primary_mortgage_balance == 0 }
    assert paid_off.present?, "Small mortgage should be paid off"
    assert paid_off <= 3, "Should pay off $3K mortgage within 3 months with $2K surplus"
  end

  test "primary mortgage balance decreases monotonically" do
    simulator = PrepayOnlySimulator.new(@strategy)
    simulator.simulate!

    entries = @strategy.ledger_entries.where(scenario_type: "prepay_only").order(:month_number).to_a
    return if entries.size < 2

    (1...entries.size).each do |i|
      assert entries[i].primary_mortgage_balance <= entries[i - 1].primary_mortgage_balance,
        "Primary mortgage balance should not increase (month #{entries[i].month_number})"
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
