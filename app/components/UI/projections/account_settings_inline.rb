# Compact inline settings panel for account projection cards
class UI::Projections::AccountSettingsInline < ApplicationComponent
  attr_reader :account, :projection_years

  def initialize(account:, projection_years: 10)
    @account = account
    @projection_years = projection_years
  end

  def assumption
    @assumption ||= account.effective_projection_assumption
  end

  def expected_return_percent
    (assumption&.effective_return.to_f * 100).round(1)
  end

  def monthly_contribution
    assumption&.monthly_contribution.to_f.round(0)
  end

  def volatility_percent
    (assumption&.effective_volatility.to_f * 100).round(1)
  end

  def inflation_percent
    (assumption&.effective_inflation.to_f * 100).round(1)
  end

  def use_pag_defaults?
    assumption&.use_pag_defaults || false
  end

  def custom_settings?
    account.custom_projection_settings?
  end

  def compliance_badge
    assumption&.compliance_badge || "Using custom assumptions"
  end

  def currency_symbol
    account.balance_money.currency.symbol
  end

  def settings_frame_id
    helpers.dom_id(account, :projection_settings)
  end

  def chart_frame_id
    helpers.dom_id(account, :projection_chart)
  end

  def form_url
    helpers.account_projection_settings_path(account)
  end

  def reset_url
    helpers.reset_account_projection_settings_path(account)
  end
end
