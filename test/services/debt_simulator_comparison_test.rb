require "test_helper"

# Cross-simulator comparison tests — validates the economic ordering
# invariants that must hold across baseline, prepay-only, and Smith strategies.
class DebtSimulatorComparisonTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)

    @primary_mortgage = create_loan_account(@family, "Primary Comparison", 400000, 5.0, 300)
    @heloc = create_heloc_account(@family, "HELOC Comparison", 0, 7.0, 100000)
    @rental_mortgage = create_loan_account(@family, "Rental Comparison", 200000, 5.5, 240)

    @strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "Comparison Test",
      strategy_type: "modified_smith",
      primary_mortgage: @primary_mortgage,
      heloc: @heloc,
      rental_mortgage: @rental_mortgage,
      rental_income: 2500,
      rental_expenses: 500,
      simulation_months: 120
    )

    # Run all three scenarios
    CanadianSmithManoeuvrSimulator.new(@strategy).simulate!
  end

  # C1: Total interest ordering — baseline > prepay-only > smith (mortgage-only)
  test "C1: total mortgage interest ordering baseline > prepay > smith" do
    baseline_interest = @strategy.baseline_entries.sum(&:primary_mortgage_interest)
    prepay_interest = @strategy.prepay_only_entries.sum(&:primary_mortgage_interest)
    smith_interest = @strategy.strategy_entries.sum(&:primary_mortgage_interest)

    assert baseline_interest > prepay_interest,
      "Baseline interest ($#{baseline_interest.round}) should exceed prepay ($#{prepay_interest.round})"
    assert prepay_interest > smith_interest,
      "Prepay interest ($#{prepay_interest.round}) should exceed Smith ($#{smith_interest.round})"

    # Also verify net cost: mortgage savings + tax benefit - HELOC cost > 0
    smith_heloc_interest = @strategy.strategy_entries.sum(&:heloc_interest)
    smith_tax_benefit = @strategy.strategy_entries.last.cumulative_tax_benefit
    net_cost = smith_interest + smith_heloc_interest - smith_tax_benefit

    assert baseline_interest > net_cost,
      "Baseline interest should exceed Smith net cost (mortgage + HELOC - tax benefit)"
  end

  # C2: Payoff speed ordering — Smith <= prepay < baseline
  test "C2: payoff speed ordering smith <= prepay < baseline" do
    baseline_final = @strategy.baseline_entries.order(:month_number).last
    prepay_final = @strategy.prepay_only_entries.order(:month_number).last
    smith_final = @strategy.strategy_entries.order(:month_number).last

    # At end of simulation, Smith should have lowest primary balance
    assert smith_final.primary_mortgage_balance <= prepay_final.primary_mortgage_balance,
      "Smith balance ($#{smith_final.primary_mortgage_balance.round}) should be <= prepay ($#{prepay_final.primary_mortgage_balance.round})"
    assert prepay_final.primary_mortgage_balance < baseline_final.primary_mortgage_balance,
      "Prepay balance ($#{prepay_final.primary_mortgage_balance.round}) should be < baseline ($#{baseline_final.primary_mortgage_balance.round})"
  end

  # C3: HELOC balance only in Smith — zero in baseline and prepay-only
  test "C3: HELOC balance is zero in baseline and prepay-only, positive in Smith" do
    @strategy.baseline_entries.each do |entry|
      assert_equal 0, entry.heloc_balance,
        "Baseline month #{entry.month_number}: HELOC balance should be zero"
    end

    @strategy.prepay_only_entries.each do |entry|
      assert_equal 0, entry.heloc_balance,
        "Prepay-only month #{entry.month_number}: HELOC balance should be zero"
    end

    smith_with_heloc = @strategy.strategy_entries.where("heloc_balance > 0")
    assert smith_with_heloc.count > 0,
      "Smith strategy should have months with positive HELOC balance"
  end

  # C4: Net economic benefit is positive under standard configuration
  test "C4: net economic benefit is positive" do
    last_entry = @strategy.strategy_entries.order(:month_number).last
    cumulative_net_benefit = last_entry.metadata["cumulative_net_benefit"].to_f

    assert cumulative_net_benefit > 0,
      "Net economic benefit ($#{cumulative_net_benefit.round(2)}) should be positive " \
      "under standard 5%/7% config with $2K surplus"
  end

  # C5: Smith deductible interest exceeds baseline (HELOC interest is deductible)
  test "C5: Smith total deductible interest exceeds baseline" do
    baseline_deductible = @strategy.baseline_entries.sum(&:deductible_interest)
    smith_deductible = @strategy.strategy_entries.sum(&:deductible_interest)

    assert smith_deductible > baseline_deductible,
      "Smith deductible interest ($#{smith_deductible.round}) should exceed " \
      "baseline ($#{baseline_deductible.round}) due to HELOC interest"
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
