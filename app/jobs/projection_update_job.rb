# Job to record actual balances against projections for forecast accuracy tracking
# Run monthly (e.g., via cron) to capture actual vs projected performance
#
# Usage:
#   ProjectionUpdateJob.perform_later  # All families
#   ProjectionUpdateJob.perform_later(family_id: "uuid")  # Single family
class ProjectionUpdateJob < ApplicationJob
  queue_as :low_priority

  def perform(family_id: nil)
    families = family_id ? Family.where(id: family_id) : Family.all

    families.find_each do |family|
      record_actuals_for_family(family)
    end
  end

  private

    def record_actuals_for_family(family)
      current_month = Date.current.beginning_of_month

      family.accounts.active.find_each do |account|
        # Find projection for current month (if exists)
        projection = account.projections
                           .where(projection_date: current_month..current_month.end_of_month)
                           .first

        # Record actual balance if we have a projection for this month
        if projection && projection.actual_balance.nil?
          projection.record_actual!(account.balance)
          Rails.logger.info "Recorded actual balance #{account.balance} for projection #{projection.id}"
        end
      end
    end
end
