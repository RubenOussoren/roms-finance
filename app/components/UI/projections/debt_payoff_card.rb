# Individual loan payoff information card
class UI::Projections::DebtPayoffCard < ApplicationComponent
  include Milestoneable

  attr_reader :payoff

  def initialize(payoff:)
    @payoff = payoff
  end

  def account
    payoff[:account]
  end

  def current_balance_formatted
    format_money(Money.new(payoff[:current_balance], payoff[:currency]))
  end

  def monthly_payment_formatted
    return "--" unless payoff[:monthly_payment]&.positive?
    format_money(Money.new(payoff[:monthly_payment], payoff[:currency]))
  end

  def interest_rate_formatted
    return "--" unless payoff[:interest_rate]
    "#{payoff[:interest_rate].round(1)}%"
  end

  def payoff_date_formatted
    payoff[:payoff_date]&.strftime("%b %Y") || "--"
  end

  def time_remaining_formatted
    years = payoff[:years_remaining]
    return "--" unless years

    years_int = years.to_i
    months = ((years - years_int) * 12).round

    if years_int > 0 && months > 0
      "#{years_int}y #{months}m"
    elsif years_int > 0
      "#{years_int}y"
    else
      "#{months}m"
    end
  end

  def total_interest_formatted
    return "--" unless payoff[:total_interest_remaining]
    format_money(Money.new(payoff[:total_interest_remaining], payoff[:currency]))
  end

  def loan_subtype
    account.subtype || "loan"
  end

  def loan_type_label
    case loan_subtype
    when "mortgage"
      "Mortgage"
    when "student"
      "Student Loan"
    when "auto"
      "Auto Loan"
    else
      "Loan"
    end
  end

  def loan_type_color
    case loan_subtype
    when "mortgage" then "text-blue-600"
    when "student"  then "text-purple-600"
    when "auto"     then "text-cyan-600"
    else                 "text-secondary"
    end
  end

  def progress_percentage
    return 0 unless account.accountable.respond_to?(:original_balance)

    original = account.accountable.original_balance&.amount || payoff[:current_balance]
    return 0 if original.zero?

    paid = original - payoff[:current_balance]
    [ (paid / original * 100).round, 100 ].min
  end

  # Tab name for Milestoneable concern
  def tab_name
    "debt"
  end

  # Debt settings helpers
  def effective_extra_payment
    account.projection_assumption&.effective_extra_payment.to_d
  end

  def chart_frame_id
    helpers.dom_id(account, :debt_payoff_chart)
  end

  def settings_frame_id
    helpers.dom_id(account, :debt_settings)
  end

  private

    def format_money(money)
      helpers.format_money(money)
    end
end
