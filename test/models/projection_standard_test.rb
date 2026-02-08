require "test_helper"

class ProjectionStandardTest < ActiveSupport::TestCase
  setup do
    @pag_2025 = projection_standards(:pag_2025)
  end

  test "calculates blended return with default weights" do
    # 60% equity (6.28%) + 30% fixed income (4.09%) + 10% cash (2.95%)
    # = 0.03768 + 0.01227 + 0.00295 = 0.0529
    expected = (0.0628 * 0.6) + (0.0409 * 0.3) + (0.0295 * 0.1)
    assert_in_delta expected, @pag_2025.blended_return, 0.0001
  end

  test "calculates blended return with custom weights" do
    # 80% equity + 15% fixed income + 5% cash
    expected = (0.0628 * 0.8) + (0.0409 * 0.15) + (0.0295 * 0.05)
    assert_in_delta expected, @pag_2025.blended_return(equity_weight: 0.8, fixed_income_weight: 0.15, cash_weight: 0.05), 0.0001
  end

  test "calculates real return" do
    nominal = @pag_2025.blended_return
    # Real return = (1 + nominal) / (1 + inflation) - 1
    expected = ((1 + nominal) / (1 + 0.021)) - 1
    assert_in_delta expected, @pag_2025.real_return, 0.0001
  end

  test "identifies PAG compliant standard" do
    assert @pag_2025.pag_compliant?
  end

  test "returns compliance badge" do
    assert_equal "Using standard Canadian guidelines (conservative)", @pag_2025.compliance_badge
  end

  test "conservative blended return subtracts safety margin" do
    expected = @pag_2025.blended_return + ProjectionStandard::PAG_2025_DEFAULTS[:safety_margin]
    assert_in_delta expected, @pag_2025.conservative_blended_return, 0.0001
  end

  test "conservative blended return is lower than blended return" do
    assert @pag_2025.conservative_blended_return < @pag_2025.blended_return
  end

  test "validates presence of required fields" do
    standard = ProjectionStandard.new
    assert_not standard.valid?
    assert standard.errors[:name].present?
    assert standard.errors[:code].present?
    assert standard.errors[:effective_year].present?
  end

  test "validates uniqueness of code within jurisdiction" do
    duplicate = ProjectionStandard.new(
      jurisdiction: jurisdictions(:canada),
      name: "Another PAG",
      code: "PAG_2025",
      effective_year: 2026
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:code].present?
  end

  test "finds PAG 2025 standard" do
    assert_equal @pag_2025, ProjectionStandard.pag_2025
  end
end
