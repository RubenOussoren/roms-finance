# Per-account debt payoff chart component
class UI::Projections::DebtPayoffChart < ApplicationComponent
  attr_reader :account, :extra_payment

  def initialize(account:, extra_payment: 0)
    @account = account
    @extra_payment = extra_payment.to_d
  end

  # Hero metric - remaining balance
  def current_balance_formatted
    format_money(Money.new(account.balance, account.currency))
  end

  # Supporting details for chart header
  def monthly_payment_formatted
    payment = account.accountable&.monthly_payment
    return "--" unless payment&.positive?
    "#{format_money(Money.new(payment, account.currency))}/mo"
  end

  def interest_rate_formatted
    rate = account.accountable&.interest_rate
    return "--" unless rate
    "#{rate.round(1)}%"
  end

  def time_remaining_formatted
    return "--" unless summary[:months_to_payoff]
    months_total = summary[:months_to_payoff]
    years = months_total / 12
    months = months_total % 12

    if years > 0 && months > 0
      "#{years}y #{months}m"
    elsif years > 0
      "#{years}y"
    else
      "#{months}m"
    end
  end

  def calculator
    @calculator ||= LoanPayoffCalculator.new(account, extra_payment: extra_payment)
  end

  def chart_data
    {
      historical: historical_data,
      projections: projection_data,
      currency: account.currency,
      today: Date.current.iso8601
    }.to_json
  end

  def historical_data
    start_date = 12.months.ago.to_date
    account.balances.where("date >= ?", start_date).order(:date).map do |b|
      { date: b.date.iso8601, value: b.balance.abs.to_f }
    end
  end

  def projection_data
    calculator.chart_data.map do |point|
      { date: point[:date], value: point[:balance].to_f }
    end
  end

  def summary
    @summary ||= calculator.summary
  end

  def has_data?
    summary[:months_to_payoff].present?
  end

  def payoff_date_formatted
    summary[:payoff_date]&.strftime("%b %Y") || "--"
  end

  def total_interest_formatted
    return "--" unless summary[:total_interest_remaining]
    format_money(Money.new(summary[:total_interest_remaining], account.currency))
  end

  def interest_saved_formatted
    return nil unless extra_payment.positive?
    saved = calculator.interest_saved_with_extra_payment
    return nil if saved.zero?
    format_money(Money.new(saved, account.currency))
  end

  def months_saved
    return nil unless extra_payment.positive?
    saved = calculator.months_saved_with_extra_payment
    return nil if saved.zero?
    saved
  end

  def months_saved_formatted
    saved = months_saved
    return nil unless saved

    years = saved / 12
    months = saved % 12

    if years > 0 && months > 0
      "#{years}y #{months}m"
    elsif years > 0
      "#{years}y"
    else
      "#{months}m"
    end
  end

  def has_impact?
    interest_saved_formatted.present? || months_saved.present?
  end

  def chart_frame_id
    helpers.dom_id(account, :debt_payoff_chart)
  end

  private

    def format_money(money)
      helpers.format_money(money)
    end
end
