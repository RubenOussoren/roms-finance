# Projectable concern for accounts/families with projections
# Provides adaptive projection capabilities and forecast accuracy tracking
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

  # Get next milestone
  def next_milestone
    milestones.where(status: %w[pending in_progress])
              .ordered_by_target
              .where("target_amount > ?", balance)
              .first
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

  # Update milestone projected dates based on projections
  def update_milestone_projections!
    milestones.where(status: %w[pending in_progress]).find_each do |milestone|
      projected = projections
        .future
        .where("projected_balance >= ?", milestone.target_amount)
        .ordered
        .first

      milestone.update!(projected_date: projected&.projection_date)
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
      return family.projection_assumptions.active.first if respond_to?(:family) && family.present?
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
      # First try to use pre-stored projections (much faster)
      stored = projections.future.ordered.limit(years * 12)
      if stored.any? && stored.first.percentiles.present?
        return stored.map do |p|
          {
            date: p.projection_date.iso8601,
            p10: p.percentile(10)&.to_f || p.projected_balance.to_f * 0.85,
            p25: p.percentile(25)&.to_f || p.projected_balance.to_f * 0.92,
            p50: p.percentile(50)&.to_f || p.projected_balance.to_f,
            p75: p.percentile(75)&.to_f || p.projected_balance.to_f * 1.08,
            p90: p.percentile(90)&.to_f || p.projected_balance.to_f * 1.15
          }
        end
      end

      # Fall back to computing Monte Carlo (reduced simulations for speed)
      monthly_contribution = assumption&.monthly_contribution || 0
      expected_return = assumption&.effective_return || 0.06
      volatility = assumption&.volatility || 0.15

      calculator = ProjectionCalculator.new(
        principal: balance,
        rate: expected_return,
        contribution: monthly_contribution,
        currency: currency
      )

      months = years * 12
      results = calculator.project_with_percentiles(
        months: months,
        volatility: volatility,
        simulations: 100  # Reduced from 500 for faster page loads
      )

      results.map do |r|
        {
          date: r[:date].iso8601,
          p10: r[:p10].to_f,
          p25: r[:p25].to_f,
          p50: r[:p50].to_f,
          p75: r[:p75].to_f,
          p90: r[:p90].to_f
        }
      end
    end
end
