require "test_helper"

class PercentileZScoresTest < ActiveSupport::TestCase
  # Test class that includes the module
  class TestCalculator
    include PercentileZScores
  end

  setup do
    @calc = TestCalculator.new
  end

  test "positive value percentiles are correctly ordered" do
    result = @calc.calculate_percentiles_for_value(10_000, 0.15)

    assert result[:p10] < result[:p25]
    assert result[:p25] < result[:p50]
    assert result[:p50] < result[:p75]
    assert result[:p75] < result[:p90]
  end

  test "negative value percentiles are correctly ordered" do
    result = @calc.calculate_percentiles_for_value(-10_000, 0.15)

    assert result[:p10] < result[:p25]
    assert result[:p25] < result[:p50]
    assert result[:p50] < result[:p75]
    assert result[:p75] < result[:p90]
  end

  test "zero value returns all zeros" do
    result = @calc.calculate_percentiles_for_value(0, 0.15)

    assert_equal 0.0, result[:p10]
    assert_equal 0.0, result[:p25]
    assert_equal 0.0, result[:p50]
    assert_equal 0.0, result[:p75]
    assert_equal 0.0, result[:p90]
  end

  test "p50 applies drift correction for positive values" do
    value = 100_000
    sigma = 0.20
    expected_p50 = (value * Math.exp(-sigma**2 / 2.0)).to_f.round(2)

    result = @calc.calculate_percentiles_for_value(value, sigma)

    assert_equal expected_p50, result[:p50]
    assert result[:p50] < value, "median should be less than mean for non-zero volatility"
  end

  test "p50 applies drift correction for negative values" do
    value = -100_000
    sigma = 0.20
    expected_p50 = -(value.abs * Math.exp(-sigma**2 / 2.0)).to_f.round(2)

    result = @calc.calculate_percentiles_for_value(value, sigma)

    assert_equal expected_p50, result[:p50]
  end

  test "zero sigma returns all values equal to input" do
    result = @calc.calculate_percentiles_for_value(50_000, 0)

    assert_equal 50_000.0, result[:p10]
    assert_equal 50_000.0, result[:p50]
    assert_equal 50_000.0, result[:p90]
  end

  test "higher sigma produces wider bands" do
    narrow = @calc.calculate_percentiles_for_value(10_000, 0.10)
    wide = @calc.calculate_percentiles_for_value(10_000, 0.50)

    narrow_width = narrow[:p90] - narrow[:p10]
    wide_width = wide[:p90] - wide[:p10]

    assert wide_width > narrow_width
  end
end
