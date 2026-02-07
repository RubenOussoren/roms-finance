require "test_helper"

class JurisdictionTest < ActiveSupport::TestCase
  test "canada is default jurisdiction" do
    assert_equal "CA", Jurisdiction.default.country_code
  end

  test "finds jurisdiction by country code" do
    canada = Jurisdiction.for_country("CA")
    assert_not_nil canada
    assert_equal "Canada", canada.name
  end

  test "canada supports smith manoeuvre" do
    canada = jurisdictions(:canada)
    assert canada.supports_smith_manoeuvre?
  end

  test "canada has interest deductible" do
    canada = jurisdictions(:canada)
    assert canada.interest_deductible?
  end

  test "calculates marginal tax rate from brackets" do
    canada = jurisdictions(:canada)

    # Below first bracket
    assert_equal 0.15, canada.marginal_tax_rate(income: 50000)

    # In second bracket
    assert_equal 0.205, canada.marginal_tax_rate(income: 80000)
  end

  test "returns current projection standard" do
    canada = jurisdictions(:canada)
    standard = canada.current_projection_standard

    assert_not_nil standard
    assert_equal "PAG_2025", standard.code
  end

  test "validates presence of required fields" do
    jurisdiction = Jurisdiction.new
    assert_not jurisdiction.valid?
    assert jurisdiction.errors[:country_code].present?
    assert jurisdiction.errors[:name].present?
    assert jurisdiction.errors[:currency_code].present?
  end

  test "validates uniqueness of country code" do
    duplicate = Jurisdiction.new(
      country_code: "CA",
      name: "Another Canada",
      currency_code: "CAD"
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:country_code].present?
  end

  # --- Federal rate tests ---

  test "federal_marginal_rate at 50K returns 15%" do
    canada = jurisdictions(:canada)
    assert_equal BigDecimal("0.15"), canada.federal_marginal_rate(income: 50_000)
  end

  test "federal_marginal_rate at 80K returns 20.5%" do
    canada = jurisdictions(:canada)
    assert_equal BigDecimal("0.205"), canada.federal_marginal_rate(income: 80_000)
  end

  # --- Provincial rate tests ---

  test "provincial_marginal_rate Ontario at 80K returns 9.15%" do
    canada = jurisdictions(:canada)
    assert_equal BigDecimal("0.0915"), canada.provincial_marginal_rate(income: 80_000, province: "ON")
  end

  test "provincial_marginal_rate returns 0 for nil province" do
    canada = jurisdictions(:canada)
    assert_equal BigDecimal("0"), canada.provincial_marginal_rate(income: 80_000, province: nil)
  end

  test "provincial_marginal_rate returns 0 for unknown province" do
    canada = jurisdictions(:canada)
    assert_equal BigDecimal("0"), canada.provincial_marginal_rate(income: 80_000, province: "XX")
  end

  # --- Combined rate tests ---

  test "combined_marginal_rate at 100K Ontario equals 29.65%" do
    canada = jurisdictions(:canada)
    # Federal: 20.5% (100K > 55867), Ontario: 9.15% (100K > 51446, < 102894)
    assert_in_delta 0.2965, canada.combined_marginal_rate(income: 100_000, province: "ON").to_f, 0.0001
  end

  test "combined_marginal_rate without province equals federal only" do
    canada = jurisdictions(:canada)
    federal = canada.federal_marginal_rate(income: 100_000)
    combined = canada.combined_marginal_rate(income: 100_000, province: nil)
    assert_equal federal, combined
  end

  # --- Backward compatibility ---

  test "marginal_tax_rate without province returns federal only" do
    canada = jurisdictions(:canada)
    assert_equal canada.federal_marginal_rate(income: 80_000), canada.marginal_tax_rate(income: 80_000)
  end

  test "marginal_tax_rate with province returns combined" do
    canada = jurisdictions(:canada)
    assert_equal canada.combined_marginal_rate(income: 80_000, province: "ON"),
                 canada.marginal_tax_rate(income: 80_000, province: "ON")
  end

  # --- Available provinces ---

  test "available_provinces returns province codes from tax_config" do
    canada = jurisdictions(:canada)
    assert_includes canada.available_provinces, "ON"
  end

  test "available_provinces returns empty for jurisdiction without provincial brackets" do
    us = jurisdictions(:united_states)
    assert_equal [], us.available_provinces
  end

  # --- Reference table verification (Ontario) ---

  test "Ontario combined rates match reference table" do
    canada = jurisdictions(:canada)
    # $50K: federal 15% + ON 5.05% = 20.05%
    assert_in_delta 0.2005, canada.combined_marginal_rate(income: 50_000, province: "ON").to_f, 0.0001
    # $75K: federal 20.5% + ON 9.15% = 29.65%
    assert_in_delta 0.2965, canada.combined_marginal_rate(income: 75_000, province: "ON").to_f, 0.0001
    # $100K: federal 20.5% + ON 9.15% = 29.65%
    assert_in_delta 0.2965, canada.combined_marginal_rate(income: 100_000, province: "ON").to_f, 0.0001
  end
end
