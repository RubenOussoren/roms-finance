# Shared z-score constants for percentile calculations across projection calculators.
# These are standard normal distribution z-scores used to compute confidence bands
# in log-normal financial projections (e.g., p10/p25/p75/p90).
module PercentileZScores
  Z_P10 = -1.28  # 10th percentile
  Z_P25 = -0.67  # 25th percentile (first quartile)
  Z_P75 =  0.67  # 75th percentile (third quartile)
  Z_P90 =  1.28  # 90th percentile
end
