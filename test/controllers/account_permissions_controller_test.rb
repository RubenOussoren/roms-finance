require "test_helper"

class AccountPermissionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:family_admin)
    @member = users(:family_member)
    @account = accounts(:depository) # owned by family_admin
    sign_in @owner
  end

  test "owner can access edit privacy settings" do
    get edit_account_account_permissions_url(@account)
    assert_response :success
  end

  test "non-owner is redirected from edit" do
    sign_in @member
    get edit_account_account_permissions_url(@account)
    assert_redirected_to account_path(@account)
    assert_equal "Only the account owner can manage privacy settings", flash[:alert]
  end

  test "single-user family gets 404" do
    # Stub multi_user? to return false to test the single-user guard
    Family.any_instance.stubs(:multi_user?).returns(false)
    sign_in @owner

    get edit_account_account_permissions_url(@account)
    assert_response :not_found
  end

  test "owner can update permissions to balance_only" do
    patch account_account_permissions_url(@account), params: {
      permissions: { @member.id => "balance_only" }
    }

    assert_redirected_to account_path(@account)
    permission = @account.account_permissions.find_by(user_id: @member.id)
    assert_equal "balance_only", permission.visibility
  end

  test "owner can update permissions to hidden" do
    patch account_account_permissions_url(@account), params: {
      permissions: { @member.id => "hidden" }
    }

    assert_redirected_to account_path(@account)
    permission = @account.account_permissions.find_by(user_id: @member.id)
    assert_equal "hidden", permission.visibility
  end

  test "setting permission to full deletes the row" do
    # First create a permission row
    @account.account_permissions.create!(user: @member, visibility: "hidden")

    patch account_account_permissions_url(@account), params: {
      permissions: { @member.id => "full" }
    }

    assert_redirected_to account_path(@account)
    assert_nil @account.account_permissions.find_by(user_id: @member.id)
  end

  test "upsert updates existing permission" do
    @account.account_permissions.create!(user: @member, visibility: "hidden")

    patch account_account_permissions_url(@account), params: {
      permissions: { @member.id => "balance_only" }
    }

    assert_redirected_to account_path(@account)
    permission = @account.account_permissions.find_by(user_id: @member.id)
    assert_equal "balance_only", permission.visibility
  end

  test "joint account edit shows info but no submit" do
    @account.update!(is_joint: true)
    get edit_account_account_permissions_url(@account)
    assert_response :success
    assert_select "select[disabled]"
  end

  test "non-owner cannot update permissions" do
    sign_in @member
    patch account_account_permissions_url(@account), params: {
      permissions: { @member.id => "hidden" }
    }
    assert_redirected_to account_path(@account)
    assert_nil @account.account_permissions.find_by(user_id: @member.id)
  end
end
