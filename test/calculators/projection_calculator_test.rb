require "test_helper"

class ProjectionCalculatorTest < ActiveSupport::TestCase
  test "compound interest calculation matches formula" do
    # Test case: $1000 at 8% for 10 years, no contributions
    calc = ProjectionCalculator.new(principal: 1000, rate: 0.08, contribution: 0)
    expected = 1000 * (1.08 ** 10)  # Known formula

    # 10 years = 120 months, use monthly compounding
    # Monthly rate = 0.08/12, compound for 120 months
    monthly_rate = 0.08 / 12
    expected_monthly = 1000 * ((1 + monthly_rate) ** 120)

    assert_in_delta expected_monthly, calc.future_value_at_month(120), 1.0
  end

  test "future value with no growth returns principal plus contributions" do
    calc = ProjectionCalculator.new(principal: 10000, rate: 0, contribution: 500)

    # After 12 months: 10000 + (500 * 12) = 16000
    assert_in_delta 16000, calc.future_value_at_month(12), 0.01
  end

  test "future value at month zero returns principal" do
    calc = ProjectionCalculator.new(principal: 10000, rate: 0.08, contribution: 500)
    assert_in_delta 10000, calc.future_value_at_month(0), 0.01
  end

  test "project returns array of monthly projections" do
    calc = ProjectionCalculator.new(principal: 10000, rate: 0.06, contribution: 500)
    results = calc.project(months: 12)

    assert_equal 12, results.count
    assert results.first[:month] == 1
    assert results.last[:month] == 12
    assert results.last[:balance] > results.first[:balance]
  end

  test "years to target calculates correctly" do
    calc = ProjectionCalculator.new(principal: 10000, rate: 0.08, contribution: 500)

    years = calc.years_to_target(target: 100000)
    assert years > 0
    assert years < 20  # Should reach $100k in under 20 years
  end

  test "years to target returns 0 when already achieved" do
    calc = ProjectionCalculator.new(principal: 100000, rate: 0.08, contribution: 500)
    assert_equal 0, calc.years_to_target(target: 50000)
  end

  test "months to target returns nil when unreachable" do
    calc = ProjectionCalculator.new(principal: 1000, rate: 0, contribution: 0)
    assert_nil calc.months_to_target(target: 10000)
  end

  test "required contribution calculates correctly" do
    calc = ProjectionCalculator.new(principal: 10000, rate: 0.06, contribution: 0)

    # Calculate required contribution to reach $50000 in 5 years (60 months)
    required = calc.required_contribution(target: 50000, months: 60)

    assert required > 0
    assert required < 1000  # Should be reasonable

    # Verify: create new calc with this contribution and check target is reached
    verify_calc = ProjectionCalculator.new(principal: 10000, rate: 0.06, contribution: required)
    assert_in_delta 50000, verify_calc.future_value_at_month(60), 100
  end

  test "required contribution returns 0 when target already met" do
    calc = ProjectionCalculator.new(principal: 100000, rate: 0.06, contribution: 0)
    assert_equal 0, calc.required_contribution(target: 50000, months: 60)
  end

  test "real future value accounts for inflation" do
    calc = ProjectionCalculator.new(principal: 10000, rate: 0.08, contribution: 0)

    nominal = calc.future_value_at_month(120)
    real = calc.real_future_value_at_month(120, inflation_rate: 0.02)

    assert real < nominal  # Real value should be less due to inflation
    assert real > 0
  end

  test "project with percentiles returns distribution" do
    calc = ProjectionCalculator.new(principal: 10000, rate: 0.06, contribution: 500)

    results = calc.project_with_percentiles(months: 12, volatility: 0.18, simulations: 100)

    assert_equal 12, results.count
    final = results.last

    assert final[:p10] < final[:p50]
    assert final[:p50] < final[:p90]
    assert_not_nil final[:mean]
  end

  test "project with analytical bands returns deterministic distribution" do
    calc = ProjectionCalculator.new(principal: 10000, rate: 0.06, contribution: 500)

    results = calc.project_with_analytical_bands(months: 12, volatility: 0.18)

    assert_equal 12, results.count

    # Check structure
    first = results.first
    assert_equal 1, first[:month]
    assert_not_nil first[:date]
    assert_not_nil first[:p10]
    assert_not_nil first[:p25]
    assert_not_nil first[:p50]
    assert_not_nil first[:p75]
    assert_not_nil first[:p90]
    assert_not_nil first[:mean]

    # Check ordering (p10 < p25 < p50 < p75 < p90)
    final = results.last
    assert final[:p10] < final[:p25]
    assert final[:p25] < final[:p50]
    assert final[:p50] < final[:p75]
    assert final[:p75] < final[:p90]

    # p50 should equal mean (deterministic expected value)
    assert_equal final[:p50], final[:mean]
  end

  test "analytical bands widen over time with sqrt scaling" do
    calc = ProjectionCalculator.new(principal: 10000, rate: 0.06, contribution: 0)

    results = calc.project_with_analytical_bands(months: 24, volatility: 0.15)

    # Band width should increase over time
    month_1 = results[0]
    month_12 = results[11]
    month_24 = results[23]

    width_1 = month_1[:p90] - month_1[:p10]
    width_12 = month_12[:p90] - month_12[:p10]
    width_24 = month_24[:p90] - month_24[:p10]

    assert width_12 > width_1, "Bands should widen over time"
    assert width_24 > width_12, "Bands should continue widening"

    # Approximately sqrt(12)/sqrt(1) ≈ 3.46 ratio for width scaling
    # Allow for some tolerance due to compounding effects
    assert_in_delta 3.46, width_12 / width_1, 0.5
  end
end
