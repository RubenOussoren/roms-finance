require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:depository)
  end

  test "should get index" do
    get accounts_url
    assert_response :success
  end

  test "should get show" do
    get account_url(@account)
    assert_response :success
  end

  test "balance-only viewers do not render account details or holdings requests" do
    viewer = users(:family_member)
    sign_in viewer

    %i[investment equity_compensation loan].each do |fixture|
      account = accounts(fixture)
      account.account_permissions.create!(user: viewer, visibility: "balance_only")

      get account_url(account)
      assert_response :success
      assert_select "p", text: "You have balance-only access to this account"
      assert_select "[data-testid='account-details']", count: 0
      assert_select "turbo-frame[src*='/holdings']", count: 0
      assert_select "a[href=?]", sync_account_path(account), count: 0
    end
  end

  test "full-access investment viewers still load holdings" do
    get account_url(accounts(:investment))
    assert_response :success
    assert_select "[data-testid='account-details']", count: 1
    assert_select "turbo-frame[src*='/holdings']", count: 1
  end

  test "should sync account" do
    post sync_account_url(@account)
    assert_redirected_to account_url(@account)
  end

  test "should get sparkline" do
    get sparkline_account_url(@account)
    assert_response :success
  end

  test "destroys account" do
    delete account_url(@account)
    assert_redirected_to accounts_path
    assert_enqueued_with job: DestroyJob
    assert_equal "Account scheduled for deletion", flash[:notice]
  end
end
