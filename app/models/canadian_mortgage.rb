# Canonical Canadian fixed-rate mortgage math.
#
# Canadian fixed-rate mortgages compound semi-annually per the Interest Act
# (R.S.C., 1985, c. I-15, s. 6). The quoted annual rate is a nominal rate
# compounded twice per year, not twelve times. To derive the effective
# monthly rate we convert:
#
#   effective_monthly_rate = (1 + annual_rate / 2)^(1/6) - 1
#
# This yields a slightly lower monthly rate than the US convention of
# annual_rate / 12, resulting in lower monthly payments (~$12/month on
# a typical $400K mortgage at 5%).
#
# HELOCs and variable-rate products in Canada typically compound monthly,
# so the standard annual_rate / 12 applies to those.
class CanadianMortgage
  # Convert a quoted Canadian fixed-rate annual rate to an effective monthly rate.
  #
  #   CanadianMortgage.monthly_rate(0.05)  # => ~0.004123915
  #
  # Compare US monthly compounding: 0.05 / 12 = 0.004166667
  def self.monthly_rate(annual_rate)
    return 0.0 if annual_rate.nil? || annual_rate.zero?

    (1 + annual_rate / 2.0)**(1.0 / 6) - 1
  end

  # Standard monthly compounding rate (for HELOCs, variable-rate products,
  # or non-Canadian loans).
  def self.monthly_rate_simple(annual_rate)
    return 0.0 if annual_rate.nil? || annual_rate.zero?

    annual_rate / 12.0
  end

  # Calculate the fixed monthly payment for a Canadian mortgage using
  # semi-annual compounding.
  #
  #   CanadianMortgage.monthly_payment(400_000, 0.05, 300)  # => ~2326.37
  def self.monthly_payment(principal, annual_rate, term_months)
    return 0 if principal <= 0 || term_months <= 0

    r = monthly_rate(annual_rate)
    return principal.to_f / term_months if r.zero?

    (principal * r * (1 + r)**term_months) /
      ((1 + r)**term_months - 1)
  end

  # Calculate monthly interest on a balance using Canadian semi-annual compounding.
  def self.monthly_interest(balance, annual_rate)
    return 0 if balance <= 0

    balance * monthly_rate(annual_rate)
  end

  # Calculate monthly interest using simple monthly compounding (for HELOCs).
  def self.monthly_interest_simple(balance, annual_rate)
    return 0 if balance <= 0

    balance * monthly_rate_simple(annual_rate)
  end
end
