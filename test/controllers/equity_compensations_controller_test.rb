require "test_helper"

class EquityCompensationsControllerTest < ActionDispatch::IntegrationTest
  include AccountableResourceInterfaceTest

  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:equity_compensation)
  end

  test "creates equity compensation account" do
    assert_difference -> { Account.count } => 1 do
      post equity_compensations_path, params: {
        account: {
          name: "New Equity Comp",
          balance: 0,
          subtype: "rsu",
          currency: "USD",
          accountable_type: "EquityCompensation",
          accountable_attributes: {}
        }
      }
    end

    created_account = Account.order(:created_at).last
    assert created_account.accountable.is_a?(EquityCompensation)
    assert_equal "rsu", created_account.subtype
  end

  test "updates equity compensation account" do
    patch equity_compensation_path(@account), params: {
      account: {
        name: "Updated Name",
        balance: 10000,
        accountable_attributes: { id: @account.accountable_id }
      }
    }

    assert_redirected_to account_path(@account)
    assert_equal "Updated Name", @account.reload.name
  end
end
