class UI::Account::ProjectionChart < ApplicationComponent
  attr_reader :account, :years, :assumption

  def initialize(account:, years: 10, assumption: nil)
    @account = account
    @years = years
    @assumption = assumption
  end

  def chart_data
    account.projection_chart_data(years: years, assumption: assumption)
  end

  def current_balance_formatted
    account.balance_money.format
  end

  def projected_balance_formatted
    projections = chart_data[:projections]
    return nil if projections.empty?

    Money.new(projections.last[:p50], account.currency).format
  end

  def assumption_summary
    return "Default assumptions" unless assumption.present?

    parts = []
    parts << "#{(assumption.effective_return * 100).round(1)}% return" if assumption.effective_return
    parts << "#{account.balance_money.currency.symbol}#{assumption.monthly_contribution.to_i}/mo" if assumption.monthly_contribution&.positive?
    parts.join(", ")
  end

  def show_chart?
    account.accountable_type.in?(%w[Investment Crypto])
  end
end
