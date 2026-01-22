require "test_helper"

class UI::Account::MilestoneTrackerTest < ActiveSupport::TestCase
  setup do
    @investment_account = accounts(:investment)
  end

  test "initializes with account" do
    component = UI::Account::MilestoneTracker.new(account: @investment_account)
    assert_equal @investment_account, component.account
  end

  test "milestones returns ordered milestones for account" do
    component = UI::Account::MilestoneTracker.new(account: @investment_account)
    milestones = component.milestones

    assert_kind_of ActiveRecord::Relation, milestones
    assert milestones.all? { |m| m.account == @investment_account }
  end

  test "next_milestone returns account next_milestone" do
    component = UI::Account::MilestoneTracker.new(account: @investment_account)
    # Assuming Account#next_milestone is defined
    assert_equal @investment_account.next_milestone, component.next_milestone
  end

  test "achieved_milestones returns only achieved milestones" do
    milestone = milestones(:first_100k)
    milestone.update!(status: "achieved")

    component = UI::Account::MilestoneTracker.new(account: @investment_account)
    achieved = component.achieved_milestones

    assert achieved.all?(&:achieved?)
  end

  test "pending_milestones returns pending and in_progress milestones" do
    component = UI::Account::MilestoneTracker.new(account: @investment_account)
    pending = component.pending_milestones

    assert pending.all? { |m| m.status.in?(%w[pending in_progress]) }
  end

  test "has_milestones? returns true when milestones exist" do
    component = UI::Account::MilestoneTracker.new(account: @investment_account)
    assert component.has_milestones?
  end

  test "has_milestones? returns false when no milestones" do
    new_account = Account.create!(
      family: families(:dylan_family),
      name: "Empty Account",
      balance: 1000,
      currency: "USD",
      accountable: Depository.create!
    )

    component = UI::Account::MilestoneTracker.new(account: new_account)
    assert_not component.has_milestones?
  end

  test "achieved_count returns count of achieved milestones" do
    component = UI::Account::MilestoneTracker.new(account: @investment_account)
    assert_kind_of Integer, component.achieved_count
  end

  test "total_count returns total milestone count" do
    component = UI::Account::MilestoneTracker.new(account: @investment_account)
    assert_equal component.milestones.count, component.total_count
  end
end
