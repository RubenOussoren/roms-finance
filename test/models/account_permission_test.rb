require "test_helper"

class AccountPermissionTest < ActiveSupport::TestCase
  setup do
    @admin = users(:family_admin)
    @member = users(:family_member)
    @account = accounts(:depository)
  end

  # Validation: visibility inclusion
  test "valid with full visibility" do
    permission = AccountPermission.new(account: @account, user: @member, visibility: "full")
    assert permission.valid?
  end

  test "valid with balance_only visibility" do
    permission = AccountPermission.new(account: @account, user: @member, visibility: "balance_only")
    assert permission.valid?
  end

  test "valid with hidden visibility" do
    permission = AccountPermission.new(account: @account, user: @member, visibility: "hidden")
    assert permission.valid?
  end

  test "invalid with unknown visibility" do
    permission = AccountPermission.new(account: @account, user: @member, visibility: "read_only")
    assert_not permission.valid?
    assert_includes permission.errors[:visibility], "is not included in the list"
  end

  # Validation: uniqueness of user scoped to account
  test "prevents duplicate permission for same user and account" do
    AccountPermission.create!(account: @account, user: @member, visibility: "full")
    duplicate = AccountPermission.new(account: @account, user: @member, visibility: "hidden")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  # Validation: user cannot be account owner
  test "owner cannot have permission row" do
    permission = AccountPermission.new(account: @account, user: @admin, visibility: "full")
    assert_not permission.valid?
    assert_includes permission.errors[:user], "cannot set permissions for the account owner"
  end

  # Validation: joint accounts must be full
  test "joint account cannot have non-full visibility" do
    @account.update_column(:is_joint, true)
    permission = AccountPermission.new(account: @account, user: @member, visibility: "hidden")
    assert_not permission.valid?
    assert_includes permission.errors[:visibility], "must be full for joint accounts"
  end

  test "joint account allows full visibility" do
    @account.update_column(:is_joint, true)
    permission = AccountPermission.new(account: @account, user: @member, visibility: "full")
    assert permission.valid?
  end

  # Scopes
  test "for_user scope returns permissions for given user" do
    p1 = AccountPermission.create!(account: @account, user: @member, visibility: "full")
    assert_includes AccountPermission.for_user(@member), p1
    assert_not_includes AccountPermission.for_user(@admin), p1
  end

  test "full_access scope returns full permissions" do
    p1 = AccountPermission.create!(account: @account, user: @member, visibility: "full")
    assert_includes AccountPermission.full_access, p1
    assert_not_includes AccountPermission.balance_only, p1
    assert_not_includes AccountPermission.hidden, p1
  end

  test "balance_only scope returns balance_only permissions" do
    p1 = AccountPermission.create!(account: @account, user: @member, visibility: "balance_only")
    assert_includes AccountPermission.balance_only, p1
    assert_not_includes AccountPermission.full_access, p1
  end

  test "hidden scope returns hidden permissions" do
    p1 = AccountPermission.create!(account: @account, user: @member, visibility: "hidden")
    assert_includes AccountPermission.hidden, p1
    assert_not_includes AccountPermission.full_access, p1
  end

  # Cache invalidation
  test "after_save touches account" do
    original_updated_at = @account.updated_at
    travel_to 1.minute.from_now do
      AccountPermission.create!(account: @account, user: @member, visibility: "full")
    end
    assert_operator @account.reload.updated_at, :>, original_updated_at
  end

  test "after_destroy touches account" do
    permission = AccountPermission.create!(account: @account, user: @member, visibility: "full")
    original_updated_at = @account.reload.updated_at
    travel_to 1.minute.from_now do
      permission.destroy!
    end
    assert_operator @account.reload.updated_at, :>, original_updated_at
  end
end
