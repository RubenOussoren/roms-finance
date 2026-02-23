require "test_helper"

class AccountOwnershipTest < ActiveSupport::TestCase
  setup do
    @admin = users(:family_admin)
    @member = users(:family_member)
    @account = accounts(:depository)
  end

  # Validation: percentage range
  test "valid with percentage between 0 and 100" do
    ownership = AccountOwnership.new(account: @account, user: @admin, percentage: 50)
    assert ownership.valid?
  end

  test "invalid with zero percentage" do
    ownership = AccountOwnership.new(account: @account, user: @admin, percentage: 0)
    assert_not ownership.valid?
  end

  test "invalid with negative percentage" do
    ownership = AccountOwnership.new(account: @account, user: @admin, percentage: -5)
    assert_not ownership.valid?
  end

  test "invalid with percentage over 100" do
    ownership = AccountOwnership.new(account: @account, user: @admin, percentage: 101)
    assert_not ownership.valid?
  end

  test "valid with 100 percent" do
    ownership = AccountOwnership.new(account: @account, user: @admin, percentage: 100)
    assert ownership.valid?
  end

  # Validation: uniqueness
  test "prevents duplicate ownership for same user and account" do
    AccountOwnership.create!(account: @account, user: @admin, percentage: 50)
    duplicate = AccountOwnership.new(account: @account, user: @admin, percentage: 30)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  # Validation: total <= 100%
  test "total percentage cannot exceed 100" do
    AccountOwnership.create!(account: @account, user: @admin, percentage: 60)
    over = AccountOwnership.new(account: @account, user: @member, percentage: 50)
    assert_not over.valid?
    assert_includes over.errors[:percentage], "total ownership cannot exceed 100%"
  end

  test "total percentage can equal 100" do
    AccountOwnership.create!(account: @account, user: @admin, percentage: 60)
    complement = AccountOwnership.new(account: @account, user: @member, percentage: 40)
    assert complement.valid?
  end

  # Validation: same family
  test "user must be in same family as account" do
    other_family = Family.create!(name: "Other", currency: "USD", country: "US", locale: "en", date_format: "%Y-%m-%d")
    other_user = other_family.users.create!(first_name: "Other", last_name: "User", email: "other_ownership@test.com", password: "password123")

    ownership = AccountOwnership.new(account: @account, user: other_user, percentage: 50)
    assert_not ownership.valid?
    assert_includes ownership.errors[:user], "must be in the same family as the account"
  end

  # Cache invalidation
  test "after_save touches account" do
    original_updated_at = @account.updated_at
    travel_to 1.minute.from_now do
      AccountOwnership.create!(account: @account, user: @admin, percentage: 50)
    end
    assert_operator @account.reload.updated_at, :>, original_updated_at
  end

  test "after_destroy touches account" do
    ownership = AccountOwnership.create!(account: @account, user: @admin, percentage: 50)
    original_updated_at = @account.reload.updated_at
    travel_to 1.minute.from_now do
      ownership.destroy!
    end
    assert_operator @account.reload.updated_at, :>, original_updated_at
  end

  # Account#ownership_fraction_for
  test "no ownership records returns 1.0 for owner" do
    assert_equal 1.0, @account.ownership_fraction_for(@admin)
  end

  test "no ownership records returns 0.0 for non-owner" do
    assert_equal 0.0, @account.ownership_fraction_for(@member)
  end

  test "joint account with no records returns equal split" do
    @account.update_column(:is_joint, true)
    member_count = @account.family.users.count
    expected = 1.0 / member_count

    assert_in_delta expected, @account.ownership_fraction_for(@admin), 0.001
    assert_in_delta expected, @account.ownership_fraction_for(@member), 0.001
  end

  test "explicit ownership records override defaults" do
    AccountOwnership.create!(account: @account, user: @admin, percentage: 60)
    AccountOwnership.create!(account: @account, user: @member, percentage: 40)

    assert_in_delta 0.6, @account.ownership_fraction_for(@admin), 0.001
    assert_in_delta 0.4, @account.ownership_fraction_for(@member), 0.001
  end

  test "user with no ownership record gets 0.0 when records exist" do
    AccountOwnership.create!(account: @account, user: @admin, percentage: 100)
    assert_in_delta 0.0, @account.ownership_fraction_for(@member), 0.001
  end
end
