# 🌍 Universal: Forecast accuracy metrics calculator
# Calculates MAPE, RMSE, and Tracking Signal
class ForecastAccuracyCalculator
  attr_reader :projections

  def initialize(projections)
    @projections = projections.to_a
  end

  # Calculate all accuracy metrics
  def calculate
    return nil if projections.empty? || valid_projections.empty?

    {
      mape: mean_absolute_percentage_error,
      rmse: root_mean_square_error,
      tracking_signal: tracking_signal,
      bias: forecast_bias,
      count: valid_projections.count,
      accuracy_score: accuracy_score
    }
  end

  # Mean Absolute Percentage Error
  # Lower is better, typically < 10% is good
  def mean_absolute_percentage_error
    return nil if valid_projections.empty?

    errors = valid_projections.map do |p|
      next nil if p.projected_balance.to_d.zero?
      ((p.actual_balance.to_d - p.projected_balance.to_d).abs / p.projected_balance.to_d.abs * 100)
    end.compact

    return nil if errors.empty?
    (errors.sum / errors.count).round(2)
  end

  # Root Mean Square Error
  # Penalizes large errors more than MAPE
  def root_mean_square_error
    return nil if valid_projections.empty?

    squared_errors = valid_projections.map do |p|
      (p.actual_balance - p.projected_balance) ** 2
    end

    Math.sqrt(squared_errors.sum / squared_errors.count).round(2)
  end

  # Tracking Signal
  # Measures cumulative forecast error relative to MAD
  # Values between -4 and 4 indicate good forecast, outside suggests bias
  def tracking_signal
    return nil if valid_projections.empty?

    cumulative_error = valid_projections.sum do |p|
      p.actual_balance - p.projected_balance
    end

    mad = mean_absolute_deviation
    return nil if mad.nil? || mad.zero?

    (cumulative_error / mad).round(2)
  end

  # Mean Absolute Deviation
  def mean_absolute_deviation
    return nil if valid_projections.empty?

    deviations = valid_projections.map do |p|
      (p.actual_balance - p.projected_balance).abs
    end

    (deviations.sum / deviations.count).round(2)
  end

  # Forecast Bias (positive = over-forecasting, negative = under-forecasting)
  def forecast_bias
    return nil if valid_projections.empty?

    errors = valid_projections.map do |p|
      p.projected_balance - p.actual_balance
    end

    (errors.sum / errors.count).round(2)
  end

  # Overall accuracy score (0-100)
  # Based on MAPE and tracking signal
  def accuracy_score
    mape = mean_absolute_percentage_error
    ts = tracking_signal&.abs

    return nil if mape.nil?

    # Score based on MAPE (0-70 points)
    mape_score = if mape <= 5
      70
    elsif mape <= 10
      60
    elsif mape <= 20
      40
    elsif mape <= 50
      20
    else
      0
    end

    # Score based on tracking signal (0-30 points)
    ts_score = if ts.nil?
      15 # Neutral if not enough data
    elsif ts <= 2
      30
    elsif ts <= 4
      20
    elsif ts <= 6
      10
    else
      0
    end

    mape_score + ts_score
  end

  # Human-readable accuracy assessment
  def accuracy_assessment
    score = accuracy_score
    return "Insufficient data" if score.nil?

    case score
    when 80..100 then "Excellent"
    when 60..79 then "Good"
    when 40..59 then "Fair"
    when 20..39 then "Poor"
    else "Very Poor"
    end
  end

  # Detect if forecast is systematically biased
  def bias_detected?
    ts = tracking_signal
    return false if ts.nil?
    ts.abs > 4
  end

  # Get recommendation based on accuracy
  def recommendation
    return "Add more actual balance data to improve accuracy measurement" if valid_projections.count < 3

    if bias_detected?
      if tracking_signal > 0
        "Forecasts consistently under-predict. Consider increasing expected return assumptions."
      else
        "Forecasts consistently over-predict. Consider decreasing expected return assumptions."
      end
    elsif accuracy_score.nil? || accuracy_score < 40
      "Consider reviewing and adjusting projection assumptions."
    else
      "Forecast accuracy is acceptable. Continue monitoring."
    end
  end

  private

    def valid_projections
      @valid_projections ||= projections.select do |p|
        p.actual_balance.present? && p.projected_balance.present?
      end
    end
end
