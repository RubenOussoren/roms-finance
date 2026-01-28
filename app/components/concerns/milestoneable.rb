# Shared milestone methods for projection card components
module Milestoneable
  extend ActiveSupport::Concern

  def milestones
    @milestones ||= account.milestones.ordered_by_target
  end

  def next_milestone
    @next_milestone ||= account.next_milestone
  end

  def achieved_milestones
    @achieved_milestones ||= milestones.achieved
  end

  def pending_milestones
    @pending_milestones ||= milestones.where(status: %w[pending in_progress])
  end

  def has_milestones?
    milestones.any?
  end

  def achieved_count
    achieved_milestones.count
  end

  def pending_count
    pending_milestones.count
  end

  def new_milestone_path
    helpers.new_account_milestone_path(account, return_to: milestone_return_to)
  end

  def milestones_frame_id
    helpers.dom_id(account, :"#{tab_name}_milestones")
  end

  def milestone_return_to
    helpers.projections_path(tab: tab_name)
  end

  # Subclasses must implement this method
  def tab_name
    raise NotImplementedError, "Subclasses must implement #tab_name"
  end
end
