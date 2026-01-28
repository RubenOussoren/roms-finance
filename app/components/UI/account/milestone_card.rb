# Individual milestone display with progress bar, status badge, and projected date
# Supports both growth milestones (reach target) and debt milestones (reduce to target)
class UI::Account::MilestoneCard < ApplicationComponent
  attr_reader :milestone, :return_to

  def initialize(milestone:, highlight: false, return_to: nil)
    @milestone = milestone
    @highlight = highlight
    @return_to = return_to
  end

  def highlight?
    @highlight
  end

  def debt_milestone?
    milestone.reduction_milestone?
  end

  def status_badge_classes
    case milestone.status
    when "achieved"
      "bg-green-100 text-green-700"
    when "in_progress"
      "bg-blue-100 text-blue-700"
    else
      "bg-gray-100 text-secondary"
    end
  end

  def status_label
    case milestone.status
    when "achieved"
      debt_milestone? ? "Paid Off" : "Achieved"
    when "in_progress"
      "In Progress"
    else
      "Pending"
    end
  end

  def progress_bar_classes
    case milestone.status
    when "achieved"
      "bg-green-500"
    when "in_progress"
      "bg-blue-500"
    else
      "bg-gray-300"
    end
  end

  def formatted_target
    if debt_milestone? && milestone.target_amount.zero?
      "Paid Off"
    else
      helpers.format_money(Money.new(milestone.target_amount, milestone.currency))
    end
  end

  # For debt milestones, show the amount being paid off (matches investment style)
  # For growth milestones, show the dollar target
  def target_display
    if debt_milestone?
      if milestone.target_amount.zero?
        "Paid Off!"
      else
        # Show the amount being paid off: starting_balance - target_amount
        amount_to_pay = milestone.starting_balance.to_d - milestone.target_amount.to_d
        helpers.format_money(Money.new(amount_to_pay, milestone.currency))
      end
    else
      formatted_target
    end
  end

  def formatted_progress
    milestone.progress_percentage.round(0)
  end

  def progress_label
    "Progress"
  end

  def target_label
    debt_milestone? ? "Target Balance" : "Target"
  end

  def milestone_icon
    if milestone.achieved?
      "trophy"
    elsif debt_milestone?
      "trending-down"
    else
      "target"
    end
  end

  def days_remaining_text
    days = milestone.days_to_target
    return nil if days.nil?
    return debt_milestone? ? "Paid Off!" : "Achieved!" if milestone.achieved?
    return "Today!" if days == 0
    return "#{days} days" if days > 0
    "#{days.abs} days ago" # Past projected date
  end

  def projected_date_text
    return nil unless milestone.projected_date.present?
    if milestone.achieved? && milestone.achieved_date.present?
      return debt_milestone? ? "Paid off #{helpers.format_date(milestone.achieved_date)}" : "Achieved #{helpers.format_date(milestone.achieved_date)}"
    end

    helpers.format_date(milestone.projected_date)
  end

  def on_track_indicator
    on_track = milestone.on_track?
    return nil if on_track.nil?

    if on_track
      { icon: "check-circle", color: "success", text: "On track" }
    else
      { icon: "alert-circle", color: "warning", text: "Behind schedule" }
    end
  end

  def custom?
    milestone.is_custom
  end

  def edit_path
    helpers.edit_milestone_path(milestone, return_to: return_to)
  end

  def delete_path
    helpers.milestone_path(milestone, return_to: return_to)
  end
end
