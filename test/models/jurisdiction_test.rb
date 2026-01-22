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
end
