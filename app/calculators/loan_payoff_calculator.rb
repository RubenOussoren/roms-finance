# Loan payoff calculator for debt projections
# Calculates: months_to_payoff, payoff_date, total_interest, amortization_schedule
class LoanPayoffCalculator
  attr_reader :account, :loan, :extra_payment

  def initialize(account, extra_payment: 0)
    @account = account
    @loan = account.accountable
    @extra_payment = extra_payment.to_d
  end

  # Get summary of loan payoff
  # Results are cached based on account balance, interest rate, and extra payment
  def summary
    return empty_summary unless valid_loan?

    Rails.cache.fetch(cache_key("summary"), expires_in: 1.hour) do
      schedule = amortization_schedule

      {
        account: account,
        current_balance: account.balance.abs,
        monthly_payment: monthly_payment,
        interest_rate: interest_rate,
        months_to_payoff: schedule.length,
        payoff_date: payoff_date(schedule.length),
        total_interest_remaining: total_interest_remaining(schedule),
        total_amount_remaining: total_amount_remaining(schedule),
        years_remaining: (schedule.length / 12.0).round(1),
        currency: account.currency
      }
    end
  end

  # Cache key for memoization across requests
  def cache_key(suffix = nil)
    key_parts = [
      "loan_payoff",
      account.id,
      account.balance.to_i,
      loan&.interest_rate.to_s,
      @extra_payment.to_i
    ]
    key_parts << suffix if suffix
    key_parts.join("_")
  end

  # Generate full amortization schedule (memoized to avoid O(n²) recalculations)
  def amortization_schedule
    @amortization_schedule ||= calculate_amortization_schedule
  end

  # Find the date when balance reaches a specific target
  # Used for milestone projected date calculations
  def projected_date_for_target(target_balance)
    schedule = amortization_schedule
    entry = schedule.find { |e| e[:balance] <= target_balance }
    return nil unless entry
    Date.parse(entry[:date])
  end

  # Generate chart data for debt payoff visualization
  def chart_data
    schedule = amortization_schedule
    return [] if schedule.empty?

    # Sample every nth point for charts (keep manageable size)
    sample_rate = [ schedule.length / 60, 1 ].max

    schedule.each_with_index.select { |_, i| i % sample_rate == 0 || i == schedule.length - 1 }.map do |entry, _|
      {
        date: entry[:date],
        balance: entry[:balance],
        principal_paid: account.balance.abs - entry[:balance],
        interest_paid: cumulative_interest_at(entry[:month])
      }
    end
  end

  # Total monthly payment including extra payment
  def total_monthly_payment
    monthly_payment + @extra_payment
  end

  # Calculate interest saved by making extra payments
  def interest_saved_with_extra_payment
    return 0 unless @extra_payment.positive?

    baseline = LoanPayoffCalculator.new(account).amortization_schedule.sum { |e| e[:interest] }
    accelerated = amortization_schedule.sum { |e| e[:interest] }
    (baseline - accelerated).round(2)
  end

  # Calculate months saved by making extra payments
  def months_saved_with_extra_payment
    return 0 unless @extra_payment.positive?

    baseline = LoanPayoffCalculator.new(account).amortization_schedule.length
    accelerated = amortization_schedule.length
    baseline - accelerated
  end

  private

    def calculate_amortization_schedule
      return [] unless valid_loan?

      schedule = []
      balance = account.balance.abs
      month = 0
      max_months = 360 # 30 years max
      effective_payment = total_monthly_payment

      while balance > 0.01 && month < max_months
        month += 1
        interest_payment = balance * monthly_rate
        principal_payment = [ effective_payment - interest_payment, balance ].min

        # Handle case where payment doesn't cover interest
        if principal_payment <= 0
          break # Loan will never be paid off at current rate
        end

        balance -= principal_payment

        schedule << {
          month: month,
          date: (Date.current + month.months).iso8601,
          payment: effective_payment.round(2),
          principal: principal_payment.round(2),
          interest: interest_payment.round(2),
          balance: [ balance, 0 ].max.round(2)
        }
      end

      schedule
    end

    def valid_loan?
      loan.present? && account.balance.abs > 0 && monthly_payment > 0
    end

    def empty_summary
      {
        account: account,
        current_balance: account.balance.abs,
        monthly_payment: 0,
        interest_rate: 0,
        months_to_payoff: nil,
        payoff_date: nil,
        total_interest_remaining: 0,
        total_amount_remaining: account.balance.abs,
        years_remaining: nil,
        currency: account.currency
      }
    end

    def interest_rate
      loan&.interest_rate || 5.0
    end

    def monthly_rate
      interest_rate / 100.0 / 12
    end

    def monthly_payment
      loan.monthly_payment&.amount || estimated_payment
    end

    def estimated_payment
      # Estimate payment if not provided (assume 25-year amortization)
      return 0 if account.balance.abs <= 0

      balance = account.balance.abs
      n = 300 # 25 years

      if monthly_rate > 0
        (balance * monthly_rate * (1 + monthly_rate)**n) / ((1 + monthly_rate)**n - 1)
      else
        balance / n
      end
    end

    def payoff_date(months)
      Date.current + months.months
    end

    def total_interest_remaining(schedule)
      schedule.sum { |entry| entry[:interest] }.round(2)
    end

    def total_amount_remaining(schedule)
      schedule.sum { |entry| entry[:payment] }.round(2)
    end

    def cumulative_interest_at(month)
      amortization_schedule.take(month).sum { |entry| entry[:interest] }.round(2)
    end
end
