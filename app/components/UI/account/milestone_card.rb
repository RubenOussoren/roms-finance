# Individual milestone display with progress bar, status badge, and projected date
class UI::Account::MilestoneCard < ApplicationComponent
  attr_reader :milestone

  def initialize(milestone:, highlight: false)
    @milestone = milestone
    @highlight = highlight
  end

  def highlight?
    @highlight
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
      "Achieved"
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
    helpers.format_money(Money.new(milestone.target_amount, milestone.currency))
  end

  def formatted_progress
    milestone.progress_percentage.round(0)
  end

  def days_remaining_text
    days = milestone.days_to_target
    return nil if days.nil?
    return "Achieved!" if milestone.achieved?
    return "Today!" if days == 0
    return "#{days} days" if days > 0
    "#{days.abs} days ago" # Past projected date
  end

  def projected_date_text
    return nil unless milestone.projected_date.present?
    return "Achieved #{helpers.format_date(milestone.achieved_date)}" if milestone.achieved? && milestone.achieved_date.present?

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
    helpers.edit_milestone_path(milestone)
  end

  def delete_path
    helpers.milestone_path(milestone)
  end
end
