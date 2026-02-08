# 🇨🇦 PAG 2025 Compliance concern
# Ensures projections meet FP Canada's Projection Assumption Guidelines
module PagCompliant
  extend ActiveSupport::Concern

  # PAG 2025 default assumptions from FP Canada
  PAG_2025_ASSUMPTIONS = {
    equity_return: 0.0628,        # 6.28% nominal
    fixed_income_return: 0.0409,  # 4.09% nominal
    cash_return: 0.0295,          # 2.95% nominal
    inflation_rate: 0.021,        # 2.10%
    short_term_return: 0.0295,    # Same as cash
    volatility_equity: 0.18,      # 18% standard deviation
    volatility_fixed_income: 0.05, # 5% standard deviation
    safety_margin: -0.005         # -0.50% conservative adjustment
  }.freeze

  included do
    # Models including this can track PAG compliance
  end

  # Apply PAG 2025 defaults to assumptions
  def use_pag_assumptions!
    return unless respond_to?(:projection_assumptions)

    assumption = projection_assumptions.active.first
    return unless assumption.present?

    assumption.apply_pag_defaults!
  end

  # Check if using PAG-compliant assumptions
  def pag_compliant?
    return false unless respond_to?(:projection_assumptions)

    assumption = projection_assumptions.active.first
    assumption&.pag_compliant? || false
  end

  # Get compliance badge text
  def compliance_badge
    return "Using standard Canadian guidelines (conservative)" if pag_compliant?
    "Using custom assumptions"
  end

  # Get PAG default for a specific assumption
  def pag_default(key)
    PAG_2025_ASSUMPTIONS[key.to_sym]
  end

  # Validate that assumptions are within reasonable PAG bounds
  def pag_assumption_warnings
    warnings = []

    return warnings unless respond_to?(:projection_assumptions)

    assumption = projection_assumptions.active.first
    return warnings unless assumption.present?

    if assumption.expected_return.present?
      if assumption.expected_return > 0.12
        warnings << "Your expected return of #{(assumption.expected_return * 100).round(1)}% is higher than the guideline maximum of 12%. Consider using a more conservative estimate."
      elsif assumption.expected_return < 0.02
        warnings << "Your expected return of #{(assumption.expected_return * 100).round(1)}% is below the guideline cash return of 2.95%. This may understate your growth potential."
      end
    end

    if assumption.inflation_rate.present?
      if assumption.inflation_rate > 0.05
        warnings << "Your inflation rate of #{(assumption.inflation_rate * 100).round(1)}% is above the historical norm. This will significantly reduce projected real returns."
      elsif assumption.inflation_rate < 0.01
        warnings << "Your inflation rate of #{(assumption.inflation_rate * 100).round(1)}% is unusually low. This may overstate your purchasing power in future projections."
      end
    end

    warnings
  end

  module ClassMethods
    def pag_2025_defaults
      PAG_2025_ASSUMPTIONS
    end
  end
end
