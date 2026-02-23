require "test_helper"

class BalanceSheetTest < ActiveSupport::TestCase
  setup do
    @family = families(:empty)
    @user = users(:empty)
  end

  test "calculates total assets" do
    assert_equal 0, BalanceSheet.new(@family).assets.total

    create_account(balance: 1000, accountable: Depository.new)
    create_account(balance: 5000, accountable: OtherAsset.new)
    create_account(balance: 10000, accountable: CreditCard.new) # ignored

    assert_equal 1000 + 5000, BalanceSheet.new(@family).assets.total
  end

  test "calculates total liabilities" do
    assert_equal 0, BalanceSheet.new(@family).liabilities.total

    create_account(balance: 1000, accountable: CreditCard.new)
    create_account(balance: 5000, accountable: OtherLiability.new)
    create_account(balance: 10000, accountable: Depository.new) # ignored

    assert_equal 1000 + 5000, BalanceSheet.new(@family).liabilities.total
  end

  test "calculates net worth" do
    assert_equal 0, BalanceSheet.new(@family).net_worth

    create_account(balance: 1000, accountable: CreditCard.new)
    create_account(balance: 50000, accountable: Depository.new)

    assert_equal 50000 - 1000, BalanceSheet.new(@family).net_worth
  end

  test "disabled accounts do not affect totals" do
    create_account(balance: 1000, accountable: CreditCard.new)
    create_account(balance: 10000, accountable: Depository.new)

    other_liability = create_account(balance: 5000, accountable: OtherLiability.new)
    other_liability.disable!

    assert_equal 10000 - 1000, BalanceSheet.new(@family).net_worth
    assert_equal 10000, BalanceSheet.new(@family).assets.total
    assert_equal 1000, BalanceSheet.new(@family).liabilities.total
  end

  test "calculates asset group totals" do
    create_account(balance: 1000, accountable: Depository.new)
    create_account(balance: 2000, accountable: Depository.new)
    create_account(balance: 3000, accountable: Investment.new)
    create_account(balance: 5000, accountable: OtherAsset.new)
    create_account(balance: 10000, accountable: CreditCard.new) # ignored

    asset_groups = BalanceSheet.new(@family).assets.account_groups

    assert_equal 3, asset_groups.size
    assert_equal 1000 + 2000, asset_groups.find { |ag| ag.name == "Cash" }.total
    assert_equal 3000, asset_groups.find { |ag| ag.name == "Investments" }.total
    assert_equal 5000, asset_groups.find { |ag| ag.name == "Other Assets" }.total
  end

  test "calculates liability group totals" do
    create_account(balance: 1000, accountable: CreditCard.new)
    create_account(balance: 2000, accountable: CreditCard.new)
    create_account(balance: 3000, accountable: OtherLiability.new)
    create_account(balance: 5000, accountable: OtherLiability.new)
    create_account(balance: 10000, accountable: Depository.new) # ignored

    liability_groups = BalanceSheet.new(@family).liabilities.account_groups

    assert_equal 2, liability_groups.size
    assert_equal 1000 + 2000, liability_groups.find { |ag| ag.name == "Credit Cards" }.total
    assert_equal 3000 + 5000, liability_groups.find { |ag| ag.name == "Other Liabilities" }.total
  end

  # --- Phase 2: Viewer/Scope tests ---

  test "personal scope only includes owned accounts" do
    other_user = create_family_user

    owned = create_account(balance: 1000, accountable: Depository.new, created_by_user: @user)
    _other = create_account(balance: 2000, accountable: Depository.new, created_by_user: other_user)

    bs = BalanceSheet.new(@family, viewer: @user, scope: :personal)
    assert_equal 1000, bs.net_worth
  end

  test "household scope includes accessible accounts and excludes hidden" do
    other_user = create_family_user

    owned = create_account(balance: 1000, accountable: Depository.new, created_by_user: @user)
    full_access = create_account(balance: 2000, accountable: Depository.new, created_by_user: other_user)
    balance_only = create_account(balance: 3000, accountable: Depository.new, created_by_user: other_user)
    hidden = create_account(balance: 5000, accountable: Depository.new, created_by_user: other_user)

    AccountPermission.create!(account: balance_only, user: @user, visibility: "balance_only")
    AccountPermission.create!(account: hidden, user: @user, visibility: "hidden")

    bs = BalanceSheet.new(@family, viewer: @user, scope: :household)
    # owned (1000) + full_access (2000, no permission row = full) + balance_only (3000) = 6000
    # hidden (5000) excluded
    assert_equal 6000, bs.net_worth
  end

  test "no viewer returns all family accounts" do
    other_user = create_family_user

    create_account(balance: 1000, accountable: Depository.new, created_by_user: @user)
    create_account(balance: 2000, accountable: Depository.new, created_by_user: other_user)

    bs = BalanceSheet.new(@family)
    assert_equal 3000, bs.net_worth
  end

  test "balance_only accounts included in household net worth sum" do
    other_user = create_family_user

    owned = create_account(balance: 1000, accountable: Depository.new, created_by_user: @user)
    balance_only = create_account(balance: 3000, accountable: Depository.new, created_by_user: other_user)
    AccountPermission.create!(account: balance_only, user: @user, visibility: "balance_only")

    bs = BalanceSheet.new(@family, viewer: @user, scope: :household)
    assert_equal 4000, bs.net_worth
  end

  test "Family#balance_sheet_for returns scoped balance sheet" do
    bs = @family.balance_sheet_for(@user, scope: :personal)
    assert_instance_of BalanceSheet, bs
    assert_equal @user, bs.viewer
    assert_equal :personal, bs.scope
  end

  # --- Fractional ownership tests ---

  test "personal scope with 50/50 ownership shows half balance" do
    other_user = create_family_user

    house = create_account(balance: 500000, accountable: Property.new, created_by_user: @user)
    AccountOwnership.create!(account: house, user: @user, percentage: 50)
    AccountOwnership.create!(account: house, user: other_user, percentage: 50)

    bs = BalanceSheet.new(@family, viewer: @user, scope: :personal)
    assert_equal 250000, bs.net_worth
  end

  test "personal scope with 60/40 ownership shows correct fraction" do
    other_user = create_family_user

    house = create_account(balance: 100000, accountable: Property.new, created_by_user: @user)
    AccountOwnership.create!(account: house, user: @user, percentage: 60)
    AccountOwnership.create!(account: house, user: other_user, percentage: 40)

    bs_user = BalanceSheet.new(@family, viewer: @user, scope: :personal)
    assert_equal 60000, bs_user.net_worth

    bs_other = BalanceSheet.new(@family, viewer: other_user, scope: :personal)
    assert_equal 40000, bs_other.net_worth
  end

  test "personal scope without ownership records shows full balance for owner" do
    _other_user = create_family_user

    create_account(balance: 10000, accountable: Depository.new, created_by_user: @user)

    bs = BalanceSheet.new(@family, viewer: @user, scope: :personal)
    assert_equal 10000, bs.net_worth
  end

  test "personal scope without ownership records shows zero for non-owner" do
    other_user = create_family_user

    create_account(balance: 10000, accountable: Depository.new, created_by_user: @user)

    bs = BalanceSheet.new(@family, viewer: other_user, scope: :personal)
    assert_equal 0, bs.net_worth
  end

  test "personal scope joint account with no records splits equally" do
    other_user = create_family_user

    joint = create_account(balance: 10000, accountable: Depository.new, created_by_user: @user)
    joint.update_column(:is_joint, true)

    member_count = @family.users.count
    expected_share = (10000.0 / member_count).round

    bs = BalanceSheet.new(@family, viewer: @user, scope: :personal)
    assert_in_delta expected_share, bs.net_worth, 1

    bs_other = BalanceSheet.new(@family, viewer: other_user, scope: :personal)
    assert_in_delta expected_share, bs_other.net_worth, 1
  end

  test "household scope ignores ownership fractions" do
    other_user = create_family_user

    house = create_account(balance: 500000, accountable: Property.new, created_by_user: @user)
    AccountOwnership.create!(account: house, user: @user, percentage: 50)
    AccountOwnership.create!(account: house, user: other_user, percentage: 50)

    bs = BalanceSheet.new(@family, viewer: @user, scope: :household)
    assert_equal 500000, bs.net_worth
  end

  test "no viewer ignores ownership fractions" do
    other_user = create_family_user

    house = create_account(balance: 500000, accountable: Property.new, created_by_user: @user)
    AccountOwnership.create!(account: house, user: @user, percentage: 50)
    AccountOwnership.create!(account: house, user: other_user, percentage: 50)

    bs = BalanceSheet.new(@family)
    assert_equal 500000, bs.net_worth
  end

  test "personal scope with mix of owned and fractional accounts" do
    other_user = create_family_user

    # Fully owned by user
    _checking = create_account(balance: 5000, accountable: Depository.new, created_by_user: @user)
    # 50/50 shared property
    house = create_account(balance: 400000, accountable: Property.new, created_by_user: @user)
    AccountOwnership.create!(account: house, user: @user, percentage: 50)
    AccountOwnership.create!(account: house, user: other_user, percentage: 50)
    # Owned by other user (should not appear)
    _other_savings = create_account(balance: 20000, accountable: Depository.new, created_by_user: other_user)

    bs = BalanceSheet.new(@family, viewer: @user, scope: :personal)
    # 5000 (fully owned) + 200000 (50% of 400k) = 205000
    assert_equal 205000, bs.net_worth
  end

  test "Family#multi_user? returns false for single-user family" do
    # empty family only has one user after removing the extra ones
    single_user_family = Family.create!(name: "Single", currency: "USD", country: "US", locale: "en", date_format: "%Y-%m-%d")
    single_user_family.users.create!(first_name: "Solo", last_name: "User", email: "solo@test.com", password: "password123")
    refute single_user_family.multi_user?
  end

  test "Family#multi_user? returns true for multi-user family" do
    assert families(:dylan_family).multi_user?
  end

  private
    def create_account(attributes = {})
      attrs = { name: "Test", currency: "USD", created_by_user: @user }.merge(attributes)
      account = @family.accounts.create!(**attrs)
      account
    end

    def create_family_user
      @family.users.create!(
        first_name: "Other",
        last_name: "User",
        email: "other_#{SecureRandom.hex(4)}@test.com",
        password: "password123"
      )
    end
end
