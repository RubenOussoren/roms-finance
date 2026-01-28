# Compact card showing account with projected growth
class UI::Projections::AccountProjectionCard < ApplicationComponent
  include Milestoneable

  attr_reader :account, :projection_years

  def initialize(account:, projection_years: 10)
    @account = account
    @projection_years = projection_years
  end

  def current_balance_formatted
    account.balance_money.format
  end

  def projected_balance_formatted
    Money.new(projected_balance, account.currency).format
  end

  def projected_balance
    @projected_balance ||= begin
      rate = cached_assumption&.effective_return || 0.06
      contribution = cached_assumption&.monthly_contribution || 0

      calculator = ProjectionCalculator.new(
        principal: account.balance,
        rate: rate,
        contribution: contribution,
        currency: account.currency
      )
      calculator.future_value_at_month(projection_years * 12)
    end
  end

  def growth_amount
    projected_balance - account.balance
  end

  def growth_percentage
    return 0 if account.balance.zero?
    ((projected_balance - account.balance) / account.balance * 100).round(1)
  end

  def expected_return
    ((cached_assumption&.effective_return || 0.06) * 100).round(1)
  end

  # Use account-specific assumption or fall back to family default
  def cached_assumption
    @cached_assumption ||= account.effective_projection_assumption
  end

  def custom_settings?
    account.custom_projection_settings?
  end

  def account_type_label
    account.accountable_type == "Crypto" ? "Crypto" : "Investment"
  end

  def account_type_color
    account.accountable_type == "Crypto" ? "text-orange-600" : "text-green-600"
  end

  # Tab name for Milestoneable concern
  def tab_name
    "investments"
  end
end
