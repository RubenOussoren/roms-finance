# Baseline debt simulation — no optimization strategy applied.
# Mortgage payments proceed on schedule with no prepayments.
class BaselineSimulator < AbstractDebtSimulator
  private

    def scenario_type
      "baseline"
    end

    # No prepayment in baseline
    def calculate_prepayment(rental_surplus, primary_balance, remaining_privilege)
      0
    end
end
