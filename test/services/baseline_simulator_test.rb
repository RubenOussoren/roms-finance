require "test_helper"

class BaselineSimulatorTest < ActiveSupport::TestCase
  include DebtSimulatorTestHelper

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

  # B1: Known-value amortization with Canadian semi-annual compounding
  # $400K @ 5%, 25yr (300 months)
  # monthly_rate = (1 + 0.05/2)^(1/6) - 1 ≈ 0.00412389
  # payment ≈ $2,326.37
  # month-0 interest = 400000 * 0.00412389 ≈ $1,649.56
  # month-0 principal = 2326.37 - 1649.56 ≈ $676.81
  test "B1: known-value amortization with semi-annual compounding" do
    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "B1 Known Value",
      strategy_type: "baseline",
      primary_mortgage: @primary_mortgage,
      rental_income: 0,
      rental_expenses: 0,
      simulation_months: 300
    )

    BaselineSimulator.new(strategy).simulate!

    entries = strategy.baseline_entries.order(:month_number).to_a
    first = entries.first

    # Verify semi-annual compounding monthly rate
    expected_monthly_rate = (1 + 0.05 / 2.0)**(1.0 / 6) - 1
    assert_in_delta 0.00412389, expected_monthly_rate, 0.0000001

    # Verify monthly payment
    expected_payment = CanadianMortgage.monthly_payment(400_000, 0.05, 300)
    assert_in_delta 2326.37, expected_payment, 1.0

    # Verify month-0 interest
    expected_interest = 400_000 * expected_monthly_rate
    assert_in_delta 1649.56, first.primary_mortgage_interest, 1.0

    # Verify month-0 principal
    assert_in_delta 676.81, first.primary_mortgage_principal, 1.0

    # Verify total interest over full amortization
    total_interest = entries.sum(&:primary_mortgage_interest)
    assert_in_delta 297_911, total_interest, 500

    # Verify final balance is zero
    assert_equal 0, entries.last.primary_mortgage_balance,
      "Mortgage should be fully paid off at end of amortization"
  end

  # B2: Full-term completion — mortgage terminates early when paid off
  # $10K @ 5% over 60-month term. Payment ≈ $188.71, fully paid in 60 months.
  # With a 300-month simulation window, loop should break early.
  test "B2: mortgage terminates early with zero final balance" do
    small_mortgage = create_loan_account(@family, "Small B2", 10000, 5.0, 60)

    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "B2 Small Mortgage",
      strategy_type: "baseline",
      primary_mortgage: small_mortgage,
      rental_income: 0,
      rental_expenses: 0,
      simulation_months: 300
    )

    BaselineSimulator.new(strategy).simulate!

    entries = strategy.baseline_entries.order(:month_number).to_a
    assert_equal 0, entries.last.primary_mortgage_balance,
      "Mortgage should be fully paid off"
    assert entries.size <= 61,
      "Simulation should terminate at or near term end (got #{entries.size} entries)"
    assert entries.size < 300,
      "Simulation should terminate early, not run full 300 months"
  end

  # B3: Multiple renewals with rate change
  test "B3: mortgage renewal changes payment and interest at renewal boundary" do
    loan = @primary_mortgage.accountable
    loan.update!(renewal_date: Date.current + 1.day, renewal_term_months: 12, renewal_rate: 6.0)

    strategy = DebtOptimizationStrategy.create!(
      family: @family,
      name: "B3 Renewal Rate Change",
      strategy_type: "baseline",
      primary_mortgage: @primary_mortgage,
      rental_income: 0,
      rental_expenses: 0,
      simulation_months: 60
    )

    BaselineSimulator.new(strategy).simulate!

    entries = strategy.baseline_entries.order(:month_number).to_a
    assert entries.size > 12, "Should run past first renewal"

    pre_renewal = entries[11]  # Month 11 (last month before first renewal)
    post_renewal = entries[12] # Month 12 (first month after renewal)

    # After renewal at 6% (up from 5%), payment should change
    assert post_renewal.primary_mortgage_payment != pre_renewal.primary_mortgage_payment,
      "Payment should change at renewal boundary (5% → 6%)"

    # Interest should be higher at 6% than 5% on similar balance
    assert post_renewal.primary_mortgage_interest > pre_renewal.primary_mortgage_interest * 1.1,
      "Interest should increase noticeably after renewal to 6%"
  end

  # B4: Rental mortgage amortization
  # $200K @ 5.5%, monthly_rate = (1+0.055/2)^(1/6)-1 ≈ 0.00453168
  # month-0 interest = 200000 * 0.00453168 ≈ $906.34
  test "B4: rental mortgage known-value interest" do
    BaselineSimulator.new(@strategy).simulate!

    entry = @strategy.baseline_entries.first
    assert_in_delta 906.34, entry.rental_mortgage_interest, 2.0,
      "Rental month-0 interest should match semi-annual compounding"

    # Verify rental balance decreases
    entries = @strategy.baseline_entries.order(:month_number).to_a
    assert entries.last.rental_mortgage_balance < entries.first.rental_mortgage_balance,
      "Rental balance should decrease over time"
  end

  # B5: Cumulative tax benefit accuracy
  test "B5: cumulative tax benefit is running sum of monthly benefits" do
    @strategy.update!(simulation_months: 12)
    BaselineSimulator.new(@strategy).simulate!

    entries = @strategy.baseline_entries.order(:month_number).to_a
    marginal_rate = @strategy.effective_marginal_tax_rate

    running_sum = 0
    entries.each do |entry|
      expected_benefit = entry.deductible_interest * marginal_rate
      assert_in_delta expected_benefit, entry.tax_benefit, 0.01,
        "Month #{entry.month_number}: tax_benefit should equal deductible_interest * rate"

      running_sum += entry.tax_benefit
      assert_in_delta running_sum, entry.cumulative_tax_benefit, 0.01,
        "Month #{entry.month_number}: cumulative_tax_benefit should be running sum"
    end
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
end
