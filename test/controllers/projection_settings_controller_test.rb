require "test_helper"

class ProjectionSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
    sign_in @user

    @investment_account = accounts(:investment)
    @assumption = projection_assumptions(:default_assumption)
  end

  test "update with custom values modifies assumption" do
    patch account_projection_settings_path(@investment_account), params: {
      expected_return: "8.0",
      monthly_contribution: "1000",
      volatility: "20.0",
      projection_years: "15",
      use_pag_defaults: "0"
    }

    assert_redirected_to account_path(@investment_account, projection_years: 15)

    @assumption.reload
    assert_equal false, @assumption.use_pag_defaults
    assert_in_delta 0.08, @assumption.expected_return, 0.001
    assert_in_delta 0.20, @assumption.volatility, 0.001
    assert_in_delta 1000.0, @assumption.monthly_contribution, 0.01
  end

  test "update with PAG defaults applies standard assumptions" do
    @assumption.update!(use_pag_defaults: false, expected_return: 0.10)

    patch account_projection_settings_path(@investment_account), params: {
      use_pag_defaults: "1",
      projection_years: "10"
    }

    assert_redirected_to account_path(@investment_account, projection_years: 10)

    @assumption.reload
    assert_equal true, @assumption.use_pag_defaults
  end

  test "update responds with turbo stream" do
    patch account_projection_settings_path(@investment_account), params: {
      expected_return: "7.0",
      projection_years: "5"
    }, as: :turbo_stream

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

  test "update with default projection years when not provided" do
    patch account_projection_settings_path(@investment_account), params: {
      expected_return: "7.0"
    }

    assert_redirected_to account_path(@investment_account, projection_years: 10)
  end
end
