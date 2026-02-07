require "test_helper"

class FamilyTest < ActiveSupport::TestCase
  include SyncableInterfaceTest

  def setup
    @syncable = families(:dylan_family)
    @family = @syncable
  end

  # JurisdictionAware concern tests
  test "family has jurisdiction based on country" do
    @family.update!(country: "CA")

    jurisdiction = @family.jurisdiction

    assert_not_nil jurisdiction
    assert_equal "CA", jurisdiction.country_code
  end

  test "family gets projection standard from jurisdiction" do
    @family.update!(country: "CA")

    assert_respond_to @family, :projection_standard
    assert_respond_to @family, :tax_calculator_config
  end

  test "family can calculate marginal tax rate" do
    @family.update!(country: "CA")

    rate = @family.marginal_tax_rate(income: 100_000)

    assert_kind_of BigDecimal, rate
  end

  test "family checks if Smith Manoeuvre is supported" do
    @family.update!(country: "CA")

    assert_respond_to @family, :supports_smith_manoeuvre?
  end

  # PagCompliant concern tests
  test "family can check PAG compliance" do
    assert_respond_to @family, :pag_compliant?
    assert_respond_to @family, :compliance_badge
  end

  test "family can apply PAG defaults" do
    assumption = @family.projection_assumptions.create!(
      name: "Test Assumption",
      expected_return: 0.10,
      inflation_rate: 0.03,
      is_active: true
    )

    assert_respond_to @family, :use_pag_assumptions!
  end

  test "family compliance badge returns PAG badge when compliant" do
    # dylan_family has PAG-compliant default assumption in fixtures
    assert_equal "PAG 2025 Compliant (conservative)", @family.compliance_badge
  end

  test "family compliance badge returns custom when not PAG compliant" do
    # Create family without PAG assumptions
    family = Family.create!(name: "Test Family", country: "US")

    assert_equal "Custom assumptions", family.compliance_badge
  end

  test "family can get PAG default values" do
    assert_equal 0.0628, @family.pag_default(:equity_return)
    assert_equal 0.021, @family.pag_default(:inflation_rate)
  end

  test "family can get PAG assumption warnings" do
    # Deactivate any existing assumptions and create one with excessive return
    @family.projection_assumptions.update_all(is_active: false)
    @family.projection_assumptions.create!(
      name: "Aggressive",
      expected_return: 0.15,
      is_active: true
    )

    warnings = @family.pag_assumption_warnings

    assert warnings.any? { |w| w.include?("exceeds PAG") }
  end

  # DataQualityCheckable concern tests
  test "family reports data quality score" do
    score = @family.data_quality_score

    assert_kind_of Integer, score
    assert score >= 0 && score <= 100
  end

  test "family data quality acceptable returns true" do
    assert @family.data_quality_acceptable?
  end

  test "family has data quality issues method" do
    issues = @family.data_quality_issues

    assert_kind_of Array, issues
  end
end
