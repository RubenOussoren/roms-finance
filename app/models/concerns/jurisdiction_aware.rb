# 🇨🇦 JurisdictionAware concern for jurisdiction-specific behavior
# 🔧 Extensibility: Supports future US/UK expansion
module JurisdictionAware
  extend ActiveSupport::Concern

  included do
    # Families have a country field that maps to jurisdiction
  end

  # Get the jurisdiction for this model
  def jurisdiction
    country_code = determine_country_code
    @jurisdiction ||= Jurisdiction.for_country(country_code) || Jurisdiction.default
  end

  # Get the projection standard for this jurisdiction
  def projection_standard
    jurisdiction&.current_projection_standard
  end

  # Get tax calculator config for this jurisdiction
  def tax_calculator_config
    jurisdiction&.tax_config || {}
  end

  # Calculate marginal tax rate based on jurisdiction
  def marginal_tax_rate(income:, province: nil)
    jurisdiction&.marginal_tax_rate(income: income, province: province) || 0
  end

  # 🇨🇦 Check if interest is tax deductible in this jurisdiction
  def interest_deductible?
    jurisdiction&.interest_deductible? || false
  end

  # 🇨🇦 Check if Smith Manoeuvre is available
  def supports_smith_manoeuvre?
    jurisdiction&.supports_smith_manoeuvre? || false
  end

  # Get currency for this jurisdiction
  def jurisdiction_currency
    jurisdiction&.currency_code || "USD"
  end

  private

    def determine_country_code
      return country if respond_to?(:country) && country.present?
      return family.country if respond_to?(:family) && family&.country.present?
      "CA" # 🇨🇦 Default to Canada
    end
end
