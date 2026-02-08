# Compact inline settings panel for debt repayment settings
class UI::Projections::DebtSettingsInline < ApplicationComponent
  attr_reader :account

  def initialize(account:)
    @account = account
  end

  def assumption
    @assumption ||= account.projection_assumption
  end

  def extra_monthly_payment
    assumption&.extra_monthly_payment.to_f.round(0)
  end

  def target_payoff_date
    assumption&.target_payoff_date
  end

  def target_payoff_date_formatted
    target_payoff_date&.strftime("%Y-%m-%d")
  end

  def custom_settings?
    assumption&.debt_settings? || loan_lump_sum?
  end

  def loan
    @loan ||= account.accountable if account.accountable_type == "Loan"
  end

  def is_mortgage?
    account.subtype == "mortgage"
  end

  def annual_lump_sum_amount
    loan&.annual_lump_sum_amount.to_f.round(0)
  end

  def annual_lump_sum_month
    loan&.annual_lump_sum_month
  end

  def month_options
    (1..12).map { |m| [Date::MONTHNAMES[m], m] }
  end

  def loan_lump_sum?
    loan&.annual_lump_sum_amount.to_f.positive?
  end

  def currency_symbol
    account.balance_money.currency.symbol
  end

  def settings_frame_id
    helpers.dom_id(account, :debt_settings)
  end

  def chart_frame_id
    helpers.dom_id(account, :debt_payoff_chart)
  end

  def form_url
    helpers.account_debt_repayment_settings_path(account)
  end

  def reset_url
    helpers.reset_account_debt_repayment_settings_path(account)
  end

  # Calculate potential savings for right-side display (memoized to avoid double computation)
  def potential_savings_formatted
    return @potential_savings_formatted if defined?(@potential_savings_formatted)

    @potential_savings_formatted = if extra_monthly_payment.positive?
      calculator = LoanPayoffCalculator.new(account, extra_payment: extra_monthly_payment)
      saved = calculator.interest_saved_with_extra_payment
      saved.zero? ? nil : helpers.format_money(Money.new(saved, account.currency))
    end
  end

  def has_savings?
    potential_savings_formatted.present?
  end
end
