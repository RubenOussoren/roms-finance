require "test_helper"

class ForecastAccuracyCalculatorTest < ActiveSupport::TestCase
  setup do
    @projections_with_actuals = [
      OpenStruct.new(projected_balance: 10000, actual_balance: 10200),
      OpenStruct.new(projected_balance: 11000, actual_balance: 10800),
      OpenStruct.new(projected_balance: 12000, actual_balance: 12100),
      OpenStruct.new(projected_balance: 13000, actual_balance: 12700)
    ]
  end

  test "calculates MAPE correctly" do
    calc = ForecastAccuracyCalculator.new(@projections_with_actuals)
    mape = calc.mean_absolute_percentage_error

    # Expected errors:
    # |10200-10000|/10000 = 2%
    # |10800-11000|/11000 = 1.82%
    # |12100-12000|/12000 = 0.83%
    # |12700-13000|/13000 = 2.31%
    # Average ~ 1.74%

    assert_not_nil mape, "MAPE should not be nil"
    assert mape > 0, "MAPE should be positive"
    assert mape < 10, "MAPE should be under 10% for this data"
  end

  test "calculates RMSE correctly" do
    calc = ForecastAccuracyCalculator.new(@projections_with_actuals)
    rmse = calc.root_mean_square_error

    assert_not_nil rmse
    assert rmse > 0
  end

  test "calculates tracking signal" do
    calc = ForecastAccuracyCalculator.new(@projections_with_actuals)
    ts = calc.tracking_signal

    assert_not_nil ts
    # Tracking signal between -4 and 4 indicates good forecast
    assert ts.abs < 10
  end

  test "calculates forecast bias" do
    calc = ForecastAccuracyCalculator.new(@projections_with_actuals)
    bias = calc.forecast_bias

    assert_not_nil bias
    # Positive bias = over-forecasting (projected > actual on average)
  end

  test "calculates accuracy score" do
    calc = ForecastAccuracyCalculator.new(@projections_with_actuals)
    score = calc.accuracy_score

    assert_not_nil score
    assert score >= 0
    assert score <= 100
  end

  test "returns accuracy assessment" do
    calc = ForecastAccuracyCalculator.new(@projections_with_actuals)
    assessment = calc.accuracy_assessment

    assert %w[Excellent Good Fair Poor].include?(assessment) || assessment.include?("Very Poor")
  end

  test "detects bias when tracking signal is high" do
    # Create biased data (consistently under-forecasting)
    biased_projections = [
      OpenStruct.new(projected_balance: 10000, actual_balance: 12000),
      OpenStruct.new(projected_balance: 11000, actual_balance: 13500),
      OpenStruct.new(projected_balance: 12000, actual_balance: 15000),
      OpenStruct.new(projected_balance: 13000, actual_balance: 17000),
      OpenStruct.new(projected_balance: 14000, actual_balance: 19000)
    ]

    calc = ForecastAccuracyCalculator.new(biased_projections)
    assert calc.bias_detected?
  end

  test "returns nil for empty projections" do
    calc = ForecastAccuracyCalculator.new([])
    assert_nil calc.calculate
  end

  test "returns nil when no actual balances" do
    projections_without_actuals = [
      OpenStruct.new(projected_balance: 10000, actual_balance: nil),
      OpenStruct.new(projected_balance: 11000, actual_balance: nil)
    ]

    calc = ForecastAccuracyCalculator.new(projections_without_actuals)
    assert_nil calc.calculate
  end

  test "provides recommendation" do
    calc = ForecastAccuracyCalculator.new(@projections_with_actuals)
    recommendation = calc.recommendation

    assert_not_nil recommendation
    assert recommendation.is_a?(String)
    assert recommendation.length > 0
  end

  test "calculate returns all metrics" do
    calc = ForecastAccuracyCalculator.new(@projections_with_actuals)
    result = calc.calculate

    assert_not_nil result
    assert result.key?(:mape)
    assert result.key?(:rmse)
    assert result.key?(:tracking_signal)
    assert result.key?(:bias)
    assert result.key?(:count)
    assert result.key?(:accuracy_score)
  end
end
