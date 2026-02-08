# Container component showing account milestones with progress tracking
class UI::Account::MilestoneTracker < ApplicationComponent
  include Milestoneable

  attr_reader :account

  def initialize(account:)
    @account = account
  end

  def id
    helpers.dom_id(account, :milestones)
  end

  def total_count
    milestones.count
  end

  def new_milestone_path
    helpers.new_account_milestone_path(account)
  end

  private

    def tab_name
      "account"
    end
end
