require "test_helper"

class UI::DebtOptimization::StrategyCardTest < ActiveSupport::TestCase
  setup do
    @strategy = debt_optimization_strategies(:smith_manoeuvre)
    @baseline_strategy = debt_optimization_strategies(:baseline)
  end

  test "initializes with strategy" do
    component = UI::DebtOptimization::StrategyCard.new(strategy: @strategy)
    assert_equal @strategy, component.strategy
  end

  test "strategy_type_label returns Baseline for baseline type" do
    component = UI::DebtOptimization::StrategyCard.new(strategy: @baseline_strategy)
    assert_equal "Baseline (No Optimization)", component.strategy_type_label
  end

  test "strategy_type_label returns Modified Smith for modified_smith type" do
    component = UI::DebtOptimization::StrategyCard.new(strategy: @strategy)
    assert_equal "Modified Smith Manoeuvre", component.strategy_type_label
  end

  test "status_badge_classes returns blue for simulated status" do
    # Use baseline strategy which is already simulated
    component = UI::DebtOptimization::StrategyCard.new(strategy: @baseline_strategy)
    assert_equal "bg-blue-100 text-blue-700", component.status_badge_classes
  end

  test "status_badge_classes returns yellow for draft status" do
    # Smith manoeuvre fixture has draft status
    component = UI::DebtOptimization::StrategyCard.new(strategy: @strategy)
    assert_equal "bg-yellow-100 text-yellow-700", component.status_badge_classes
  end

  test "status_label returns titleized status" do
    component = UI::DebtOptimization::StrategyCard.new(strategy: @baseline_strategy)
    assert_equal "Simulated", component.status_label
  end

  test "formatted_tax_benefit returns dash when nil" do
    # Smith_manoeuvre has nil tax benefit
    component = UI::DebtOptimization::StrategyCard.new(strategy: @strategy)
    assert_equal "—", component.formatted_tax_benefit
  end

  test "formatted_interest_saved returns dash when nil" do
    # Smith_manoeuvre has nil interest saved
    component = UI::DebtOptimization::StrategyCard.new(strategy: @strategy)
    assert_equal "—", component.formatted_interest_saved
  end

  test "months_accelerated_text returns formatted years for 36 months" do
    component = UI::DebtOptimization::StrategyCard.new(strategy: @baseline_strategy)
    assert_equal "3 years", component.months_accelerated_text
  end

  test "months_accelerated_text returns dash when nil" do
    component = UI::DebtOptimization::StrategyCard.new(strategy: @strategy)
    assert_equal "—", component.months_accelerated_text
  end

  test "last_simulated_text returns Not simulated when nil" do
    component = UI::DebtOptimization::StrategyCard.new(strategy: @strategy)
    assert_equal "Not simulated", component.last_simulated_text
  end

  test "primary_mortgage_name returns Not set when nil" do
    component = UI::DebtOptimization::StrategyCard.new(strategy: @strategy)
    assert_equal "Not set", component.primary_mortgage_name
  end

  test "heloc_name returns Not set when nil" do
    component = UI::DebtOptimization::StrategyCard.new(strategy: @strategy)
    assert_equal "Not set", component.heloc_name
  end

  test "rental_mortgage_name returns Not set when nil" do
    component = UI::DebtOptimization::StrategyCard.new(strategy: @strategy)
    assert_equal "Not set", component.rental_mortgage_name
  end
end
