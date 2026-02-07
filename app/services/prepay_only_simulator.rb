# Prepay-only comparator — uses rental surplus to prepay primary mortgage
# without any HELOC or Smith Manoeuvre tax optimization.
# Provides a middle-ground comparison between baseline (no action) and
# the full Smith Manoeuvre.
class PrepayOnlySimulator < AbstractDebtSimulator
  private

    def scenario_type
      "prepay_only"
    end

    # Apply rental surplus as prepayment, respecting privilege limits
    def calculate_prepayment(rental_surplus, primary_balance, remaining_privilege)
      return 0 if primary_balance <= 0

      [ [ rental_surplus, 0 ].max, primary_balance, remaining_privilege ].min
    end
end
