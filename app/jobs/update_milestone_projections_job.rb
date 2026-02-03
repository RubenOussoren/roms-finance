# Background job to update milestone projected dates for an account
# Triggered by balance changes to keep milestone projections accurate
# without blocking the request cycle
class UpdateMilestoneProjectionsJob < ApplicationJob
  queue_as :low_priority

  def perform(account_id)
    account = Account.find_by(id: account_id)
    return unless account&.respond_to?(:update_milestone_projections!)

    account.update_milestone_projections!
  end
end
