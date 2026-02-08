require "test_helper"

class AccountTest < ActiveSupport::TestCase
  include SyncableInterfaceTest, EntriesTestHelper

  setup do
    @account = @syncable = accounts(:depository)
    @family = families(:dylan_family)
  end

  test "can destroy" do
    assert_difference "Account.count", -1 do
      @account.destroy
    end
  end

  test "gets short/long subtype label" do
    account = @family.accounts.create!(
      name: "Test Investment",
      balance: 1000,
      currency: "USD",
      subtype: "hsa",
      accountable: Investment.new
    )

    assert_equal "HSA", account.short_subtype_label
    assert_equal "Health Savings Account (HSA)", account.long_subtype_label

    # Test with nil subtype
    account.update!(subtype: nil)
    assert_equal "Investments", account.short_subtype_label
    assert_equal "Investments", account.long_subtype_label
  end

  # Projectable concern tests
  test "account can generate adaptive projection" do
    projection = @account.adaptive_projection(years: 1)

    assert_kind_of Array, projection
    assert_equal 12, projection.length
    assert projection.first[:balance] >= @account.balance
  end

  test "account has milestones association" do
    assert_respond_to @account, :milestones
    assert_respond_to @account, :projections
  end

  test "account can track next milestone" do
    milestone = @account.milestones.create!(
      name: "Test Goal",
      target_amount: @account.balance + 10_000,
      currency: @account.currency,
      status: "pending",
      progress_percentage: 0
    )

    assert_equal milestone, @account.next_milestone
  end

  # JurisdictionAware concern tests
  test "account inherits jurisdiction from family" do
    @family.update!(country: "CA")

    jurisdiction = @account.jurisdiction

    assert_not_nil jurisdiction
    assert_equal "CA", jurisdiction.country_code
  end

  test "account gets projection standard from jurisdiction" do
    @family.update!(country: "CA")

    assert_respond_to @account, :projection_standard
    assert_respond_to @account, :tax_calculator_config
  end

  # DataQualityCheckable concern tests
  test "account reports data quality issues for missing balance" do
    @account.balance = nil
    issues = @account.data_quality_issues

    issue = issues.find { |i| i[:field] == :balance && i[:severity] == :error }
    assert_not_nil issue
    assert_equal "Update balance", issue[:action_text]
    assert_equal :edit, issue[:action_path]
    assert_includes issue[:message], @account.name
  end

  test "account reports data quality warning for negative balance" do
    @account.balance = -100
    issues = @account.data_quality_issues

    issue = issues.find { |i| i[:field] == :balance && i[:severity] == :warning }
    assert_not_nil issue
    assert_equal "Review transactions", issue[:action_text]
    assert_equal :show, issue[:action_path]
  end

  test "account data quality score reflects projection status" do
    # Account without projection_assumption gets info-level warning (2 point deduction)
    assert_equal 98, @account.data_quality_score
  end

  test "account data quality acceptable returns true for valid account" do
    assert @account.data_quality_acceptable?
  end

  test "account reports actionable stale data warning" do
    @account.update_column(:updated_at, 31.days.ago)
    issues = @account.data_quality_issues

    issue = issues.find { |i| i[:field] == :updated_at && i[:severity] == :warning }
    assert_not_nil issue
    assert_equal "Refresh account", issue[:action_text]
    assert_equal :show, issue[:action_path]
  end

  test "account reports missing projection assumptions" do
    issues = @account.data_quality_issues

    issue = issues.find { |i| i[:field] == :projection_assumptions && i[:severity] == :info }
    assert_not_nil issue
    assert_equal "Set up projections", issue[:action_text]
    assert_equal :edit, issue[:action_path]
  end
end
