# Shared z-score constants and percentile calculation for projection calculators.
# These are standard normal distribution z-scores used to compute confidence bands
# in log-normal financial projections (e.g., p10/p25/p75/p90).
module PercentileZScores
  Z_P10 = -1.28  # 10th percentile
  Z_P25 = -0.67  # 25th percentile (first quartile)
  Z_P75 =  0.67  # 75th percentile (third quartile)
  Z_P90 =  1.28  # 90th percentile

  # Calculate percentiles handling both positive and negative values
  # For positive values: p10 (pessimistic) < p50 < p90 (optimistic)
  # For negative values (debts): p10 (more debt) < p50 < p90 (less debt)
  # p50 uses drift correction: median = value * exp(-sigma²/2) for log-normal
  def calculate_percentiles_for_value(value, sigma)
    drift_correction = Math.exp(-sigma**2 / 2.0)

    if value >= 0
      {
        p10: (value * Math.exp(Z_P10 * sigma)).to_f.round(2),
        p25: (value * Math.exp(Z_P25 * sigma)).to_f.round(2),
        p50: (value * drift_correction).to_f.round(2),
        p75: (value * Math.exp(Z_P75 * sigma)).to_f.round(2),
        p90: (value * Math.exp(Z_P90 * sigma)).to_f.round(2)
      }
    else
      abs_value = value.abs
      {
        p10: -(abs_value * Math.exp(-Z_P10 * sigma)).to_f.round(2),
        p25: -(abs_value * Math.exp(-Z_P25 * sigma)).to_f.round(2),
        p50: -(abs_value * drift_correction).to_f.round(2),
        p75: -(abs_value * Math.exp(-Z_P75 * sigma)).to_f.round(2),
        p90: -(abs_value * Math.exp(-Z_P90 * sigma)).to_f.round(2)
      }
    end
  end
end
