# Container component showing account milestones with progress tracking
class UI::Account::MilestoneTracker < ApplicationComponent
  attr_reader :account

  def initialize(account:)
    @account = account
  end

  def id
    helpers.dom_id(account, :milestones)
  end

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

  def total_count
    milestones.count
  end

  def new_milestone_path
    helpers.new_account_milestone_path(account)
  end
end
