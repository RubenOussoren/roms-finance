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

  test "scopes match predicates when only another member has a permission" do
    other_member = @family.users.create!(
      first_name: "Other", last_name: "Member", email: "access_other@example.com", password: "password123"
    )
    %w[full balance_only hidden].each do |visibility|
      permission = AccountPermission.create!(account: @account, user: other_member, visibility: visibility)
      assert_equal :full, @account.visibility_for(@member)
      assert_visibility_scopes_match(@member)
      permission.destroy!
    end
  end

  test "scopes match predicates for every viewer permission and default" do
    assert_visibility_scopes_match(@member)
    %w[full balance_only hidden].each do |visibility|
      permission = AccountPermission.create!(account: @account, user: @member, visibility: visibility)
      assert_visibility_scopes_match(@member)
      assert_visibility_scopes_match(@admin)
      permission.destroy!
    end
  end

  test "joint accounts override existing hidden permissions in scopes and predicates" do
    AccountPermission.create!(account: @account, user: @member, visibility: "hidden")
    @account.update!(is_joint: true)

    assert_equal :full, @account.visibility_for(@member)
    assert_visibility_scopes_match(@member)
  end

  test "joint accounts override existing balance only permissions in scopes and predicates" do
    AccountPermission.create!(account: @account, user: @member, visibility: "balance_only")
    @account.update!(is_joint: true)

    assert_equal :full, @account.visibility_for(@member)
    assert_visibility_scopes_match(@member)
  end

  test "creator overrides existing restrictions in scopes and predicates" do
    AccountPermission.create!(account: @account, user: @member, visibility: "hidden")
    @account.update!(created_by_user: @member)

    assert_equal :full, @account.visibility_for(@member)
    assert_visibility_scopes_match(@member)
  end

  test "visibility scopes preserve the family boundary of their input relation" do
    foreign_account = accounts(:other_asset)
    foreign_account.update!(family: families(:empty), created_by_user: users(:empty), is_joint: true)
    AccountPermission.create!(account: @account, user: @member, visibility: "balance_only")

    assert_visibility_scopes_match(@member)
    %i[accessible_by full_access_for balance_only_for hidden_from].each do |scope|
      assert_not_includes @family.accounts.public_send(scope, @member).pluck(:id), foreign_account.id
      assert_empty families(:empty).accounts.public_send(scope, @member).where(id: @account.id).pluck(:id)
    end
  end

  private

    def assert_visibility_scopes_match(user)
      accounts = @family.accounts.to_a
      {
        accessible_by: ->(account) { account.accessible_by?(user) },
        full_access_for: ->(account) { account.full_access_for?(user) },
        balance_only_for: ->(account) { account.balance_only_for?(user) },
        hidden_from: ->(account) { account.visibility_for(user) == :hidden }
      }.each do |scope, predicate|
        expected_ids = accounts.select(&predicate).map(&:id).sort
        actual_ids = @family.accounts.public_send(scope, user).pluck(:id).sort
        assert_equal expected_ids, actual_ids, "#{scope} must match instance visibility"
      end
    end
end
