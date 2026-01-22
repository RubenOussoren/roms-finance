require "test_helper"

class UI::Account::MilestoneCardTest < ActiveSupport::TestCase
  setup do
    @milestone = milestones(:first_100k)
    @custom_milestone = milestones(:custom_goal)
  end

  test "initializes with milestone" do
    component = UI::Account::MilestoneCard.new(milestone: @milestone)
    assert_equal @milestone, component.milestone
  end

  test "highlight? returns false by default" do
    component = UI::Account::MilestoneCard.new(milestone: @milestone)
    assert_not component.highlight?
  end

  test "highlight? returns true when set" do
    component = UI::Account::MilestoneCard.new(milestone: @milestone, highlight: true)
    assert component.highlight?
  end

  test "status_badge_classes returns correct classes for achieved" do
    @milestone.update!(status: "achieved")
    component = UI::Account::MilestoneCard.new(milestone: @milestone)
    assert_equal "bg-green-100 text-green-700", component.status_badge_classes
  end

  test "status_badge_classes returns correct classes for in_progress" do
    @milestone.update!(status: "in_progress")
    component = UI::Account::MilestoneCard.new(milestone: @milestone)
    assert_equal "bg-blue-100 text-blue-700", component.status_badge_classes
  end

  test "status_badge_classes returns correct classes for pending" do
    @milestone.update!(status: "pending")
    component = UI::Account::MilestoneCard.new(milestone: @milestone)
    assert_equal "bg-gray-100 text-secondary", component.status_badge_classes
  end

  test "status_label returns Achieved for achieved status" do
    @milestone.update!(status: "achieved")
    component = UI::Account::MilestoneCard.new(milestone: @milestone)
    assert_equal "Achieved", component.status_label
  end

  test "status_label returns In Progress for in_progress status" do
    @milestone.update!(status: "in_progress")
    component = UI::Account::MilestoneCard.new(milestone: @milestone)
    assert_equal "In Progress", component.status_label
  end

  test "status_label returns Pending for pending status" do
    @milestone.update!(status: "pending")
    component = UI::Account::MilestoneCard.new(milestone: @milestone)
    assert_equal "Pending", component.status_label
  end

  test "progress_bar_classes returns green for achieved" do
    @milestone.update!(status: "achieved")
    component = UI::Account::MilestoneCard.new(milestone: @milestone)
    assert_equal "bg-green-500", component.progress_bar_classes
  end

  test "progress_bar_classes returns blue for in_progress" do
    @milestone.update!(status: "in_progress")
    component = UI::Account::MilestoneCard.new(milestone: @milestone)
    assert_equal "bg-blue-500", component.progress_bar_classes
  end

  test "progress_bar_classes returns gray for pending" do
    @milestone.update!(status: "pending")
    component = UI::Account::MilestoneCard.new(milestone: @milestone)
    assert_equal "bg-gray-300", component.progress_bar_classes
  end

  test "formatted_progress returns rounded percentage" do
    @milestone.update!(progress_percentage: 33.33)
    component = UI::Account::MilestoneCard.new(milestone: @milestone)
    assert_equal 33, component.formatted_progress
  end

  test "days_remaining_text returns nil when no projected_date" do
    @milestone.update!(projected_date: nil)
    component = UI::Account::MilestoneCard.new(milestone: @milestone)
    assert_nil component.days_remaining_text
  end

  test "days_remaining_text returns Achieved! when achieved" do
    @milestone.update!(status: "achieved", projected_date: Date.current + 30.days)
    component = UI::Account::MilestoneCard.new(milestone: @milestone)
    assert_equal "Achieved!", component.days_remaining_text
  end

  test "days_remaining_text returns Today! when target is today" do
    @milestone.update!(projected_date: Date.current)
    component = UI::Account::MilestoneCard.new(milestone: @milestone)
    assert_equal "Today!", component.days_remaining_text
  end

  test "days_remaining_text returns days count for future dates" do
    @milestone.update!(projected_date: Date.current + 30.days)
    component = UI::Account::MilestoneCard.new(milestone: @milestone)
    assert_equal "30 days", component.days_remaining_text
  end

  test "on_track_indicator returns nil when on_track is nil" do
    @milestone.update!(target_date: nil, projected_date: nil)
    component = UI::Account::MilestoneCard.new(milestone: @milestone)
    assert_nil component.on_track_indicator
  end

  test "on_track_indicator returns success indicator when on track" do
    @milestone.update!(
      target_date: Date.current + 365.days,
      projected_date: Date.current + 300.days
    )
    component = UI::Account::MilestoneCard.new(milestone: @milestone)

    indicator = component.on_track_indicator
    assert_equal "check-circle", indicator[:icon]
    assert_equal "success", indicator[:color]
    assert_equal "On track", indicator[:text]
  end

  test "on_track_indicator returns warning indicator when behind" do
    @milestone.update!(
      target_date: Date.current + 300.days,
      projected_date: Date.current + 365.days
    )
    component = UI::Account::MilestoneCard.new(milestone: @milestone)

    indicator = component.on_track_indicator
    assert_equal "alert-circle", indicator[:icon]
    assert_equal "warning", indicator[:color]
    assert_equal "Behind schedule", indicator[:text]
  end

  test "custom? returns true for custom milestones" do
    component = UI::Account::MilestoneCard.new(milestone: @custom_milestone)
    assert component.custom?
  end

  test "custom? returns false for standard milestones" do
    component = UI::Account::MilestoneCard.new(milestone: @milestone)
    assert_not component.custom?
  end
end
