require "test_helper"

class ProjectionSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
    sign_in @user

    @investment_account = accounts(:investment)
    @family_assumption = projection_assumptions(:default_assumption)
  end

  test "update creates account-specific assumption with custom values" do
    assert_nil @investment_account.projection_assumption

    patch account_projection_settings_path(@investment_account), params: {
      expected_return: "8.0",
      monthly_contribution: "1000",
      volatility: "20.0",
      projection_years: "15",
      use_pag_defaults: "0"
    }

    assert_redirected_to projections_path(tab: "investments")

    @investment_account.reload
    account_assumption = @investment_account.projection_assumption
    assert_not_nil account_assumption
    assert_equal false, account_assumption.use_pag_defaults
    assert_in_delta 0.08, account_assumption.expected_return, 0.001
    assert_in_delta 0.20, account_assumption.volatility, 0.001
    assert_in_delta 1000.0, account_assumption.monthly_contribution, 0.01
  end

  test "update with PAG defaults applies standard assumptions to account" do
    # First create account-specific assumption with custom values
    account_assumption = ProjectionAssumption.create_for_account(@investment_account, {
      expected_return: 0.10,
      use_pag_defaults: false
    })

    patch account_projection_settings_path(@investment_account), params: {
      use_pag_defaults: "1",
      projection_years: "10"
    }

    assert_redirected_to projections_path(tab: "investments")

    account_assumption.reload
    assert_equal true, account_assumption.use_pag_defaults
  end

  test "update responds with turbo stream" do
    patch account_projection_settings_path(@investment_account), params: {
      expected_return: "7.0",
      projection_years: "5"
    }, as: :turbo_stream

    assert_response :success
    assert_match "turbo-stream", response.content_type
  end

  test "reset deletes account-specific assumption and falls back to family default" do
    # Create account-specific assumption
    account_assumption = ProjectionAssumption.create_for_account(@investment_account, {
      expected_return: 0.15,
      monthly_contribution: 2000
    })

    assert @investment_account.reload.custom_projection_settings?

    delete reset_account_projection_settings_path(@investment_account)

    assert_redirected_to projections_path(tab: "investments")

    @investment_account.reload
    assert_not @investment_account.custom_projection_settings?
    assert_nil @investment_account.projection_assumption
  end

  test "reset responds with turbo stream" do
    # Create account-specific assumption first
    ProjectionAssumption.create_for_account(@investment_account, { expected_return: 0.12 })

    delete reset_account_projection_settings_path(@investment_account), as: :turbo_stream

    assert_response :success
    assert_match "turbo-stream", response.content_type
  end

  test "requires authentication" do
    # Reset session to test unauthenticated access
    reset!

    patch account_projection_settings_path(@investment_account), params: {
      expected_return: "8.0"
    }

    assert_redirected_to new_session_path
  end

  test "cannot access other family accounts" do
    other_family = Family.create!(name: "Other Family", currency: "USD", country: "US")
    other_account = Account.create!(
      family: other_family,
      name: "Other Investment",
      balance: 50000,
      currency: "USD",
      accountable: Investment.create!
    )

    patch account_projection_settings_path(other_account), params: {
      expected_return: "8.0"
    }

    assert_response :not_found
  end

  test "family assumption is not modified when updating account settings" do
    original_return = @family_assumption.expected_return

    patch account_projection_settings_path(@investment_account), params: {
      expected_return: "12.0",
      use_pag_defaults: "0"
    }

    @family_assumption.reload
    assert_equal original_return, @family_assumption.expected_return
  end
end
