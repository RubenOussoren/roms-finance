# 🇨🇦 Canadian Modified Smith Manoeuvre Simulator
# CRA-compliant debt optimization strategy that converts non-deductible
# mortgage interest into tax-deductible investment loan interest
#
# Strategy Flow:
# 1. Rental income → Prepay primary mortgage (accelerate payoff)
# 2. HELOC → Pay rental expenses (creates deductible interest)
# 3. Rental mortgage interest → Already deductible
# 4. Net effect: Convert non-deductible interest to deductible interest
#
# 🇨🇦 Canadian-Specific Features:
# - Readvanceable HELOC: Credit limit grows as mortgage principal repays
# - Mortgage renewals: Every 5 years with potentially new rates
# - Annual lump-sum prepayments: 10-20% allowed per year on most mortgages
#
# CRA Requirements:
# - HELOC must be used 100% for investment/rental purposes
# - Must maintain clear audit trail of all transactions
# - Interest deductibility depends on use of borrowed funds
class CanadianSmithManoeuvrSimulator
  attr_reader :strategy

  def initialize(strategy)
    @strategy = strategy
  end

  def simulate!
    # First run baseline simulation
    baseline_simulator = BaselineSimulator.new(strategy)
    baseline_simulator.simulate!

    # Then run the Modified Smith strategy
    simulate_modified_smith!
  end

  private

    def simulate_modified_smith!
      entries = []
      start_date = Date.current.beginning_of_month

      # Initial balances
      primary_balance = initial_primary_mortgage_balance
      rental_balance = initial_rental_mortgage_balance
      heloc_balance = 0
      heloc_credit_limit = initial_heloc_credit_limit
      original_primary_balance = primary_balance # Track for readvanceable HELOC

      # Current interest rates (may change at renewals)
      current_primary_rate = primary_mortgage_rate
      current_rental_rate = rental_mortgage_rate

      # Calculate base monthly payments
      primary_payment = calculate_mortgage_payment(primary_balance, current_primary_rate, primary_mortgage_term)
      rental_payment = calculate_mortgage_payment(rental_balance, current_rental_rate, rental_mortgage_term)

      # Track cumulative values
      cumulative_tax_benefit = 0
      strategy_stopped = false
      stop_reason = nil
      cumulative_principal_paid = 0 # Track for readvanceable HELOC

      strategy.simulation_months.times do |month|
        break if strategy_stopped

        calendar_month = start_date + month.months

        # === 🇨🇦 CANADIAN FEATURE: Mortgage Renewals ===
        if should_renew_primary?(calendar_month)
          current_primary_rate = primary_renewal_rate
          # Recalculate payment with new rate and remaining term
          remaining_term = primary_mortgage_term - month
          primary_payment = calculate_mortgage_payment(primary_balance, current_primary_rate, remaining_term) if remaining_term > 0
        end

        # === 🇨🇦 CANADIAN FEATURE: Annual Lump-Sum Prepayment ===
        annual_lump_sum = 0
        if should_make_lump_sum_payment?(calendar_month)
          annual_lump_sum = calculate_lump_sum_payment(primary_balance)
        end

        # === STEP 1: Calculate rental cash flow ===
        rental_income = strategy.rental_income
        rental_expenses = strategy.rental_expenses

        # === STEP 2: Calculate rental mortgage payment ===
        rental_interest = CanadianMortgage.monthly_interest(rental_balance, current_rental_rate)
        rental_principal = rental_balance > 0 ? [ rental_payment - rental_interest, rental_balance ].min : 0

        # === STEP 3: Calculate primary mortgage payment ===
        primary_interest = CanadianMortgage.monthly_interest(primary_balance, current_primary_rate)
        primary_principal = primary_balance > 0 ? [ primary_payment - primary_interest, primary_balance ].min : 0

        # === STEP 4: Modified Smith Manoeuvre Logic ===
        # Net rental cash flow (before mortgage payments)
        net_rental_before_debt = rental_income - rental_expenses

        # In Modified Smith:
        # - Use HELOC to pay rental expenses (makes HELOC interest deductible)
        # - Use rental income to prepay primary mortgage
        heloc_draw_for_expenses = rental_expenses

        # === 🇨🇦 CANADIAN FEATURE: Readvanceable HELOC ===
        # HELOC credit limit grows as mortgage principal is repaid
        if strategy.readvanceable_heloc?
          # As primary mortgage is paid down, HELOC limit grows by the same amount
          cumulative_principal_paid += primary_principal + annual_lump_sum
          base_heloc_limit = initial_heloc_credit_limit

          # HELOC limit = base limit + principal paid, up to max limit
          max_limit = strategy.heloc_max_limit || (original_primary_balance * 0.8)
          heloc_credit_limit = [ base_heloc_limit + cumulative_principal_paid, max_limit ].min
        end

        # Check if we have room on HELOC
        available_heloc_credit = [ heloc_credit_limit - heloc_balance, 0 ].max
        actual_heloc_draw = [ heloc_draw_for_expenses, available_heloc_credit ].min

        # If we can't draw enough from HELOC, use rental income for expenses first
        expenses_covered_by_heloc = actual_heloc_draw
        expenses_covered_by_rental = rental_expenses - expenses_covered_by_heloc

        # Available for prepayment = rental income - expenses not covered by HELOC
        available_for_prepayment = rental_income - expenses_covered_by_rental

        # Prepay primary mortgage with available funds (plus annual lump sum)
        prepayment = [ available_for_prepayment + annual_lump_sum, primary_balance ].min
        prepayment = 0 if primary_balance <= 0

        # === STEP 5: HELOC interest calculation ===
        heloc_interest = CanadianMortgage.monthly_interest_simple(heloc_balance, heloc_interest_rate)
        # For simplicity, we'll capitalize HELOC interest (add to balance)
        # In practice, borrower would pay this from other income
        heloc_payment = heloc_interest # Interest-only payment on HELOC

        # === STEP 6: Tax calculations ===
        # 🇨🇦 CRA Deductibility Rules:
        # - HELOC interest: Deductible if funds used for investment/rental purposes
        # - Rental mortgage interest: Deductible
        # - Primary mortgage interest: NOT deductible (personal residence)
        deductible_interest = rental_interest + heloc_interest
        non_deductible_interest = primary_interest

        # Tax benefit = deductible interest × marginal tax rate
        tax_benefit = deductible_interest * strategy.effective_marginal_tax_rate
        cumulative_tax_benefit += tax_benefit

        # === STEP 7: Update balances ===
        new_heloc_balance = heloc_balance + actual_heloc_draw + heloc_interest - heloc_payment
        new_primary_balance = [ primary_balance - primary_principal - prepayment, 0 ].max
        new_rental_balance = [ rental_balance - rental_principal, 0 ].max

        # Net rental cash flow accounting for the strategy
        net_rental_cash_flow = rental_income - rental_payment - heloc_payment
        net_rental_cash_flow = rental_income if rental_balance <= 0

        # Total debt
        total_debt = new_primary_balance + new_rental_balance + new_heloc_balance

        entry = DebtOptimizationLedgerEntry.new(
          debt_optimization_strategy: strategy,
          month_number: month,
          calendar_month: calendar_month,
          baseline: false,

          # Rental cash flows
          rental_income: rental_income,
          rental_expenses: rental_expenses,
          net_rental_cash_flow: net_rental_cash_flow,

          # HELOC tracking
          heloc_draw: actual_heloc_draw,
          heloc_balance: new_heloc_balance,
          heloc_interest: heloc_interest,
          heloc_payment: heloc_payment,

          # Primary mortgage
          primary_mortgage_balance: new_primary_balance,
          primary_mortgage_payment: primary_balance > 0 ? primary_payment : 0,
          primary_mortgage_principal: primary_principal,
          primary_mortgage_interest: primary_interest,
          primary_mortgage_prepayment: prepayment,

          # Rental mortgage
          rental_mortgage_balance: new_rental_balance,
          rental_mortgage_payment: rental_balance > 0 ? rental_payment : 0,
          rental_mortgage_principal: rental_principal,
          rental_mortgage_interest: rental_interest,

          # Tax calculations
          deductible_interest: deductible_interest,
          non_deductible_interest: non_deductible_interest,
          tax_benefit: tax_benefit,
          cumulative_tax_benefit: cumulative_tax_benefit,

          # Totals
          total_debt: total_debt,
          net_worth_impact: calculate_net_worth_impact(entries, cumulative_tax_benefit),

          # Flags
          strategy_stopped: false,
          stop_reason: nil
        )

        # Check auto-stop rules
        stop_check = strategy.check_auto_stop_rules(entry)
        if stop_check[:triggered]
          entry.strategy_stopped = true
          entry.stop_reason = stop_check[:rule].description
          strategy_stopped = true
          stop_reason = stop_check[:rule].description
        end

        entries << entry

        # Update balances for next iteration
        heloc_balance = new_heloc_balance
        primary_balance = new_primary_balance
        rental_balance = new_rental_balance

        # Natural stop: all debt paid off
        if primary_balance <= 0 && rental_balance <= 0
          break
        end
      end

      # Bulk insert all entries with timestamps
      now = Time.current
      DebtOptimizationLedgerEntry.insert_all(
        entries.map(&:attributes).map { |a|
          a.except("id").merge("created_at" => now, "updated_at" => now)
        }
      )
    end

    def initial_primary_mortgage_balance
      return 0 unless strategy.primary_mortgage.present?
      strategy.primary_mortgage.balance.abs
    end

    def initial_rental_mortgage_balance
      return 0 unless strategy.rental_mortgage.present?
      strategy.rental_mortgage.balance.abs
    end

    def initial_heloc_credit_limit
      # Use strategy's effective HELOC limit if available (respects max limit cap)
      if strategy.respond_to?(:effective_heloc_limit) && strategy.heloc.present?
        return strategy.effective_heloc_limit
      end

      return 100_000 unless strategy.heloc&.accountable.present?
      strategy.heloc.accountable.credit_limit || 100_000
    end

    # 🇨🇦 Canadian mortgage renewal support
    def should_renew_primary?(calendar_month)
      loan = strategy.primary_mortgage&.accountable
      return false unless loan.respond_to?(:renewal_date) && loan.renewal_date.present?

      # Check if we've reached the renewal date
      calendar_month >= loan.renewal_date
    end

    def primary_renewal_rate
      loan = strategy.primary_mortgage&.accountable
      return primary_mortgage_rate unless loan.respond_to?(:renewal_rate)

      (loan.renewal_rate || loan.interest_rate || 5) / 100.0
    end

    # 🇨🇦 Canadian annual lump-sum prepayment support
    def should_make_lump_sum_payment?(calendar_month)
      loan = strategy.primary_mortgage&.accountable
      return false unless loan.respond_to?(:annual_lump_sum_month)
      return false unless loan.annual_lump_sum_month.present?
      return false unless loan.annual_lump_sum_amount.present? && loan.annual_lump_sum_amount > 0

      calendar_month.month == loan.annual_lump_sum_month
    end

    def calculate_lump_sum_payment(current_balance)
      loan = strategy.primary_mortgage&.accountable
      return 0 unless loan.respond_to?(:annual_lump_sum_amount)
      return 0 unless loan.annual_lump_sum_amount.present?

      # Don't pay more than the balance
      [ loan.annual_lump_sum_amount, current_balance ].min
    end

    def primary_mortgage_rate
      return 0.05 unless strategy.primary_mortgage&.accountable.present?
      (strategy.primary_mortgage.accountable.interest_rate || 5) / 100.0
    end

    def rental_mortgage_rate
      return 0.05 unless strategy.rental_mortgage&.accountable.present?
      (strategy.rental_mortgage.accountable.interest_rate || 5) / 100.0
    end

    def heloc_interest_rate
      return (strategy.heloc_interest_rate || 7) / 100.0 if strategy.heloc_interest_rate.present?
      return 0.07 unless strategy.heloc&.accountable.present?
      (strategy.heloc.accountable.interest_rate || 7) / 100.0
    end

    def primary_mortgage_term
      return 300 unless strategy.primary_mortgage&.accountable.present?
      strategy.primary_mortgage.accountable.term_months || 300
    end

    def rental_mortgage_term
      return 300 unless strategy.rental_mortgage&.accountable.present?
      strategy.rental_mortgage.accountable.term_months || 300
    end

    def calculate_mortgage_payment(principal, annual_rate, term_months)
      CanadianMortgage.monthly_payment(principal, annual_rate, term_months)
    end

    def calculate_net_worth_impact(entries, cumulative_tax_benefit)
      # Net worth impact = cumulative tax benefit (money saved)
      # This is a simplified calculation - could be expanded to include
      # investment growth from reinvested tax savings
      cumulative_tax_benefit
    end
end
