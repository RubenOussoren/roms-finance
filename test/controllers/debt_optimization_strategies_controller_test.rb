require "test_helper"

class DebtOptimizationStrategiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
    sign_in @user

    @strategy = debt_optimization_strategies(:smith_manoeuvre)
  end

  test "should get index" do
    get debt_optimization_strategies_path
    assert_response :success
    assert_select "h1", /Debt Optimization/
  end

  test "should get new" do
    get new_debt_optimization_strategy_path
    assert_response :success
    assert_select "h1", /New Debt Optimization Strategy/
  end

  test "should create debt optimization strategy with baseline type" do
    # Use baseline type which doesn't require linked accounts
    assert_difference("DebtOptimizationStrategy.count") do
      post debt_optimization_strategies_path, params: {
        debt_optimization_strategy: {
          name: "New Baseline Strategy",
          strategy_type: "baseline",
          rental_income: 2000,
          rental_expenses: 400,
          simulation_months: 120
        }
      }
    end

    assert_redirected_to debt_optimization_strategy_path(DebtOptimizationStrategy.last)
  end

  test "should show debt optimization strategy" do
    get debt_optimization_strategy_path(@strategy)
    assert_response :success
    assert_select "h1", /#{@strategy.name}/
  end

  test "should get edit" do
    get edit_debt_optimization_strategy_path(@strategy)
    assert_response :success
    assert_select "h1", /Edit Strategy/
  end

  test "should update debt optimization strategy" do
    # Use baseline type which doesn't have validation issues
    baseline_strategy = debt_optimization_strategies(:baseline)
    patch debt_optimization_strategy_path(baseline_strategy), params: {
      debt_optimization_strategy: {
        name: "Updated Name",
        rental_income: 3000
      }
    }

    assert_redirected_to debt_optimization_strategy_path(baseline_strategy)
    baseline_strategy.reload
    assert_equal "Updated Name", baseline_strategy.name
    assert_equal 3000, baseline_strategy.rental_income.to_i
  end

  test "should destroy debt optimization strategy" do
    assert_difference("DebtOptimizationStrategy.count", -1) do
      delete debt_optimization_strategy_path(@strategy)
    end

    assert_redirected_to debt_optimization_strategies_path
  end

  test "should not allow access to other family strategies" do
    other_family = Family.create!(name: "Other Family", currency: "USD", country: "US")
    other_strategy = DebtOptimizationStrategy.create!(
      family: other_family,
      name: "Other Strategy",
      strategy_type: "baseline",
      simulation_months: 120
    )

    # The controller scopes to Current.family, so it will raise RecordNotFound
    get debt_optimization_strategy_path(other_strategy)
    assert_response :not_found
  end

  test "create adds default auto-stop rules for baseline strategy" do
    assert_difference("DebtOptimizationStrategy.count") do
      post debt_optimization_strategies_path, params: {
        debt_optimization_strategy: {
          name: "New Strategy with Rules #{Time.now.to_i}",
          strategy_type: "baseline",
          rental_income: 2000,
          rental_expenses: 400,
          simulation_months: 120
        }
      }
    end

    assert_redirected_to debt_optimization_strategy_path(DebtOptimizationStrategy.last)

    strategy = DebtOptimizationStrategy.last
    assert_equal 2, strategy.auto_stop_rules.count
    assert strategy.auto_stop_rules.find_by(rule_type: "heloc_limit_percentage").present?
    assert strategy.auto_stop_rules.find_by(rule_type: "primary_paid_off").present?
  end

  test "simulate runs simulation and redirects with success" do
    baseline_strategy = debt_optimization_strategies(:baseline)

    # Mock the run_simulation! method
    DebtOptimizationStrategy.any_instance.expects(:run_simulation!).once

    post simulate_debt_optimization_strategy_path(baseline_strategy)

    assert_redirected_to debt_optimization_strategy_path(baseline_strategy)
    assert_equal "Simulation completed successfully", flash[:notice]
  end

  test "simulate handles errors gracefully" do
    baseline_strategy = debt_optimization_strategies(:baseline)

    # Mock run_simulation! to raise an error
    DebtOptimizationStrategy.any_instance.expects(:run_simulation!).raises(StandardError.new("Test error"))

    post simulate_debt_optimization_strategy_path(baseline_strategy)

    assert_redirected_to debt_optimization_strategy_path(baseline_strategy)
    assert_equal "Simulation failed: Test error", flash[:alert]
  end
end
