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

  # Edge case tests for negative values (debt projections)
  test "project with analytical bands handles negative principal (debt)" do
    # Simulate a debt of $50,000
    calc = ProjectionCalculator.new(principal: -50000, rate: 0.05, contribution: -500)

    results = calc.project_with_analytical_bands(months: 12, volatility: 0.10)

    assert_equal 12, results.count
    final = results.last

    # For negative values (debt):
    # p10 should be the most negative (pessimistic - more debt)
    # p90 should be the least negative (optimistic - less debt)
    assert final[:p10] < final[:p50], "p10 (pessimistic) should be more negative than p50"
    assert final[:p50] < final[:p90], "p50 should be more negative than p90 (optimistic)"

    # All values should be negative since we're projecting debt
    assert final[:p10] < 0, "p10 should be negative"
    assert final[:p50] < 0, "p50 should be negative"
    assert final[:p90] < 0, "p90 should be negative"
  end

  test "percentile ordering is correct for positive values" do
    calc = ProjectionCalculator.new(principal: 10000, rate: 0.08, contribution: 500)

    results = calc.project_with_analytical_bands(months: 60, volatility: 0.20)

    results.each do |month_data|
      assert month_data[:p10] < month_data[:p25], "p10 should be < p25 for month #{month_data[:month]}"
      assert month_data[:p25] < month_data[:p50], "p25 should be < p50 for month #{month_data[:month]}"
      assert month_data[:p50] < month_data[:p75], "p50 should be < p75 for month #{month_data[:month]}"
      assert month_data[:p75] < month_data[:p90], "p75 should be < p90 for month #{month_data[:month]}"
    end
  end

  test "percentile ordering is correct for negative values" do
    calc = ProjectionCalculator.new(principal: -100000, rate: 0.06, contribution: -1000)

    results = calc.project_with_analytical_bands(months: 24, volatility: 0.15)

    results.each do |month_data|
      assert month_data[:p10] < month_data[:p25], "p10 should be < p25 for month #{month_data[:month]}"
      assert month_data[:p25] < month_data[:p50], "p25 should be < p50 for month #{month_data[:month]}"
      assert month_data[:p50] < month_data[:p75], "p50 should be < p75 for month #{month_data[:month]}"
      assert month_data[:p75] < month_data[:p90], "p75 should be < p90 for month #{month_data[:month]}"
    end
  end

  test "high volatility edge case produces wider bands" do
    calc_low_vol = ProjectionCalculator.new(principal: 10000, rate: 0.06, contribution: 0)
    calc_high_vol = ProjectionCalculator.new(principal: 10000, rate: 0.06, contribution: 0)

    low_vol_results = calc_low_vol.project_with_analytical_bands(months: 12, volatility: 0.10)
    high_vol_results = calc_high_vol.project_with_analytical_bands(months: 12, volatility: 0.50)

    low_vol_width = low_vol_results.last[:p90] - low_vol_results.last[:p10]
    high_vol_width = high_vol_results.last[:p90] - high_vol_results.last[:p10]

    assert high_vol_width > low_vol_width, "Higher volatility should produce wider bands"
    # High volatility (50%) should produce roughly 5x wider bands than low volatility (10%)
    assert_in_delta 5.0, high_vol_width / low_vol_width, 1.0
  end

  test "zero principal with contributions produces positive growth" do
    calc = ProjectionCalculator.new(principal: 0, rate: 0.06, contribution: 500)

    results = calc.project_with_analytical_bands(months: 12, volatility: 0.15)
    final = results.last

    assert final[:p50] > 0, "Should grow from contributions"
    assert_in_delta 500 * 12, final[:p50], 500  # Roughly 12 months of contributions plus some growth
  end

  test "calculate_percentiles_for_value handles edge cases" do
    calc = ProjectionCalculator.new(principal: 1000, rate: 0.06, contribution: 0)

    # Test positive value
    positive_percentiles = calc.calculate_percentiles_for_value(1000, 0.15)
    assert positive_percentiles[:p10] < positive_percentiles[:p90]
    assert_equal 1000.0, positive_percentiles[:p50]

    # Test negative value (debt)
    negative_percentiles = calc.calculate_percentiles_for_value(-1000, 0.15)
    assert negative_percentiles[:p10] < negative_percentiles[:p90]
    assert_equal(-1000.0, negative_percentiles[:p50])

    # Test zero value
    zero_percentiles = calc.calculate_percentiles_for_value(0, 0.15)
    assert_equal 0.0, zero_percentiles[:p10]
    assert_equal 0.0, zero_percentiles[:p50]
    assert_equal 0.0, zero_percentiles[:p90]
  end
end
