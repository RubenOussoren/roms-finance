# 🇨🇦 Canadian Modified Smith Manoeuvre Simulator
# CRA-compliant debt optimization strategy that converts non-deductible
# mortgage interest into tax-deductible investment loan interest
#
# Strategy Flow:
# 1. Rental income → HELOC interest → Prepay primary mortgage (accelerate payoff)
# 2. HELOC → Pay rental expenses (creates deductible interest)
# 3. Rental mortgage interest → Already deductible
# 4. Net effect: Convert non-deductible interest to deductible interest
#
# 🇨🇦 Canadian-Specific Features:
# - Readvanceable HELOC: Credit limit grows as mortgage principal repays
# - Mortgage renewals: Every N months with potentially new rates
# - Annual lump-sum prepayments: Subject to privilege limits
#
# CRA Requirements:
# - HELOC must be used 100% for investment/rental purposes
# - Must maintain clear audit trail of all transactions
# - Interest deductibility depends on use of borrowed funds
class CanadianSmithManoeuvrSimulator
  include MortgageRenewalSupport
  include LoanTermDefaults

  attr_reader :strategy

  def initialize(strategy)
    @strategy = strategy
  end

  def simulate!
    # First run baseline simulation
    BaselineSimulator.new(strategy).simulate!

    # Then run prepay-only simulation
    PrepayOnlySimulator.new(strategy).simulate!

    # Then run the Modified Smith strategy
    simulate_modified_smith!
  end

  private

    # Mutable running state for the month-by-month simulation loop.
    #
    # Balance fields:      primary_balance, rental_balance, heloc_balance, heloc_credit_limit
    # Original snapshot:   original_primary_balance (for readvanceable ratio cap)
    # Current rates:       current_primary_rate, current_rental_rate (updated on renewal)
    # Monthly payments:    primary_payment, rental_payment (recalculated on renewal)
    # Cumulative trackers: cumulative_tax_benefit, cumulative_heloc_interest,
    #                      cumulative_strategy_mortgage_interest, cumulative_baseline_mortgage_interest,
    #                      cumulative_principal_paid
    # Annual tracking:     annual_prepayment_total, current_year (reset each Jan)
    # Auto-stop:           strategy_stopped, stop_reason
    # Baseline reference:  baseline_entries_hash (month_number → baseline entry for comparison)
    SimulationState = Struct.new(
      :primary_balance, :rental_balance, :heloc_balance, :heloc_credit_limit,
      :original_primary_balance, :current_primary_rate, :current_rental_rate,
      :primary_payment, :rental_payment,
      :cumulative_tax_benefit, :cumulative_heloc_interest,
      :cumulative_strategy_mortgage_interest, :cumulative_baseline_mortgage_interest,
      :cumulative_principal_paid, :annual_prepayment_total, :current_year,
      :strategy_stopped, :stop_reason, :baseline_entries_hash,
      keyword_init: true
    )

    def simulate_modified_smith!
      state = initialize_simulation_state
      entries = []
      start_date = Date.current.beginning_of_month

      strategy.simulation_months.times do |month|
        break if state.strategy_stopped
        calendar_month = start_date + month.months

        reset_annual_tracking!(state, calendar_month)
        process_mortgage_renewal!(state, month)

        payments = calculate_mortgage_payments(state)
        heloc_draw = calculate_heloc_draw(state, payments, calendar_month)
        cash_flow = calculate_cash_flow_and_prepayment(state, heloc_draw)
        tax_metrics = calculate_tax_and_cumulative_metrics!(state, month, payments, cash_flow)

        entry = build_ledger_entry(state, month, calendar_month, payments, heloc_draw, cash_flow, tax_metrics)
        check_auto_stop!(state, entry)
        entries << entry

        advance_balances!(state, payments, heloc_draw, cash_flow)
        break if state.primary_balance <= 0 && state.rental_balance <= 0
      end

      bulk_insert_entries(entries)
    end

    def initialize_simulation_state
      primary_balance = initial_primary_mortgage_balance
      rental_balance = initial_rental_mortgage_balance
      primary_rate = primary_mortgage_rate
      rental_rate = rental_mortgage_rate

      SimulationState.new(
        primary_balance: primary_balance,
        rental_balance: rental_balance,
        heloc_balance: 0,
        heloc_credit_limit: initial_heloc_credit_limit,
        original_primary_balance: primary_balance,
        current_primary_rate: primary_rate,
        current_rental_rate: rental_rate,
        primary_payment: calculate_mortgage_payment(primary_balance, primary_rate, primary_mortgage_term),
        rental_payment: calculate_mortgage_payment(rental_balance, rental_rate, rental_mortgage_term),
        cumulative_tax_benefit: 0,
        cumulative_heloc_interest: 0,
        cumulative_strategy_mortgage_interest: 0,
        cumulative_baseline_mortgage_interest: 0,
        cumulative_principal_paid: 0,
        annual_prepayment_total: 0,
        current_year: nil,
        strategy_stopped: false,
        stop_reason: nil,
        baseline_entries_hash: strategy.ledger_entries
          .where(scenario_type: "baseline")
          .index_by(&:month_number)
      )
    end

    def reset_annual_tracking!(state, calendar_month)
      if state.current_year != calendar_month.year
        state.annual_prepayment_total = 0
        state.current_year = calendar_month.year
      end
    end

    def process_mortgage_renewal!(state, month)
      if should_renew_primary?(month)
        state.current_primary_rate = primary_renewal_rate
        remaining_term = primary_mortgage_term - month
        state.primary_payment = calculate_mortgage_payment(state.primary_balance, state.current_primary_rate, remaining_term) if remaining_term > 0
      end
    end

    def calculate_mortgage_payments(state)
      primary_interest = CanadianMortgage.monthly_interest(state.primary_balance, state.current_primary_rate)
      primary_principal = state.primary_balance > 0 ? [ state.primary_payment - primary_interest, state.primary_balance ].min : 0
      rental_interest = CanadianMortgage.monthly_interest(state.rental_balance, state.current_rental_rate)
      rental_principal = state.rental_balance > 0 ? [ state.rental_payment - rental_interest, state.rental_balance ].min : 0

      { primary_interest: primary_interest, primary_principal: primary_principal,
        rental_interest: rental_interest, rental_principal: rental_principal }
    end

    def calculate_heloc_draw(state, payments, calendar_month)
      annual_lump_sum = 0
      if should_make_lump_sum_payment?(calendar_month)
        annual_lump_sum = calculate_lump_sum_payment(state.primary_balance)
      end

      if strategy.readvanceable_heloc?
        state.cumulative_principal_paid += payments[:primary_principal] + annual_lump_sum
        base_heloc_limit = initial_heloc_credit_limit
        max_limit = strategy.heloc_max_limit || (state.original_primary_balance * READVANCEABLE_MAX_RATIO)
        state.heloc_credit_limit = [ base_heloc_limit + state.cumulative_principal_paid, max_limit ].min
      end

      available_heloc_credit = [ state.heloc_credit_limit - state.heloc_balance, 0 ].max
      actual_draw = [ strategy.rental_expenses, available_heloc_credit ].min

      { actual_draw: actual_draw,
        expenses_covered_by_heloc: actual_draw,
        expenses_covered_by_rental: strategy.rental_expenses - actual_draw,
        annual_lump_sum: annual_lump_sum }
    end

    def calculate_cash_flow_and_prepayment(state, heloc_draw)
      heloc_interest = CanadianMortgage.monthly_interest_simple(state.heloc_balance, heloc_interest_rate)
      heloc_payment = heloc_interest

      rental_surplus = strategy.rental_income - heloc_draw[:expenses_covered_by_rental]
      heloc_interest_from_rental = [ heloc_interest, [ rental_surplus, 0 ].max ].min
      heloc_interest_from_pocket = heloc_interest - heloc_interest_from_rental

      available_for_prepayment = [ rental_surplus - heloc_interest_from_rental, 0 ].max

      privilege_limit = calculate_privilege_limit
      remaining_privilege = [ privilege_limit - state.annual_prepayment_total, 0 ].max
      raw_prepayment = available_for_prepayment + heloc_draw[:annual_lump_sum]
      prepayment = [ raw_prepayment, state.primary_balance, remaining_privilege ].min
      prepayment = 0 if state.primary_balance <= 0
      state.annual_prepayment_total += prepayment
      prepayment_capped = raw_prepayment > remaining_privilege && remaining_privilege < raw_prepayment

      { heloc_interest: heloc_interest, heloc_payment: heloc_payment,
        heloc_interest_from_rental: heloc_interest_from_rental,
        heloc_interest_from_pocket: heloc_interest_from_pocket,
        prepayment: prepayment, prepayment_capped: prepayment_capped,
        privilege_limit: privilege_limit }
    end

    def calculate_tax_and_cumulative_metrics!(state, month, payments, cash_flow)
      deductible_interest = payments[:rental_interest] + cash_flow[:heloc_interest]
      non_deductible_interest = payments[:primary_interest]

      tax_benefit = deductible_interest * strategy.effective_marginal_tax_rate
      state.cumulative_tax_benefit += tax_benefit

      state.cumulative_heloc_interest += cash_flow[:heloc_interest]
      state.cumulative_strategy_mortgage_interest += payments[:primary_interest]
      baseline_entry = state.baseline_entries_hash[month]
      state.cumulative_baseline_mortgage_interest += (baseline_entry&.primary_mortgage_interest || 0)
      cumulative_net_benefit = (state.cumulative_baseline_mortgage_interest - state.cumulative_strategy_mortgage_interest) +
                               state.cumulative_tax_benefit - state.cumulative_heloc_interest

      { deductible_interest: deductible_interest, non_deductible_interest: non_deductible_interest,
        tax_benefit: tax_benefit, cumulative_net_benefit: cumulative_net_benefit }
    end

    # Maps simulation state + computed values into a DebtOptimizationLedgerEntry.
    # Long due to the 31 named parameters on the model — pure data mapping, no branching.
    def build_ledger_entry(state, month, calendar_month, payments, heloc_draw, cash_flow, tax_metrics)
      new_heloc_balance = state.heloc_balance + heloc_draw[:actual_draw] + cash_flow[:heloc_interest] - cash_flow[:heloc_payment]
      new_primary_balance = [ state.primary_balance - payments[:primary_principal] - cash_flow[:prepayment], 0 ].max
      new_rental_balance = [ state.rental_balance - payments[:rental_principal], 0 ].max

      net_rental_cash_flow = strategy.rental_income - state.rental_payment - cash_flow[:heloc_interest_from_rental]
      net_rental_cash_flow = strategy.rental_income if state.rental_balance <= 0

      total_debt = new_primary_balance + new_rental_balance + new_heloc_balance

      entry_metadata = {}
      entry_metadata[:prepayment_capped] = true if cash_flow[:prepayment_capped]
      entry_metadata[:privilege_limit] = cash_flow[:privilege_limit] if cash_flow[:prepayment_capped]
      entry_metadata[:cumulative_net_benefit] = tax_metrics[:cumulative_net_benefit].round(4)

      DebtOptimizationLedgerEntry.new(
        debt_optimization_strategy: strategy,
        month_number: month,
        calendar_month: calendar_month,
        scenario_type: "modified_smith",
        rental_income: strategy.rental_income,
        rental_expenses: strategy.rental_expenses,
        net_rental_cash_flow: net_rental_cash_flow,
        heloc_draw: heloc_draw[:actual_draw],
        heloc_balance: new_heloc_balance,
        heloc_interest: cash_flow[:heloc_interest],
        heloc_payment: cash_flow[:heloc_payment],
        heloc_interest_from_rental: cash_flow[:heloc_interest_from_rental],
        heloc_interest_from_pocket: cash_flow[:heloc_interest_from_pocket],
        primary_mortgage_balance: new_primary_balance,
        primary_mortgage_payment: state.primary_balance > 0 ? state.primary_payment : 0,
        primary_mortgage_principal: payments[:primary_principal],
        primary_mortgage_interest: payments[:primary_interest],
        primary_mortgage_prepayment: cash_flow[:prepayment],
        rental_mortgage_balance: new_rental_balance,
        rental_mortgage_payment: state.rental_balance > 0 ? state.rental_payment : 0,
        rental_mortgage_principal: payments[:rental_principal],
        rental_mortgage_interest: payments[:rental_interest],
        deductible_interest: tax_metrics[:deductible_interest],
        non_deductible_interest: tax_metrics[:non_deductible_interest],
        tax_benefit: tax_metrics[:tax_benefit],
        cumulative_tax_benefit: state.cumulative_tax_benefit,
        total_debt: total_debt,
        net_worth_impact: state.cumulative_tax_benefit,
        metadata: entry_metadata,
        strategy_stopped: false,
        stop_reason: nil
      )
    end

    def check_auto_stop!(state, entry)
      stop_check = strategy.check_auto_stop_rules(entry)
      if stop_check[:triggered]
        entry.strategy_stopped = true
        entry.stop_reason = stop_check[:rule].description
        state.strategy_stopped = true
        state.stop_reason = stop_check[:rule].description
      end
    end

    def advance_balances!(state, payments, heloc_draw, cash_flow)
      state.heloc_balance = state.heloc_balance + heloc_draw[:actual_draw] + cash_flow[:heloc_interest] - cash_flow[:heloc_payment]
      state.primary_balance = [ state.primary_balance - payments[:primary_principal] - cash_flow[:prepayment], 0 ].max
      state.rental_balance = [ state.rental_balance - payments[:rental_principal], 0 ].max
    end

    def bulk_insert_entries(entries)
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
      if strategy.respond_to?(:effective_heloc_limit) && strategy.heloc.present?
        return strategy.effective_heloc_limit
      end

      return DEFAULT_HELOC_LIMIT unless strategy.heloc&.accountable.present?
      strategy.heloc.accountable.credit_limit || DEFAULT_HELOC_LIMIT
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

      [ loan.annual_lump_sum_amount, current_balance ].min
    end

    def heloc_interest_rate
      return (strategy.heloc_interest_rate || 7) / 100.0 if strategy.heloc_interest_rate.present?
      return DEFAULT_HELOC_RATE unless strategy.heloc&.accountable.present?
      (strategy.heloc.accountable.interest_rate || 7) / 100.0
    end

end
