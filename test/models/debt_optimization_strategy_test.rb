require "test_helper"

# 🇨🇦 Tests for Canadian Modified Smith Manoeuvre debt optimization strategy
class DebtOptimizationStrategyTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @strategy = debt_optimization_strategies(:smith_manoeuvre)
  end

  test "valid strategy with required attributes" do
    strategy = DebtOptimizationStrategy.new(
      family: @family,
      name: "Test Strategy",
      strategy_type: "baseline",
      rental_income: 2000,
      rental_expenses: 500,
      simulation_months: 120
    )
    assert strategy.valid?
  end

  test "requires name" do
    @strategy.name = nil
    assert_not @strategy.valid?
    assert_includes @strategy.errors[:name], "can't be blank"
  end

  test "requires family" do
    @strategy.family = nil
    assert_not @strategy.valid?
    assert_includes @strategy.errors[:family], "must exist"
  end

  test "simulation_months must be positive" do
    @strategy.simulation_months = 0
    assert_not @strategy.valid?
    assert_includes @strategy.errors[:simulation_months], "must be greater than 0"
  end

  test "simulation_months must be at most 600" do
    @strategy.simulation_months = 601
    assert_not @strategy.valid?
    assert_includes @strategy.errors[:simulation_months], "must be less than or equal to 600"
  end

  test "strategy types" do
    assert DebtOptimizationStrategy.strategy_types.keys.include?("baseline")
    assert DebtOptimizationStrategy.strategy_types.keys.include?("modified_smith")
  end

  test "statuses" do
    assert DebtOptimizationStrategy.statuses.keys.include?("draft")
    assert DebtOptimizationStrategy.statuses.keys.include?("simulated")
    assert DebtOptimizationStrategy.statuses.keys.include?("active")
    assert DebtOptimizationStrategy.statuses.keys.include?("completed")
  end

  test "returns baseline simulator for baseline strategy" do
    @strategy.strategy_type = "baseline"
    assert_instance_of BaselineSimulator, @strategy.simulator
  end

  test "returns canadian smith manoeuvre simulator for modified_smith strategy" do
    @strategy.strategy_type = "modified_smith"
    assert_instance_of ::CanadianSmithManoeuvrSimulator, @strategy.simulator
  end

  test "effective_marginal_tax_rate uses jurisdiction" do
    # Default should return a rate (uses Canada default)
    rate = @strategy.effective_marginal_tax_rate
    assert rate >= 0
    assert rate <= 1
  end

  test "baseline_entries returns only baseline ledger entries" do
    # Create some baseline entries
    @strategy.ledger_entries.create!(
      month_number: 0,
      calendar_month: Date.current,
      baseline: true
    )
    @strategy.ledger_entries.create!(
      month_number: 0,
      calendar_month: Date.current,
      baseline: false
    )

    assert_equal 1, @strategy.baseline_entries.count
    assert @strategy.baseline_entries.all?(&:baseline?)
  end

  test "strategy_entries returns only non-baseline ledger entries" do
    @strategy.ledger_entries.create!(
      month_number: 0,
      calendar_month: Date.current,
      baseline: true
    )
    @strategy.ledger_entries.create!(
      month_number: 0,
      calendar_month: Date.current,
      baseline: false
    )

    assert_equal 1, @strategy.strategy_entries.count
    assert @strategy.strategy_entries.none?(&:baseline?)
  end

  test "for_family scope returns strategies for specific family" do
    strategies = DebtOptimizationStrategy.for_family(@family)
    assert strategies.all? { |s| s.family_id == @family.id }
  end
end
