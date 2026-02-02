require "application_system_test_case"

class DebtOptimizationTest < ApplicationSystemTestCase
  setup do
    sign_in @user = users(:family_admin)
    @strategy = debt_optimization_strategies(:baseline)
  end

  test "can view debt optimization strategies list" do
    visit debt_optimization_strategies_path

    assert_selector "h1", text: /Debt Optimization/
    assert_text @strategy.name
  end

  test "can create baseline debt optimization strategy" do
    visit debt_optimization_strategies_path

    click_link "New Strategy"

    # Fill in basic strategy info
    fill_in "Name", with: "Test Baseline Strategy"
    select "Baseline (No Optimization)", from: "Strategy Type"
    fill_in "debt_optimization_strategy[rental_income]", with: 2500
    fill_in "debt_optimization_strategy[rental_expenses]", with: 500
    fill_in "debt_optimization_strategy[simulation_months]", with: 120

    click_button "Create Strategy"

    # Should redirect to strategy show page
    assert_text "Test Baseline Strategy"
    assert_text "Strategy created successfully"
  end

  test "can run simulation on strategy" do
    visit debt_optimization_strategy_path(@strategy)

    # Find and click the simulate button
    click_button "Run Simulation"

    # Should redirect with success message
    assert_current_path debt_optimization_strategy_path(@strategy)
    assert_text "Simulation completed successfully"
  end

  test "can view strategy details with simulation results" do
    # Use the baseline strategy which has simulation data
    visit debt_optimization_strategy_path(@strategy)

    assert_selector "h1", text: @strategy.name
    assert_text @strategy.strategy_type.titleize

    # Check for strategy configuration section
    assert_text "Strategy Configuration"
  end
end
