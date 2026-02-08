# Facade encapsulating all projection and milestone logic for an Account.
#
# Extracted from the Projectable concern to reduce Account's concern count
# (11 → 9). Account delegates projection-related methods here via a lazy-
# initialized private accessor, following the same pattern as
# OpeningBalanceManager, CurrentBalanceManager, and ReconciliationManager.
#
# Responsibilities:
#   - Adaptive projections (deterministic + analytical uncertainty bands)
#   - Forecast accuracy measurement against actuals
#   - Milestone progress tracking and projected-date estimation
#   - Chart-ready data assembly (historical + projected series)
class Account::ProjectionFacade
  attr_reader :account

  def initialize(account)
    @account = account
  end

  def adaptive_projection(years:, contribution: nil, assumption: nil)
    assumption ||= default_projection_assumption
    monthly_contribution = contribution || assumption&.monthly_contribution || 0

    calculator = ProjectionCalculator.new(
      principal: account.balance,
      rate: assumption&.effective_return || 0.06,
      contribution: monthly_contribution,
      currency: account.currency
    )

    months = years * 12
    calculator.project(months: months)
  end

  # Compares historical projections against actual balances to measure
  # prediction quality. Returns nil if no projections have corresponding actuals.
  def forecast_accuracy(period: :all)
    projections_with_actuals = account.projections.with_actuals

    case period
    when :last_year
      projections_with_actuals = projections_with_actuals.where("projection_date > ?", 1.year.ago)
    when :last_6_months
      projections_with_actuals = projections_with_actuals.where("projection_date > ?", 6.months.ago)
    end

    return nil if projections_with_actuals.empty?

    ForecastAccuracyCalculator.new(projections_with_actuals).calculate
  end

  def next_milestone
    pending = account.milestones.where(status: %w[pending in_progress])

    if account.liability?
      pending.where("target_amount < ?", account.balance.abs)
             .order(target_amount: :desc).first
    else
      pending.where("target_amount > ?", account.balance)
             .order(target_amount: :asc).first
    end
  end

  def achieved_milestones
    account.milestones.achieved.ordered_by_target
  end

  def update_milestone_progress!
    account.milestones.each { |m| m.update_progress!(account.balance) }
  end

  # Regenerates forward-looking projection records and updates milestone
  # projected dates. Typically called after balance changes or assumption edits.
  def generate_projections!(months: 120)
    Account::Projection.generate_for_account(account, months: months)
    update_milestone_projections!
  end

  # Recalculates the projected achievement date for each pending/in-progress
  # milestone by querying future projection records. Loans use
  # LoanPayoffCalculator for payoff-type milestones.
  def update_milestone_projections!
    account.milestones.where(status: %w[pending in_progress]).find_each do |milestone|
      projected_date = if milestone.reduction_milestone? && account.respond_to?(:accountable) && account.accountable.is_a?(Loan)
        LoanPayoffCalculator.new(account).projected_date_for_target(milestone.target_amount)
      elsif milestone.reduction_milestone?
        account.projections
          .future
          .where("projected_balance <= ?", milestone.target_amount)
          .ordered
          .first&.projection_date
      else
        account.projections
          .future
          .where("projected_balance >= ?", milestone.target_amount)
          .ordered
          .first&.projection_date
      end

      milestone.update!(projected_date: projected_date)
    end
  end

  # Assembles a hash of historical balance data and projected percentile bands
  # (p10–p90) suitable for rendering a D3 projection chart on the frontend.
  def projection_chart_data(years: 10, assumption: nil)
    assumption ||= default_projection_assumption

    historical = historical_balance_data
    projections = projection_data(years: years, assumption: assumption)

    {
      historical: historical,
      projections: projections,
      currency: account.currency,
      today: Date.current.iso8601
    }
  end

  private

    def default_projection_assumption
      if account.respond_to?(:projection_assumption) && account.projection_assumption.present?
        return account.projection_assumption
      end

      if account.respond_to?(:family) && account.family.present?
        return ProjectionAssumption.default_for(account.family)
      end

      nil
    end

    def historical_balance_data
      start_date = 12.months.ago.to_date
      balance_records = account.balances.where("date >= ?", start_date).order(:date)

      balance_records.map do |b|
        {
          date: b.date.iso8601,
          value: b.balance.to_f
        }
      end
    end

    def projection_data(years:, assumption:)
      current_balance = account.balance.to_f
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
        principal: account.balance,
        rate: expected_return,
        contribution: monthly_contribution,
        currency: account.currency
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
