# Universal: Time-to-goal milestone calculator
# Supports both growth milestones (reach target) and debt milestones (reduce to target)
class MilestoneCalculator
  attr_reader :current_balance, :assumption, :currency, :target_type

  def initialize(current_balance:, assumption:, currency: "CAD", target_type: "reach")
    @current_balance = current_balance.to_d
    @assumption = assumption
    @currency = currency
    @target_type = target_type
  end

  def reduction_milestone?
    target_type == "reduce_to"
  end

  # Calculate time to reach a target amount
  def time_to_target(target:)
    if reduction_milestone?
      time_to_reduce_to(target)
    else
      time_to_grow_to(target)
    end
  end

  # Calculate required contribution to reach target by date
  def required_contribution(target:, target_date:)
    if reduction_milestone?
      return { achieved: true, required: 0 } if current_balance.abs <= target
    else
      return { achieved: true, required: 0 } if current_balance >= target
    end

    # Months approximated as 30 days. Maximum error: ~3% on timing estimates
    # (a 30-month estimate could be off by ~1 month vs calendar months).
    # Using 30.44 (365.25/12) would be more precise but adds negligible value
    # for a planning tool.
    months = ((target_date - Date.current) / 30).to_i
    return { achievable: false, reason: "Target date is in the past" } if months <= 0

    calculator = ProjectionCalculator.new(
      principal: current_balance,
      rate: assumption.effective_return,
      contribution: 0,
      currency: currency
    )

    required = calculator.required_contribution(target: target, months: months)

    {
      achieved: false,
      achievable: required.present? && required >= 0,
      required_monthly: required&.round(2),
      required_annual: required ? (required * 12).round(2) : nil,
      months: months,
      target_date: target_date
    }
  end

  # Analyze all standard milestones
  def analyze_standard_milestones
    milestones = reduction_milestone? ? debt_milestones : Milestone::STANDARD_MILESTONES

    milestones.map do |milestone|
      target = milestone[:amount] || milestone[:target]
      result = time_to_target(target: target)
      {
        name: milestone[:name],
        amount: target,
        progress: calculate_milestone_progress(target)
      }.merge(result)
    end
  end

  # Get next achievable milestone
  def next_achievable_milestone
    analyze_standard_milestones.find do |m|
      !m[:achieved] && m[:achievable]
    end
  end

  # Calculate milestone probability using Monte Carlo
  def milestone_probability(target:, months:, simulations: 1000)
    if reduction_milestone?
      return { probability: 100.0, achieved: true } if current_balance.abs <= target
    else
      return { probability: 100.0, achieved: true } if current_balance >= target
    end

    calculator = ProjectionCalculator.new(
      principal: current_balance,
      rate: assumption.effective_return,
      contribution: assumption.monthly_contribution,
      currency: currency
    )

    results = calculator.project_with_percentiles(
      months: months,
      volatility: assumption.effective_volatility,
      simulations: simulations
    )

    final_result = results.last
    return nil if final_result.nil?

    # Estimate probability based on where target falls in distribution
    values = [ final_result[:p10], final_result[:p25], final_result[:p50], final_result[:p75], final_result[:p90] ]
    percentiles = [ 10, 25, 50, 75, 90 ]

    probability = estimate_probability(target: target, values: values, percentiles: percentiles)

    {
      probability: probability,
      achieved: false,
      p10: final_result[:p10],
      p50: final_result[:p50],
      p90: final_result[:p90]
    }
  end

  # Compare scenarios: What if contribution changes?
  def contribution_sensitivity(target:)
    base_contribution = assumption.monthly_contribution
    scenarios = [ 0, 0.5, 1.0, 1.5, 2.0 ].map do |multiplier|
      test_contribution = base_contribution * multiplier

      test_assumption = OpenStruct.new(
        effective_return: assumption.effective_return,
        monthly_contribution: test_contribution,
        effective_volatility: assumption.effective_volatility
      )

      calc = MilestoneCalculator.new(
        current_balance: current_balance,
        assumption: test_assumption,
        currency: currency,
        target_type: target_type
      )

      result = calc.time_to_target(target: target)
      {
        contribution: test_contribution,
        multiplier: multiplier,
        label: "#{(multiplier * 100).to_i}%"
      }.merge(result)
    end

    scenarios
  end

  private

    def time_to_grow_to(target)
      return { achieved: true, months: 0, years: 0 } if current_balance >= target

      calculator = ProjectionCalculator.new(
        principal: current_balance,
        rate: assumption.effective_return,
        contribution: assumption.monthly_contribution,
        currency: currency
      )

      months = calculator.months_to_target(target: target)
      return { achievable: false } if months.nil?

      {
        achieved: false,
        achievable: true,
        months: months,
        years: (months / 12.0).round(1),
        projected_date: Date.current + months.months
      }
    end

    def time_to_reduce_to(target)
      current_abs = current_balance.abs
      return { achieved: true, months: 0, years: 0 } if current_abs <= target

      # For debt payoff, we need to calculate how long to pay down the balance
      # Using the assumption's monthly_contribution as the payment amount
      payment = assumption.monthly_contribution.abs
      return { achievable: false, reason: "No payment configured" } if payment.zero?

      # Simple debt payoff calculation (with interest)
      interest_rate = assumption.effective_return.abs  # Interest rate for debt
      monthly_rate = interest_rate / 12.0

      remaining = current_abs - target
      return { achievable: false, reason: "Cannot pay off with current payment" } if payment <= (remaining * monthly_rate)

      if monthly_rate.zero?
        # No interest case
        months = (remaining / payment).ceil
      else
        # With interest: n = -log(1 - (r * P) / M) / log(1 + r)
        # where P = principal, M = monthly payment, r = monthly rate
        numerator = Math.log(1 - (monthly_rate * remaining / payment))
        denominator = Math.log(1 + monthly_rate)
        months = (-numerator / denominator).ceil
      end

      return { achievable: false } if months.negative? || months > 1200  # Cap at 100 years

      {
        achieved: false,
        achievable: true,
        months: months,
        years: (months / 12.0).round(1),
        projected_date: Date.current + months.months
      }
    rescue Math::DomainError
      { achievable: false, reason: "Payment too low to overcome interest" }
    end

    def calculate_milestone_progress(target)
      if reduction_milestone?
        # For debt: progress = (starting - current) / (starting - target) * 100
        # Simplified: just show how much of target we've reached
        return 100.0 if current_balance.abs <= target
        remaining = current_balance.abs
        [ ((remaining - target) / remaining * 100), 100 ].min.round(1).clamp(0, 100)
      else
        [ (current_balance / target * 100).round(1), 100 ].min
      end
    end

    def debt_milestones
      # Generate milestones based on current balance
      Milestone::DEBT_MILESTONES.map do |m|
        target = (current_balance.abs * (1 - m[:percentage])).round(2)
        { name: m[:name], target: target }
      end
    end

    def estimate_probability(target:, values:, percentiles:)
      # Fit log-normal parameters from p10/p50/p90 for smooth extrapolation
      # beyond the known percentile range (instead of hard-clamping to 0% or 100%)
      p10, p50, p90 = values[0], values[2], values[4]

      if p10 > 0 && p50 > 0 && p90 > 0 && target > 0
        mu = Math.log(p50)
        sigma = (Math.log(p90) - Math.log(p10)) / (2 * 1.28)

        if sigma > 0
          z = (Math.log(target) - mu) / sigma
          probability = (1 - normal_cdf(z)) * 100
          return probability.clamp(0.5, 99.5).round(1)
        end
      end

      # Fallback: linear interpolation between known percentiles
      if target <= values.first
        return 99.5 if values.first <= 0
        return 90.0
      end
      return 10.0 if target >= values.last

      percentiles.each_with_index do |p, i|
        next if i == percentiles.length - 1

        if target >= values[i] && target < values[i + 1]
          range = values[i + 1] - values[i]
          position = target - values[i]
          fraction = range.zero? ? 0 : position / range
          lower_prob = 100 - percentiles[i]
          upper_prob = 100 - percentiles[i + 1]
          return (lower_prob - (fraction * (lower_prob - upper_prob))).round(1)
        end
      end

      50.0 # Default if interpolation fails
    end

    def normal_cdf(z)
      0.5 * (1 + Math.erf(z / Math.sqrt(2)))
    end
end
