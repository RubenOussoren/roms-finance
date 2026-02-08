# 🌍 Universal: Adaptive growth projection calculator
# Pure function calculator with no side effects
class ProjectionCalculator
  include PercentileZScores

  attr_reader :principal, :rate, :contribution, :currency

  def initialize(principal:, rate:, contribution: 0, currency: "CAD")
    @principal = principal.to_d
    @rate = rate.to_d
    @contribution = contribution.to_d
    @currency = currency
  end

  # Calculate future value at a specific month
  # Uses compound interest formula: FV = P(1 + r)^n + PMT * ((1 + r)^n - 1) / r
  def future_value_at_month(month)
    return principal if month <= 0

    monthly_rate = rate / 12

    if monthly_rate.zero?
      principal + (contribution * month)
    else
      compound_factor = (1 + monthly_rate) ** month
      principal_growth = principal * compound_factor
      contribution_growth = contribution * ((compound_factor - 1) / monthly_rate)
      principal_growth + contribution_growth
    end
  end

  # Generate projection data for multiple months
  def project(months:)
    (1..months).map do |month|
      {
        month: month,
        date: Date.current + month.months,
        balance: future_value_at_month(month).round(2),
        cumulative_contribution: (contribution * month).round(2),
        growth: (future_value_at_month(month) - principal - (contribution * month)).round(2)
      }
    end
  end

  # Calculate years to reach a target amount
  def years_to_target(target:)
    return 0 if principal >= target
    months = months_to_target(target: target)
    months.nil? ? nil : (months / 12.0).round(2)
  end

  # Calculate months to reach a target amount
  def months_to_target(target:)
    return 0 if principal >= target
    return nil if rate <= 0 && contribution <= 0 # Will never reach target

    monthly_rate = rate / 12

    if monthly_rate.zero?
      # Linear growth only (contributions)
      return nil if contribution <= 0
      ((target - principal) / contribution).ceil
    else
      # Solve: target = P(1+r)^n + PMT*((1+r)^n - 1)/r
      # This requires numerical solving for n

      # Use binary search for accuracy
      low = 0
      high = 12 * 100 # 100 years max

      while high - low > 1
        mid = (low + high) / 2
        if future_value_at_month(mid) >= target
          high = mid
        else
          low = mid
        end
      end

      # If even at the 100-year cap the target isn't reached, it's unreachable
      return nil if future_value_at_month(high) < target

      high
    end
  end

  # Calculate required monthly contribution to reach target in given months
  def required_contribution(target:, months:)
    return 0 if principal >= target
    return nil if months <= 0

    monthly_rate = rate / 12

    if monthly_rate.zero?
      (target - principal) / months
    else
      compound_factor = (1 + monthly_rate) ** months
      future_principal = principal * compound_factor
      remaining = target - future_principal
      annuity_factor = (compound_factor - 1) / monthly_rate
      (remaining / annuity_factor).round(2)
    end
  end

  # Calculate real (inflation-adjusted) future value
  def real_future_value_at_month(month, inflation_rate:)
    nominal = future_value_at_month(month)
    monthly_inflation = inflation_rate.to_d / 12
    nominal / ((1 + monthly_inflation) ** month)
  end

  # Generate projection with confidence intervals (for Monte Carlo integration)
  def project_with_percentiles(months:, volatility:, simulations: 1000)
    monthly_rate = rate / 12
    monthly_vol = volatility.to_d / Math.sqrt(12)

    results = (1..months).map do |month|
      sim_values = simulations.times.map do
        simulate_path(months: month, monthly_rate: monthly_rate, monthly_vol: monthly_vol)
      end.sort

      {
        month: month,
        date: Date.current + month.months,
        p10: sim_values[(simulations * 0.10).to_i],
        p25: sim_values[(simulations * 0.25).to_i],
        p50: sim_values[(simulations * 0.50).to_i],
        p75: sim_values[(simulations * 0.75).to_i],
        p90: sim_values[(simulations * 0.90).to_i],
        mean: sim_values.sum / simulations
      }
    end

    results
  end

  # Generate projections with analytical confidence bands
  # Uses deterministic compound growth for the main line
  # and volatility-based bands that widen over time (√t scaling)
  def project_with_analytical_bands(months:, volatility:)
    monthly_vol = volatility.to_d / Math.sqrt(12)

    (1..months).map do |month|
      base_value = future_value_at_month(month)
      cumulative_vol = monthly_vol * Math.sqrt(month)

      percentiles = calculate_percentiles_for_value(base_value, cumulative_vol)

      {
        month: month,
        date: Date.current + month.months,
        p10: percentiles[:p10],
        p25: percentiles[:p25],
        p50: percentiles[:p50],
        p75: percentiles[:p75],
        p90: percentiles[:p90],
        mean: base_value.round(2)
      }
    end
  end

  private

    def simulate_path(months:, monthly_rate:, monthly_vol:)
      balance = principal

      months.times do
        random_return = monthly_rate + (monthly_vol * gaussian_random)
        balance = balance * (1 + random_return) + contribution
      end

      balance.round(2)
    end

    def gaussian_random
      # Box-Muller transform for normal distribution
      # Guard: clamp u1 to avoid log(0) = -Infinity
      u1 = [ rand, Float::EPSILON ].max
      u2 = rand
      Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math::PI * u2)
    end
end
