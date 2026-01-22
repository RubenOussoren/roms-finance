# 🌍 Universal baseline debt simulation
# Simple month-by-month simulation with no optimization strategy
class BaselineSimulator
  attr_reader :strategy

  def initialize(strategy)
    @strategy = strategy
  end

  def simulate!
    entries = []
    start_date = Date.current.beginning_of_month

    # Initial balances from accounts
    primary_balance = initial_primary_mortgage_balance
    rental_balance = initial_rental_mortgage_balance
    heloc_balance = 0 # Not used in baseline

    # Calculate monthly payments
    primary_payment = calculate_mortgage_payment(primary_balance, primary_mortgage_rate, primary_mortgage_term)
    rental_payment = calculate_mortgage_payment(rental_balance, rental_mortgage_rate, rental_mortgage_term)

    cumulative_interest = 0

    strategy.simulation_months.times do |month|
      calendar_month = start_date + month.months

      # Calculate interest and principal for primary mortgage
      primary_interest = primary_balance * (primary_mortgage_rate / 12)
      primary_principal = [ primary_payment - primary_interest, primary_balance ].min
      primary_principal = 0 if primary_balance <= 0
      primary_interest = 0 if primary_balance <= 0

      # Calculate interest and principal for rental mortgage
      rental_interest = rental_balance * (rental_mortgage_rate / 12)
      rental_principal = [ rental_payment - rental_interest, rental_balance ].min
      rental_principal = 0 if rental_balance <= 0
      rental_interest = 0 if rental_balance <= 0

      # Net rental cash flow (income - expenses - mortgage payment)
      net_rental = strategy.rental_income - strategy.rental_expenses - rental_payment
      net_rental = strategy.rental_income - strategy.rental_expenses if rental_balance <= 0

      # In baseline, rental income just covers expenses (no prepayment strategy)
      # Any excess stays with owner, no debt acceleration

      # 🇨🇦 Rental mortgage interest is deductible in Canada
      deductible_interest = rental_interest
      non_deductible_interest = primary_interest

      # Tax benefit from deductible interest
      tax_benefit = deductible_interest * strategy.effective_marginal_tax_rate
      cumulative_interest += primary_interest + rental_interest

      # Total debt
      total_debt = primary_balance + rental_balance

      entry = DebtOptimizationLedgerEntry.new(
        debt_optimization_strategy: strategy,
        month_number: month,
        calendar_month: calendar_month,
        baseline: true,

        # Rental cash flows
        rental_income: strategy.rental_income,
        rental_expenses: strategy.rental_expenses,
        net_rental_cash_flow: net_rental,

        # HELOC (not used in baseline)
        heloc_draw: 0,
        heloc_balance: 0,
        heloc_interest: 0,
        heloc_payment: 0,

        # Primary mortgage
        primary_mortgage_balance: primary_balance,
        primary_mortgage_payment: primary_balance > 0 ? primary_payment : 0,
        primary_mortgage_principal: primary_principal,
        primary_mortgage_interest: primary_interest,
        primary_mortgage_prepayment: 0,

        # Rental mortgage
        rental_mortgage_balance: rental_balance,
        rental_mortgage_payment: rental_balance > 0 ? rental_payment : 0,
        rental_mortgage_principal: rental_principal,
        rental_mortgage_interest: rental_interest,

        # Tax calculations
        deductible_interest: deductible_interest,
        non_deductible_interest: non_deductible_interest,
        tax_benefit: tax_benefit,
        cumulative_tax_benefit: entries.sum(&:tax_benefit) + tax_benefit,

        # Totals
        total_debt: total_debt,
        net_worth_impact: 0,

        # Flags
        strategy_stopped: false,
        stop_reason: nil
      )

      entries << entry

      # Update balances for next month
      primary_balance = [ primary_balance - primary_principal, 0 ].max
      rental_balance = [ rental_balance - rental_principal, 0 ].max

      # Stop if all debt is paid off
      break if primary_balance <= 0 && rental_balance <= 0
    end

    # Bulk insert all entries with timestamps
    now = Time.current
    DebtOptimizationLedgerEntry.insert_all(
      entries.map(&:attributes).map { |a|
        a.except("id").merge("created_at" => now, "updated_at" => now)
      }
    )
  end

  private

    def initial_primary_mortgage_balance
      return 0 unless strategy.primary_mortgage.present?
      strategy.primary_mortgage.balance.abs
    end

    def initial_rental_mortgage_balance
      return 0 unless strategy.rental_mortgage.present?
      strategy.rental_mortgage.balance.abs
    end

    def primary_mortgage_rate
      return 0.05 unless strategy.primary_mortgage&.accountable.present?
      (strategy.primary_mortgage.accountable.interest_rate || 5) / 100.0
    end

    def rental_mortgage_rate
      return 0.05 unless strategy.rental_mortgage&.accountable.present?
      (strategy.rental_mortgage.accountable.interest_rate || 5) / 100.0
    end

    def primary_mortgage_term
      return 300 unless strategy.primary_mortgage&.accountable.present?
      strategy.primary_mortgage.accountable.term_months || 300
    end

    def rental_mortgage_term
      return 300 unless strategy.rental_mortgage&.accountable.present?
      strategy.rental_mortgage.accountable.term_months || 300
    end

    # Standard mortgage payment calculation
    def calculate_mortgage_payment(principal, annual_rate, term_months)
      return 0 if principal <= 0 || term_months <= 0

      monthly_rate = annual_rate / 12.0
      return principal / term_months if monthly_rate.zero?

      (principal * monthly_rate * (1 + monthly_rate)**term_months) /
        ((1 + monthly_rate)**term_months - 1)
    end
end
