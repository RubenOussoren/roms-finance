require "test_helper"

class AccountAccessibleTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @admin = users(:family_admin)
    @member = users(:family_member)
    @account = accounts(:depository)
  end

  # --- Scope: owned_by ---
  test "owned_by returns accounts created by user" do
    results = @family.accounts.owned_by(@admin)
    assert_includes results, @account
    assert results.all? { |a| a.created_by_user_id == @admin.id }
  end

  test "owned_by returns empty for user with no accounts" do
    results = @family.accounts.owned_by(@member)
    assert_empty results
  end

  # --- Scope: accessible_by ---
  test "accessible_by includes owned accounts" do
    results = @family.accounts.accessible_by(@admin)
    assert_includes results, @account
  end

  test "accessible_by includes accounts with no permission row (default full)" do
    results = @family.accounts.accessible_by(@member)
    assert_includes results, @account
  end

  test "accessible_by includes accounts with full permission" do
    AccountPermission.create!(account: @account, user: @member, visibility: "full")
    results = @family.accounts.accessible_by(@member)
    assert_includes results, @account
  end

  test "accessible_by includes accounts with balance_only permission" do
    AccountPermission.create!(account: @account, user: @member, visibility: "balance_only")
    results = @family.accounts.accessible_by(@member)
    assert_includes results, @account
  end

  test "accessible_by excludes accounts with hidden permission" do
    AccountPermission.create!(account: @account, user: @member, visibility: "hidden")
    results = @family.accounts.accessible_by(@member)
    assert_not_includes results, @account
  end

  # --- Scope: full_access_for ---
  test "full_access_for includes owned accounts" do
    results = @family.accounts.full_access_for(@admin)
    assert_includes results, @account
  end

  test "full_access_for includes accounts with no permission row (default full)" do
    results = @family.accounts.full_access_for(@member)
    assert_includes results, @account
  end

  test "full_access_for includes accounts with explicit full permission" do
    AccountPermission.create!(account: @account, user: @member, visibility: "full")
    results = @family.accounts.full_access_for(@member)
    assert_includes results, @account
  end

  test "full_access_for excludes accounts with balance_only permission" do
    AccountPermission.create!(account: @account, user: @member, visibility: "balance_only")
    results = @family.accounts.full_access_for(@member)
    assert_not_includes results, @account
  end

  test "full_access_for excludes accounts with hidden permission" do
    AccountPermission.create!(account: @account, user: @member, visibility: "hidden")
    results = @family.accounts.full_access_for(@member)
    assert_not_includes results, @account
  end

  # --- Scope: balance_only_for ---
  test "balance_only_for returns accounts with balance_only permission" do
    AccountPermission.create!(account: @account, user: @member, visibility: "balance_only")
    results = @family.accounts.balance_only_for(@member)
    assert_includes results, @account
  end

  test "balance_only_for excludes owned accounts even with balance_only" do
    # Owner can't have permission rows (validated), so this scope should be empty for owner
    results = @family.accounts.balance_only_for(@admin)
    assert_empty results
  end

  # --- Scope: hidden_from ---
  test "hidden_from returns accounts with hidden permission" do
    AccountPermission.create!(account: @account, user: @member, visibility: "hidden")
    results = @family.accounts.hidden_from(@member)
    assert_includes results, @account
  end

  test "hidden_from does not include accounts without hidden permission" do
    results = @family.accounts.hidden_from(@member)
    assert_not_includes results, @account
  end

  # --- Instance method: owned_by? ---
  test "owned_by? returns true for account owner" do
    assert @account.owned_by?(@admin)
  end

  test "owned_by? returns false for non-owner" do
    assert_not @account.owned_by?(@member)
  end

  # --- Instance method: visibility_for ---
  test "visibility_for returns full for owner" do
    assert_equal :full, @account.visibility_for(@admin)
  end

  test "visibility_for returns full when no permission row exists" do
    assert_equal :full, @account.visibility_for(@member)
  end

  test "visibility_for returns balance_only when permission says balance_only" do
    AccountPermission.create!(account: @account, user: @member, visibility: "balance_only")
    assert_equal :balance_only, @account.visibility_for(@member)
  end

  test "visibility_for returns hidden when permission says hidden" do
    AccountPermission.create!(account: @account, user: @member, visibility: "hidden")
    assert_equal :hidden, @account.visibility_for(@member)
  end

  test "visibility_for returns full for joint accounts regardless of permission" do
    @account.update_column(:is_joint, true)
    # Joint accounts can't have non-full permissions (validated), but even if somehow present
    # the method returns :full for joint accounts
    assert_equal :full, @account.visibility_for(@member)
  end

  # --- Instance method: accessible_by? ---
  test "accessible_by? returns true when no permission row" do
    assert @account.accessible_by?(@member)
  end

  test "accessible_by? returns true for owner" do
    assert @account.accessible_by?(@admin)
  end

  test "accessible_by? returns false when hidden" do
    AccountPermission.create!(account: @account, user: @member, visibility: "hidden")
    assert_not @account.accessible_by?(@member)
  end

  # --- Instance method: full_access_for? ---
  test "full_access_for? returns true for owner" do
    assert @account.full_access_for?(@admin)
  end

  test "full_access_for? returns true when no permission row" do
    assert @account.full_access_for?(@member)
  end

  test "full_access_for? returns false when balance_only" do
    AccountPermission.create!(account: @account, user: @member, visibility: "balance_only")
    assert_not @account.full_access_for?(@member)
  end

  # --- Instance method: balance_only_for? ---
  test "balance_only_for? returns true when balance_only" do
    AccountPermission.create!(account: @account, user: @member, visibility: "balance_only")
    assert @account.balance_only_for?(@member)
  end

  test "balance_only_for? returns false when full" do
    assert_not @account.balance_only_for?(@member)
  end
end
