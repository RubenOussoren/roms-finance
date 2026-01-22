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
    volatility_fixed_income: 0.05 # 5% standard deviation
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
    return "Prepared using FP Canada PAG 2025" if pag_compliant?
    "Custom assumptions"
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
        warnings << "Expected return (#{(assumption.expected_return * 100).round(1)}%) exceeds PAG reasonable maximum (12%)"
      elsif assumption.expected_return < 0.02
        warnings << "Expected return (#{(assumption.expected_return * 100).round(1)}%) is below PAG cash return assumption"
      end
    end

    if assumption.inflation_rate.present?
      if assumption.inflation_rate > 0.05
        warnings << "Inflation rate (#{(assumption.inflation_rate * 100).round(1)}%) exceeds historical norms"
      elsif assumption.inflation_rate < 0.01
        warnings << "Inflation rate (#{(assumption.inflation_rate * 100).round(1)}%) may be unrealistically low"
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
