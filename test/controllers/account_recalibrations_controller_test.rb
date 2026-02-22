require "test_helper"

class AccountRecalibrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @family = families(:dylan_family)

    @mortgage_loan = Loan.create!(
      interest_rate: 4.9,
      term_months: 360,
      rate_type: "fixed",
      origination_date: Date.new(2024, 7, 1)
    )

    @mortgage = Account.create!(
      family: @family,
      created_by_user: @user,
      name: "TD Mortgage",
      balance: 800000,
      currency: "CAD",
      subtype: "mortgage",
      accountable: @mortgage_loan
    )
  end

  test "new renders recalibration form" do
    get new_account_recalibration_path(@mortgage)
    assert_response :success
  end

  test "create updates calibrated balance and date" do
    post account_recalibration_path(@mortgage), params: {
      recalibration: {
        balance: "760000",
        date: "2026-02-01"
      }
    }

    assert_redirected_to account_path(@mortgage)

    @mortgage_loan.reload
    assert_equal 760000, @mortgage_loan.calibrated_balance.to_f
    assert_equal Date.new(2026, 2, 1), @mortgage_loan.calibrated_at
  end

  test "create defaults date to today when not provided" do
    post account_recalibration_path(@mortgage), params: {
      recalibration: {
        balance: "760000",
        date: ""
      }
    }

    assert_redirected_to account_path(@mortgage)

    @mortgage_loan.reload
    assert_equal Date.current, @mortgage_loan.calibrated_at
  end
end
