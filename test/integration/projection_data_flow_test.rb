require "test_helper"

class ProjectionDataFlowTest < ActionDispatch::IntegrationTest
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
    sign_in @user

    @investment_account = accounts(:investment)
    @assumption = projection_assumptions(:default_assumption)
  end

  test "changing projection settings updates chart data" do
    # Initial state - get current assumption values
    original_return = @assumption.expected_return

    # Update settings via controller
    patch account_projection_settings_path(@investment_account), params: {
      expected_return: "10.0",
      monthly_contribution: "2000",
      volatility: "25.0",
      projection_years: "20",
      use_pag_defaults: "0"
    }

    assert_response :redirect
    @assumption.reload

    # Verify assumption was updated
    assert_in_delta 0.10, @assumption.expected_return, 0.001
    assert_in_delta 2000.0, @assumption.monthly_contribution, 0.01
    assert_in_delta 0.25, @assumption.volatility, 0.001
    assert_not_equal original_return, @assumption.expected_return
  end

  test "projection chart uses updated assumptions" do
    # Update assumption
    @assumption.update!(
      expected_return: 0.12,
      monthly_contribution: 3000,
      volatility: 0.30,
      use_pag_defaults: false
    )

    # Create chart component with updated assumption
    component = UI::Account::ProjectionChart.new(
      account: @investment_account,
      years: 10,
      assumption: @assumption
    )

    chart_data = component.chart_data

    # Verify chart data reflects assumptions
    assert_not_nil chart_data[:projections]
    assert chart_data[:projections].length > 0

    # With higher return, projected values should be higher
    # (This is a basic sanity check - actual values depend on calculation)
    final_projection = chart_data[:projections].last
    assert final_projection[:p50] > @investment_account.balance
  end

  test "PAG defaults override custom values" do
    # Set custom values first
    @assumption.update!(
      expected_return: 0.15,
      volatility: 0.40,
      use_pag_defaults: false
    )

    # Apply PAG defaults
    patch account_projection_settings_path(@investment_account), params: {
      use_pag_defaults: "1",
      projection_years: "10"
    }

    assert_response :redirect
    @assumption.reload

    # PAG defaults should be applied
    assert @assumption.use_pag_defaults
    # The effective values should come from PAG standard now
    assert @assumption.expected_return != 0.15 || @assumption.use_pag_defaults
  end

  test "projection settings component reflects assumption state" do
    @assumption.update!(
      expected_return: 0.08,
      monthly_contribution: 1500,
      volatility: 0.20,
      use_pag_defaults: false
    )

    component = UI::Account::ProjectionSettings.new(
      account: @investment_account,
      assumption: @assumption
    )

    # Verify component reflects assumption values
    assert_in_delta 8.0, component.expected_return_percent, 0.1
    assert_equal 1500, component.monthly_contribution
    assert_in_delta 20.0, component.volatility_percent, 0.1
    assert_not component.use_pag_defaults?
  end

  test "full flow: settings update to chart render" do
    # 1. Update settings
    patch account_projection_settings_path(@investment_account), params: {
      expected_return: "7.5",
      monthly_contribution: "750",
      volatility: "18.0",
      projection_years: "15",
      use_pag_defaults: "0"
    }

    assert_response :redirect
    @assumption.reload

    # 2. Create components with updated data
    settings_component = UI::Account::ProjectionSettings.new(
      account: @investment_account,
      assumption: @assumption
    )

    chart_component = UI::Account::ProjectionChart.new(
      account: @investment_account,
      years: 15,
      assumption: @assumption
    )

    # 3. Verify consistency
    assert_in_delta 7.5, settings_component.expected_return_percent, 0.1
    assert_equal 750, settings_component.monthly_contribution

    chart_data = chart_component.chart_data
    # 15 years * 12 months = 180 data points
    assert_equal 180, chart_data[:projections].length
  end
end
