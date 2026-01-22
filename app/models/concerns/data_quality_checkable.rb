# DataQualityCheckable concern for validation warnings
# Never fails hard, guides users with warnings instead
module DataQualityCheckable
  extend ActiveSupport::Concern

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

      if respond_to?(:balance)
        if balance.nil?
          issues << { field: :balance, message: "Balance is missing", severity: :error }
        elsif balance.negative?
          issues << { field: :balance, message: "Negative balance may indicate data issue", severity: :warning }
        elsif balance.zero?
          issues << { field: :balance, message: "Zero balance - projections will not grow", severity: :info }
        end
      end

      if respond_to?(:currency) && currency.blank?
        issues << { field: :currency, message: "Currency is missing", severity: :error }
      end

      issues
    end

    # Default projection quality checks
    def projection_quality_issues
      issues = []

      if respond_to?(:projections)
        if projections.empty?
          issues << { field: :projections, message: "No projections generated", severity: :info }
        else
          stale_projection = projections.future.ordered.first
          if stale_projection && stale_projection.projection_date < 1.month.from_now
            issues << { field: :projections, message: "Projections may need regeneration", severity: :warning }
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
