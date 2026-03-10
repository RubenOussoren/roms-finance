class Assistant::Function::GetLoanPayoff < Assistant::Function
  class << self
    def name
      "get_loan_payoff"
    end

    def description
      <<~INSTRUCTIONS
        Get loan amortization and payoff analysis for a specific loan account.

        This is great for:
        - "When will my mortgage be paid off?"
        - "How much interest am I paying?"
        - "What if I pay an extra $500/month?"
      INSTRUCTIONS
    end
  end

  def params_schema
    build_schema(
      required: [ "account_name" ],
      properties: {
        account_name: {
          type: "string",
          description: "The name of the loan account to analyze"
        },
        extra_payment: {
          type: "number",
          description: "Optional extra monthly payment amount to simulate"
        }
      }
    )
  end

  def strict_mode?
    false
  end

  def call(params = {})
    account = accessible_accounts.where(accountable_type: "Loan").find_by(name: params["account_name"])
    return { error: "Loan account '#{params['account_name']}' not found" } unless account

    extra_payment = (params["extra_payment"] || 0).to_f

    calculator = LoanPayoffCalculator.new(account, extra_payment: extra_payment)
    summary = calculator.summary

    result = {
      account: summary[:account]&.name,
      current_balance: format_money(summary[:current_balance], summary[:currency]),
      monthly_payment: format_money(summary[:monthly_payment], summary[:currency]),
      interest_rate: summary[:interest_rate],
      months_to_payoff: summary[:months_to_payoff],
      payoff_date: summary[:payoff_date],
      total_interest_remaining: format_money(summary[:total_interest_remaining], summary[:currency]),
      years_remaining: summary[:years_remaining],
      currency: summary[:currency]
    }

    if extra_payment > 0
      result[:extra_payment_scenario] = {
        extra_monthly_payment: Money.new(extra_payment, summary[:currency]).format,
        total_monthly_payment: format_money(calculator.total_monthly_payment, summary[:currency]),
        months_saved: calculator.months_saved_with_extra_payment,
        interest_saved: format_money(calculator.interest_saved_with_extra_payment, summary[:currency])
      }
    end

    result
  end

  private
    def format_money(value, currency)
      return nil unless value && currency
      Money.new(value, currency).format
    end
end
