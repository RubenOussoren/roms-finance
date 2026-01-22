# 🌍 Universal: Time-to-goal milestone calculator
class MilestoneCalculator
  attr_reader :current_balance, :assumption, :currency

  def initialize(current_balance:, assumption:, currency: "CAD")
    @current_balance = current_balance.to_d
    @assumption = assumption
    @currency = currency
  end

  # Calculate time to reach a target amount
  def time_to_target(target:)
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

  # Calculate required contribution to reach target by date
  def required_contribution(target:, target_date:)
    return { achieved: true, required: 0 } if current_balance >= target

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
    Milestone::STANDARD_MILESTONES.map do |milestone|
      result = time_to_target(target: milestone[:amount])
      {
        name: milestone[:name],
        amount: milestone[:amount],
        progress: [ (current_balance / milestone[:amount] * 100).round(1), 100 ].min
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
    return { probability: 100.0, achieved: true } if current_balance >= target

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
        currency: currency
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

    def estimate_probability(target:, values:, percentiles:)
      return 100.0 if target <= values.first
      return 0.0 if target >= values.last

      # Linear interpolation between percentiles
      percentiles.each_with_index do |p, i|
        next if i == percentiles.length - 1

        if target >= values[i] && target < values[i + 1]
          # Interpolate
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
end
