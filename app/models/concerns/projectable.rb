# Projectable concern for accounts/families with projections
# Provides adaptive projection capabilities and forecast accuracy tracking
#
# DUAL PROJECTION STORAGE PATTERN:
# This system uses two complementary projection mechanisms:
#
# 1. Account::Projection database records
#    - Used for forecast accuracy tracking via ForecastAccuracyCalculator
#    - Stores "forecast checkpoints" with actual_balance for comparing predicted vs actual
#    - Generated periodically via generate_projections!
#
# 2. On-the-fly calculations (ProjectionCalculator, LoanPayoffCalculator)
#    - Used for real-time chart data reflecting current assumptions
#    - Recalculated on each page load (with caching)
#    - Immediately reflects changes to contribution/return assumptions
#
# These are complementary, not redundant - database records enable historical
# accuracy analysis while on-the-fly calculations provide responsive UI.
module Projectable
  extend ActiveSupport::Concern

  included do
    has_many :projections, class_name: "Account::Projection", dependent: :destroy
    has_many :milestones, dependent: :destroy
  end

  # Generate adaptive projections starting from actual balance
  def adaptive_projection(years:, contribution: nil, assumption: nil)
    assumption ||= default_projection_assumption
    monthly_contribution = contribution || assumption&.monthly_contribution || 0

    calculator = ProjectionCalculator.new(
      principal: balance,
      rate: assumption&.effective_return || 0.06,
      contribution: monthly_contribution,
      currency: currency
    )

    months = years * 12
    calculator.project(months: months)
  end

  # Get forecast accuracy metrics
  def forecast_accuracy(period: :all)
    projections_with_actuals = projections.with_actuals

    case period
    when :last_year
      projections_with_actuals = projections_with_actuals.where("projection_date > ?", 1.year.ago)
    when :last_6_months
      projections_with_actuals = projections_with_actuals.where("projection_date > ?", 6.months.ago)
    end

    return nil if projections_with_actuals.empty?

    ForecastAccuracyCalculator.new(projections_with_actuals).calculate
  end

  # Get next milestone (debt-aware)
  def next_milestone
    pending = milestones.where(status: %w[pending in_progress])

    if liability?
      # For debts: find highest target below current balance (next reduction goal)
      pending.where("target_amount < ?", balance.abs)
             .order(target_amount: :desc).first
    else
      # For assets: find lowest target above current balance (next growth goal)
      pending.where("target_amount > ?", balance)
             .order(target_amount: :asc).first
    end
  end

  # Get achieved milestones
  def achieved_milestones
    milestones.achieved.ordered_by_target
  end

  # Update all milestone progress based on current balance
  def update_milestone_progress!
    milestones.each { |m| m.update_progress!(balance) }
  end

  # Generate projections for this account
  def generate_projections!(months: 120)
    Account::Projection.generate_for_account(self, months: months)
    update_milestone_projections!
  end

  # Update milestone projected dates based on projections (debt-aware)
  def update_milestone_projections!
    milestones.where(status: %w[pending in_progress]).find_each do |milestone|
      projected_date = if milestone.reduction_milestone? && respond_to?(:accountable) && accountable.is_a?(Loan)
        # Use amortization schedule for loans (more accurate than projections)
        LoanPayoffCalculator.new(self).projected_date_for_target(milestone.target_amount)
      elsif milestone.reduction_milestone?
        # Fall back to projection records for other liabilities
        projections
          .future
          .where("projected_balance <= ?", milestone.target_amount)
          .ordered
          .first&.projection_date
      else
        # For growth milestones: find when projected_balance >= target
        projections
          .future
          .where("projected_balance >= ?", milestone.target_amount)
          .ordered
          .first&.projection_date
      end

      milestone.update!(projected_date: projected_date)
    end
  end

  # Prepare chart data combining historical balances with Monte Carlo projections
  def projection_chart_data(years: 10, assumption: nil)
    assumption ||= default_projection_assumption

    historical = historical_balance_data
    projections = projection_data(years: years, assumption: assumption)

    {
      historical: historical,
      projections: projections,
      currency: currency,
      today: Date.current.iso8601
    }
  end

  private

    def default_projection_assumption
      # For accounts, prefer account-specific assumption, then fall back to family default
      if respond_to?(:projection_assumption) && projection_assumption.present?
        return projection_assumption
      end

      if respond_to?(:family) && family.present?
        return ProjectionAssumption.default_for(family)
      end

      nil
    end

    def historical_balance_data
      # Get last 12 months of balance data
      start_date = 12.months.ago.to_date
      balance_records = balances.where("date >= ?", start_date).order(:date)

      balance_records.map do |b|
        {
          date: b.date.iso8601,
          value: b.balance.to_f
        }
      end
    end

    def projection_data(years:, assumption:)
      current_balance = balance.to_f
      anchor = {
        date: Date.current.iso8601,
        p10: current_balance,
        p25: current_balance,
        p50: current_balance,
        p75: current_balance,
        p90: current_balance
      }

      monthly_contribution = assumption&.monthly_contribution || 0
      expected_return = assumption&.effective_return || 0.06
      volatility = assumption&.effective_volatility || 0.15

      calculator = ProjectionCalculator.new(
        principal: balance,
        rate: expected_return,
        contribution: monthly_contribution,
        currency: currency
      )

      months = years * 12
      results = calculator.project_with_analytical_bands(
        months: months,
        volatility: volatility
      )

      projection_data = results.map do |r|
        {
          date: r[:date].iso8601,
          p10: r[:p10].to_f,
          p25: r[:p25].to_f,
          p50: r[:p50].to_f,
          p75: r[:p75].to_f,
          p90: r[:p90].to_f
        }
      end

      [ anchor ] + projection_data
    end
end
