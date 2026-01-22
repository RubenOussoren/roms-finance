class UI::Account::ProjectionSettings < ApplicationComponent
  attr_reader :account, :assumption

  def initialize(account:, assumption: nil)
    @account = account
    @assumption = assumption || default_assumption
  end

  def default_assumption
    return nil unless account.family.present?
    ProjectionAssumption.default_for(account.family)
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

  def compliance_badge
    assumption&.compliance_badge || "Custom assumptions"
  end

  def currency_symbol
    account.balance_money.currency.symbol
  end

  def show_settings?
    account.accountable_type.in?(%w[Investment Crypto])
  end
end
