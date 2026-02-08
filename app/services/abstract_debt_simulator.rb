# Base class for simple debt simulators (baseline and prepay-only).
# Uses template method pattern: subclasses override `scenario_type` and
# `calculate_prepayment` to control behavior.
#
# The Smith simulator keeps its own loop (HELOC/readvanceable logic is too
# different) but reuses MortgageRenewalSupport.
class AbstractDebtSimulator
  include MortgageRenewalSupport
  include LoanTermDefaults

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

    # Current interest rates (may change at renewals)
    current_primary_rate = primary_mortgage_rate
    current_rental_rate = rental_mortgage_rate

    # Calculate monthly payments
    primary_payment = calculate_mortgage_payment(primary_balance, current_primary_rate, primary_mortgage_term)
    rental_payment = calculate_mortgage_payment(rental_balance, current_rental_rate, rental_mortgage_term)

    cumulative_interest = 0

    # Annual prepayment privilege tracking
    annual_prepayment_total = 0
    current_year = nil

    strategy.simulation_months.times do |month|
      calendar_month = start_date + month.months

      # Reset annual prepayment tracking at year boundary
      if current_year != calendar_month.year
        annual_prepayment_total = 0
        current_year = calendar_month.year
      end

      # Mortgage renewals (via MortgageRenewalSupport)
      if should_renew_primary?(month)
        current_primary_rate = primary_renewal_rate
        remaining_term = primary_mortgage_term - month
        primary_payment = calculate_mortgage_payment(primary_balance, current_primary_rate, remaining_term) if remaining_term > 0
      end

      # Calculate interest and principal for primary mortgage
      primary_interest = CanadianMortgage.monthly_interest(primary_balance, current_primary_rate)
      primary_principal = [ primary_payment - primary_interest, primary_balance ].min
      primary_principal = 0 if primary_balance <= 0
      primary_interest = 0 if primary_balance <= 0

      # Calculate interest and principal for rental mortgage
      rental_interest = CanadianMortgage.monthly_interest(rental_balance, current_rental_rate)
      rental_principal = [ rental_payment - rental_interest, rental_balance ].min
      rental_principal = 0 if rental_balance <= 0
      rental_interest = 0 if rental_balance <= 0

      # Calculate prepayment (template method)
      rental_surplus = strategy.rental_income - strategy.rental_expenses
      privilege_limit = calculate_privilege_limit
      remaining_privilege = [ privilege_limit - annual_prepayment_total, 0 ].max
      prepayment = calculate_prepayment(rental_surplus, primary_balance, remaining_privilege)
      annual_prepayment_total += prepayment

      # Compute post-payment balances
      new_primary_balance = [ primary_balance - primary_principal - prepayment, 0 ].max
      new_rental_balance = [ rental_balance - rental_principal, 0 ].max

      # Net rental cash flow
      net_rental = strategy.rental_income - strategy.rental_expenses - rental_payment
      net_rental = strategy.rental_income - strategy.rental_expenses if rental_balance <= 0

      # Tax calculations
      deductible_interest = rental_interest
      non_deductible_interest = primary_interest
      tax_benefit = deductible_interest * strategy.effective_marginal_tax_rate
      cumulative_interest += primary_interest + rental_interest

      total_debt = new_primary_balance + new_rental_balance

      entry = DebtOptimizationLedgerEntry.new(
        debt_optimization_strategy: strategy,
        month_number: month,
        calendar_month: calendar_month,
        scenario_type: scenario_type,

        rental_income: strategy.rental_income,
        rental_expenses: strategy.rental_expenses,
        net_rental_cash_flow: net_rental,

        heloc_draw: 0,
        heloc_balance: 0,
        heloc_interest: 0,
        heloc_payment: 0,

        primary_mortgage_balance: new_primary_balance,
        primary_mortgage_payment: primary_balance > 0 ? primary_payment : 0,
        primary_mortgage_principal: primary_principal,
        primary_mortgage_interest: primary_interest,
        primary_mortgage_prepayment: prepayment,

        rental_mortgage_balance: new_rental_balance,
        rental_mortgage_payment: rental_balance > 0 ? rental_payment : 0,
        rental_mortgage_principal: rental_principal,
        rental_mortgage_interest: rental_interest,

        deductible_interest: deductible_interest,
        non_deductible_interest: non_deductible_interest,
        tax_benefit: tax_benefit,
        cumulative_tax_benefit: entries.sum(&:tax_benefit) + tax_benefit,

        total_debt: total_debt,
        net_worth_impact: 0,

        strategy_stopped: false,
        stop_reason: nil
      )

      entries << entry

      primary_balance = new_primary_balance
      rental_balance = new_rental_balance

      break if primary_balance <= 0 && rental_balance <= 0
    end

    # Bulk insert
    now = Time.current
    DebtOptimizationLedgerEntry.insert_all(
      entries.map(&:attributes).map { |a|
        a.except("id").merge("created_at" => now, "updated_at" => now)
      }
    )
  end

  private

    # Template methods — override in subclasses
    def scenario_type
      raise NotImplementedError
    end

    def calculate_prepayment(rental_surplus, primary_balance, remaining_privilege)
      0
    end

    def initial_primary_mortgage_balance
      return 0 unless strategy.primary_mortgage.present?
      strategy.primary_mortgage.balance.abs
    end

    def initial_rental_mortgage_balance
      return 0 unless strategy.rental_mortgage.present?
      strategy.rental_mortgage.balance.abs
    end
end
