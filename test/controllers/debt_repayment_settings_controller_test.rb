require "test_helper"

class DebtRepaymentSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
    sign_in @user

    @loan_account = accounts(:loan)
  end

  test "update creates account-specific assumption with debt settings" do
    assert_nil @loan_account.projection_assumption

    patch account_debt_repayment_settings_path(@loan_account), params: {
      extra_monthly_payment: "500",
      target_payoff_date: "2030-12-31"
    }

    assert_redirected_to projections_path(tab: "debt")

    @loan_account.reload
    account_assumption = @loan_account.projection_assumption
    assert_not_nil account_assumption
    assert_in_delta 500.0, account_assumption.extra_monthly_payment, 0.01
    assert_equal Date.parse("2030-12-31"), account_assumption.target_payoff_date
  end

  test "update with extra payment only" do
    patch account_debt_repayment_settings_path(@loan_account), params: {
      extra_monthly_payment: "200"
    }

    assert_redirected_to projections_path(tab: "debt")

    @loan_account.reload
    account_assumption = @loan_account.projection_assumption
    assert_not_nil account_assumption
    assert_in_delta 200.0, account_assumption.extra_monthly_payment, 0.01
    assert_nil account_assumption.target_payoff_date
  end

  test "update responds with turbo stream" do
    patch account_debt_repayment_settings_path(@loan_account), params: {
      extra_monthly_payment: "300"
    }, as: :turbo_stream

    assert_response :success
    assert_match "turbo-stream", response.content_type
  end

  test "reset clears debt settings" do
    # Create account-specific assumption with debt settings
    assumption = ProjectionAssumption.create_for_account(@loan_account)
    assumption.update!(
      extra_monthly_payment: 500,
      target_payoff_date: Date.parse("2030-12-31")
    )

    @loan_account.reload
    assert @loan_account.projection_assumption.debt_settings?

    delete reset_account_debt_repayment_settings_path(@loan_account)

    assert_redirected_to projections_path(tab: "debt")

    @loan_account.reload
    assert_in_delta 0, @loan_account.projection_assumption.extra_monthly_payment.to_f, 0.01
    assert_nil @loan_account.projection_assumption.target_payoff_date
  end

  test "reset responds with turbo stream" do
    # Create account-specific assumption with debt settings
    ProjectionAssumption.create_for_account(@loan_account, {
      extra_monthly_payment: 500
    })

    delete reset_account_debt_repayment_settings_path(@loan_account), as: :turbo_stream

    assert_response :success
    assert_match "turbo-stream", response.content_type
  end

  test "requires authentication" do
    reset!

    patch account_debt_repayment_settings_path(@loan_account), params: {
      extra_monthly_payment: "500"
    }

    assert_redirected_to new_session_path
  end

  test "cannot access other family accounts" do
    other_family = Family.create!(name: "Other Family", currency: "USD", country: "US")
    other_loan = Loan.create!(interest_rate: 5.0)
    other_account = Account.create!(
      family: other_family,
      name: "Other Loan",
      balance: -100000,
      currency: "USD",
      accountable: other_loan
    )

    patch account_debt_repayment_settings_path(other_account), params: {
      extra_monthly_payment: "500"
    }

    assert_response :not_found
  end
end
