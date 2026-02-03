class UI::Account::ProjectionChart < ApplicationComponent
  attr_reader :account, :years, :assumption, :show_years_selector

  def initialize(account:, years: 10, assumption: nil, show_years_selector: true)
    @account = account
    @years = years
    @assumption = assumption
    @show_years_selector = show_years_selector
  end

  def chart_data
    @chart_data ||= account.projection_chart_data(years: years, assumption: assumption)
  end

  def current_balance_formatted
    account.balance_money.format
  end

  # Use Monte Carlo median (p50) as the expected balance
  # This ensures the headline number matches the dashed line on the chart
  def expected_balance
    projections = chart_data[:projections]
    return account.balance if projections.empty?

    projections.last[:p50]
  end

  def expected_balance_formatted
    Money.new(expected_balance, account.currency).format
  end

  def expected_growth
    expected_balance - account.balance
  end

  def expected_growth_formatted
    Money.new(expected_growth, account.currency).format
  end

  # Monte Carlo percentiles for range display
  def conservative_estimate # p25
    projections = chart_data[:projections]
    return nil if projections.empty?

    Money.new(projections.last[:p25], account.currency).format
  end

  def optimistic_estimate # p75
    projections = chart_data[:projections]
    return nil if projections.empty?

    Money.new(projections.last[:p75], account.currency).format
  end

  def assumption_summary
    eff = effective_assumption
    return "Default assumptions" unless eff.present?

    parts = []
    parts << "#{(eff.effective_return * 100).round(1)}% return" if eff.effective_return
    parts << "#{account.balance_money.currency.symbol}#{eff.monthly_contribution.to_i}/mo" if eff.monthly_contribution&.positive?
    parts.join(", ")
  end

  def show_chart?
    account.accountable_type.in?(%w[Investment Crypto])
  end

  private

    def effective_assumption
      @effective_assumption ||= assumption || account.effective_projection_assumption
    end
end
