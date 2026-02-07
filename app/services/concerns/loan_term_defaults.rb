# Shared loan term helpers and default constants for debt simulators.
# Included by both AbstractDebtSimulator (baseline, prepay-only) and
# CanadianSmithManoeuvrSimulator (modified Smith).
module LoanTermDefaults
  extend ActiveSupport::Concern

  DEFAULT_MORTGAGE_RATE     = 0.05      # 5% annual
  DEFAULT_HELOC_RATE        = 0.07      # 7% annual
  DEFAULT_TERM_MONTHS       = 300       # 25 years
  DEFAULT_HELOC_LIMIT       = 100_000   # $100K
  READVANCEABLE_MAX_RATIO   = 0.8       # 80% of original primary balance

  private

    def primary_mortgage_rate
      return DEFAULT_MORTGAGE_RATE unless strategy.primary_mortgage&.accountable.present?
      (strategy.primary_mortgage.accountable.interest_rate || 5) / 100.0
    end

    def rental_mortgage_rate
      return DEFAULT_MORTGAGE_RATE unless strategy.rental_mortgage&.accountable.present?
      (strategy.rental_mortgage.accountable.interest_rate || 5) / 100.0
    end

    def primary_mortgage_term
      return DEFAULT_TERM_MONTHS unless strategy.primary_mortgage&.accountable.present?
      strategy.primary_mortgage.accountable.term_months || DEFAULT_TERM_MONTHS
    end

    def rental_mortgage_term
      return DEFAULT_TERM_MONTHS unless strategy.rental_mortgage&.accountable.present?
      strategy.rental_mortgage.accountable.term_months || DEFAULT_TERM_MONTHS
    end

    def calculate_privilege_limit
      loan = strategy.primary_mortgage&.accountable
      return Float::INFINITY unless loan&.prepayment_privilege_percent.present?

      initial_primary_mortgage_balance * loan.prepayment_privilege_percent / 100.0
    end

    def calculate_mortgage_payment(principal, annual_rate, term_months)
      CanadianMortgage.monthly_payment(principal, annual_rate, term_months)
    end
end
