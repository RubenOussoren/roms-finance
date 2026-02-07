# Shared mortgage renewal logic for debt simulators.
# Supports periodic renewals every N months (default 60 = 5-year term).
module MortgageRenewalSupport
  extend ActiveSupport::Concern

  private

    def should_renew_primary?(month_index)
      loan = strategy.primary_mortgage&.accountable
      return false unless loan&.canadian_mortgage?

      term = loan.renewal_term_months || 60
      term > 0 && month_index > 0 && (month_index % term).zero?
    end

    def primary_renewal_rate
      loan = strategy.primary_mortgage&.accountable
      return primary_mortgage_rate unless loan.respond_to?(:renewal_rate)

      (loan.renewal_rate || loan.interest_rate || 5) / 100.0
    end
end
