require "test_helper"

class ProjectionAssumptionTest < ActiveSupport::TestCase
  setup do
    @assumption = projection_assumptions(:default_assumption)
    @custom = projection_assumptions(:custom_assumption)
  end

  test "returns effective return from PAG standard with safety margin when using defaults" do
    expected = @assumption.projection_standard.conservative_blended_return
    assert_in_delta expected, @assumption.effective_return, 0.0001
  end

  test "PAG effective return is lower than raw blended return" do
    assert @assumption.effective_return < @assumption.projection_standard.blended_return
  end

  test "returns expected return when not using PAG defaults" do
    assert_equal 0.10, @custom.effective_return.to_f
  end

  test "calculates real return" do
    # Real return = (1 + nominal) / (1 + inflation) - 1
    nominal = @assumption.effective_return
    inflation = @assumption.effective_inflation
    expected = ((1 + nominal) / (1 + inflation)) - 1

    assert_in_delta expected, @assumption.real_return, 0.0001
  end

  test "identifies PAG compliant assumption" do
    assert @assumption.pag_compliant?
    assert_not @custom.pag_compliant?
  end

  test "returns compliance badge" do
    assert_equal "Using standard Canadian guidelines (conservative)", @assumption.compliance_badge
    assert_equal "Using custom assumptions", @custom.compliance_badge
  end

  test "applies PAG defaults" do
    @custom.update!(projection_standard: projection_standards(:pag_2025))
    @custom.apply_pag_defaults!

    assert @custom.use_pag_defaults
    assert_in_delta projection_standards(:pag_2025).blended_return, @custom.expected_return, 0.0001
  end

  test "creates default assumption for family" do
    family = families(:empty)
    assumption = ProjectionAssumption.default_for(family)

    assert_not_nil assumption
    assert assumption.is_active
    assert_equal family, assumption.family
  end

  test "validates presence of name" do
    assumption = ProjectionAssumption.new
    assert_not assumption.valid?
    assert assumption.errors[:name].present?
  end
end
