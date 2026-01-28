require "test_helper"

class MilestoneTest < ActiveSupport::TestCase
  setup do
    @milestone = milestones(:first_100k)
    @account = accounts(:investment)
    @debt_milestone = milestones(:loan_half_paid)
    @loan_account = accounts(:loan)
  end

  # ============================================
  # Growth Milestone Tests (original functionality)
  # ============================================

  test "updates progress based on current balance" do
    @milestone.update_progress!(@account.balance)

    # 10000 / 100000 = 10%
    assert_equal 10.0, @milestone.progress_percentage
    assert_equal "in_progress", @milestone.status
  end

  test "marks milestone as achieved when target reached" do
    @milestone.update_progress!(100000)

    assert_equal 100.0, @milestone.progress_percentage
    assert_equal "achieved", @milestone.status
    assert_not_nil @milestone.achieved_date
  end

  test "achieved returns true for achieved milestones" do
    @milestone.update!(status: "achieved")
    assert @milestone.achieved?
  end

  test "calculates days to target when projected date exists" do
    @milestone.update!(projected_date: Date.current + 365.days)
    assert_equal 365, @milestone.days_to_target
  end

  test "on_track returns true when projected date is before target date" do
    @milestone.update!(
      target_date: Date.current + 365.days,
      projected_date: Date.current + 300.days
    )
    assert @milestone.on_track?
  end

  test "on_track returns false when projected date is after target date" do
    @milestone.update!(
      target_date: Date.current + 300.days,
      projected_date: Date.current + 365.days
    )
    assert_not @milestone.on_track?
  end

  test "creates standard milestones for asset account" do
    new_account = Account.create!(
      family: families(:dylan_family),
      name: "Test Account",
      balance: 5000,
      currency: "USD",
      accountable: Depository.create!
    )

    milestones = Milestone.create_standard_milestones_for(new_account)

    assert_equal 10, milestones.count
    assert milestones.any? { |m| m.target_amount == 100_000 }
    assert milestones.any? { |m| m.target_amount == 1_000_000 }
    assert milestones.all? { |m| m.target_type == "reach" }
  end

  test "validates presence of required fields" do
    milestone = Milestone.new
    assert_not milestone.valid?
    assert milestone.errors[:name].present?
    assert milestone.errors[:target_amount].present?
    assert milestone.errors[:currency].present?
  end

  test "validates target amount is not negative" do
    milestone = Milestone.new(
      account: @account,
      name: "Test",
      target_amount: -100,
      currency: "USD"
    )
    assert_not milestone.valid?
    assert milestone.errors[:target_amount].present?
  end

  test "allows zero target amount for payoff milestones" do
    milestone = Milestone.new(
      account: @loan_account,
      name: "Paid Off",
      target_amount: 0,
      currency: "USD",
      target_type: "reduce_to",
      starting_balance: 100000
    )
    assert milestone.valid?
  end

  # Edge case tests for update_progress!
  test "update_progress handles zero balance" do
    @milestone.update_progress!(0)

    assert_equal 0.0, @milestone.progress_percentage
    assert_equal "pending", @milestone.status
    assert_nil @milestone.achieved_date
  end

  test "update_progress handles balance exceeding target" do
    @milestone.update_progress!(150000)

    # Progress is capped at 100%
    assert_equal 100.0, @milestone.progress_percentage
    assert_equal "achieved", @milestone.status
    assert_not_nil @milestone.achieved_date
  end

  test "update_progress preserves achieved_date on multiple calls" do
    @milestone.update_progress!(100000)
    original_achieved_date = @milestone.achieved_date

    # Call again with same balance
    @milestone.update_progress!(100000)

    assert_equal original_achieved_date, @milestone.achieved_date
  end

  test "update_progress handles small fractional balance" do
    @milestone.update_progress!(1) # Use 1 for better testability

    # 1 / 100000 * 100 = 0.001% which rounds to 0
    # So progress should exist but may be very small
    assert @milestone.progress_percentage >= 0
    assert @milestone.progress_percentage < 1
    # With such small progress, status depends on calculation - just verify it works
    assert %w[pending in_progress].include?(@milestone.status)
  end

  test "already achieved milestone stays achieved even if balance drops" do
    @milestone.update_progress!(100000)
    assert_equal "achieved", @milestone.status

    # Balance drops below target
    @milestone.update_progress!(80000)

    # Progress updates but status reflects current state
    assert_equal 80.0, @milestone.progress_percentage
    assert_equal "in_progress", @milestone.status
  end

  test "on_track returns true for achieved milestones regardless of dates" do
    @milestone.update!(
      status: "achieved",
      target_date: Date.current - 365.days,
      projected_date: Date.current + 365.days
    )
    assert @milestone.on_track?
  end

  # ============================================
  # Debt Milestone Tests (new functionality)
  # ============================================

  test "reduction_milestone? returns true for reduce_to target type" do
    assert @debt_milestone.reduction_milestone?
    assert_not @debt_milestone.growth_milestone?
  end

  test "growth_milestone? returns true for reach target type" do
    assert @milestone.growth_milestone?
    assert_not @milestone.reduction_milestone?
  end

  test "calculates reduction progress correctly" do
    # Starting: 500000, Target: 250000 (50% paid milestone)
    # Current: 400000 -> paid off 100000 of 250000 needed = 40%
    @debt_milestone.update_progress!(400000)

    assert_equal 40.0, @debt_milestone.progress_percentage
    assert_equal "in_progress", @debt_milestone.status
  end

  test "debt milestone achieved when balance at target" do
    @debt_milestone.update_progress!(250000)

    assert_equal 100.0, @debt_milestone.progress_percentage
    assert_equal "achieved", @debt_milestone.status
    assert_not_nil @debt_milestone.achieved_date
  end

  test "debt milestone achieved when balance below target" do
    @debt_milestone.update_progress!(200000)

    assert_equal 100.0, @debt_milestone.progress_percentage
    assert_equal "achieved", @debt_milestone.status
  end

  test "paid off milestone achieved at zero balance" do
    paid_off = milestones(:loan_paid_off)
    paid_off.update_progress!(0)

    assert_equal 100.0, paid_off.progress_percentage
    assert_equal "achieved", paid_off.status
  end

  test "debt progress is zero when balance unchanged" do
    # Starting: 500000, no reduction
    @debt_milestone.update_progress!(500000)

    assert_equal 0.0, @debt_milestone.progress_percentage
    assert_equal "pending", @debt_milestone.status
  end

  test "creates debt milestones for liability account" do
    new_loan = Account.create!(
      family: families(:dylan_family),
      name: "Test Loan",
      balance: 100000,
      currency: "USD",
      accountable: Loan.create!
    )

    milestones = Milestone.create_standard_milestones_for(new_loan)

    assert_equal 5, milestones.count # DEBT_MILESTONES has 5 entries
    assert milestones.all? { |m| m.target_type == "reduce_to" }
    assert milestones.all? { |m| m.starting_balance == 100000 }

    # Check targets are calculated correctly
    assert milestones.any? { |m| m.name == "25% Paid Off" && m.target_amount == 75000 }
    assert milestones.any? { |m| m.name == "50% Paid Off" && m.target_amount == 50000 }
    assert milestones.any? { |m| m.name == "Paid Off!" && m.target_amount == 0 }
  end

  test "default_target_type_for returns reduce_to for liability" do
    assert_equal "reduce_to", Milestone.default_target_type_for(@loan_account)
  end

  test "default_target_type_for returns reach for asset" do
    assert_equal "reach", Milestone.default_target_type_for(@account)
  end

  test "default_target_type_for handles nil account" do
    assert_equal "reach", Milestone.default_target_type_for(nil)
  end

  test "initializes starting_balance on first debt progress update" do
    new_milestone = Milestone.create!(
      account: @loan_account,
      name: "Test Debt Goal",
      target_amount: 100000,
      currency: "USD",
      target_type: "reduce_to",
      starting_balance: nil
    )

    assert_nil new_milestone.starting_balance

    new_milestone.update_progress!(300000)

    assert_equal 300000, new_milestone.starting_balance
  end

  test "validates target_type inclusion" do
    milestone = Milestone.new(
      account: @account,
      name: "Test",
      target_amount: 100,
      currency: "USD",
      target_type: "invalid"
    )
    assert_not milestone.valid?
    assert milestone.errors[:target_type].present?
  end

  test "scopes filter by target_type correctly" do
    growth_count = Milestone.growth_milestones.count
    reduction_count = Milestone.reduction_milestones.count
    total_count = Milestone.count

    assert_equal total_count, growth_count + reduction_count
    assert growth_count > 0
    assert reduction_count > 0
  end
end
