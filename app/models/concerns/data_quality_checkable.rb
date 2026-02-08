# DataQualityCheckable concern for validation warnings
# Never fails hard, guides users with warnings instead
module DataQualityCheckable
  extend ActiveSupport::Concern

  DATA_FRESHNESS_THRESHOLD = 30.days

  included do
    # Models including this can report data quality issues
  end

  # Get all data quality issues as warnings
  def data_quality_issues
    issues = []
    issues.concat(balance_quality_issues) if respond_to?(:balance_quality_issues, true)
    issues.concat(projection_quality_issues) if respond_to?(:projection_quality_issues, true)
    issues.concat(assumption_quality_issues) if respond_to?(:assumption_quality_issues, true)
    issues.concat(custom_quality_issues) if respond_to?(:custom_quality_issues, true)
    issues
  end

  # Check if data quality is acceptable
  def data_quality_acceptable?
    data_quality_issues.none? { |issue| issue[:severity] == :error }
  end

  # Get data quality score (0-100)
  def data_quality_score
    issues = data_quality_issues
    return 100 if issues.empty?

    deductions = issues.sum do |issue|
      case issue[:severity]
      when :error then 25
      when :warning then 10
      when :info then 2
      else 0
      end
    end

    [ 100 - deductions, 0 ].max
  end

  private

    # Default balance quality checks
    def balance_quality_issues
      issues = []
      account_name = respond_to?(:name) ? name : "This account"

      if respond_to?(:balance)
        if balance.nil?
          issues << { field: :balance, message: "#{account_name} doesn't have a current balance, so projections may be inaccurate. Update the balance for better results.", severity: :error, action_text: "Update balance", action_path: :edit }
        elsif balance.negative? && (!respond_to?(:liability?) || !liability?)
          issues << { field: :balance, message: "#{account_name} shows a negative balance, which is unusual for this type of account. Check if a recent transaction was entered incorrectly.", severity: :warning, action_text: "Review transactions", action_path: :show }
        elsif balance.zero? && (!respond_to?(:liability?) || !liability?)
          issues << { field: :balance, message: "#{account_name} shows a $0 balance. If this isn't right, update it for more accurate projections.", severity: :info, action_text: "Update balance", action_path: :edit }
        end
      end

      if respond_to?(:currency) && currency.blank?
        issues << { field: :currency, message: "#{account_name} is missing a currency setting, which is needed for accurate calculations.", severity: :error, action_text: "Update balance", action_path: :edit }
      end

      if respond_to?(:updated_at) && updated_at.present? && updated_at < DATA_FRESHNESS_THRESHOLD.ago
        issues << { field: :updated_at, message: "#{account_name} hasn't been updated in 30+ days. Projections work best with current data.", severity: :warning, action_text: "Refresh account", action_path: :show }
      end

      issues
    end

    # Default projection quality checks
    def projection_quality_issues
      issues = []
      account_name = respond_to?(:name) ? name : "This account"

      if respond_to?(:projection_assumption)
        if projection_assumption.blank?
          issues << { field: :projection_assumptions, message: "#{account_name} doesn't have projection settings. Add your expected return and contributions to see future projections.", severity: :info, action_text: "Set up projections", action_path: :edit }
        end
      end

      if respond_to?(:projections)
        if projections.any?
          stale_projection = projections.future.ordered.first
          if stale_projection && stale_projection.projection_date < 1.month.from_now
            issues << { field: :projections, message: "Projections for #{account_name} haven't been recalculated recently. They may not reflect recent changes.", severity: :warning, action_text: "Recalculate", action_path: :show }
          end
        end
      end

      issues
    end

    # Default assumption quality checks
    def assumption_quality_issues
      issues = []

      if respond_to?(:pag_assumption_warnings)
        pag_assumption_warnings.each do |warning|
          issues << { field: :assumptions, message: warning, severity: :warning }
        end
      end

      issues
    end
end
