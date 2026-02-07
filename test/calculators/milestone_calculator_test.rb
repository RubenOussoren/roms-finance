require "test_helper"

class MilestoneCalculatorTest < ActiveSupport::TestCase
  setup do
    @assumption = OpenStruct.new(
      effective_return: 0.06,
      monthly_contribution: 500,
      effective_volatility: 0.18
    )
  end

  test "time to target returns achieved when already met" do
    calc = MilestoneCalculator.new(
      current_balance: 150000,
      assumption: @assumption
    )

    result = calc.time_to_target(target: 100000)

    assert result[:achieved]
    assert_equal 0, result[:months]
  end

  test "time to target calculates months and years" do
    calc = MilestoneCalculator.new(
      current_balance: 10000,
      assumption: @assumption
    )

    result = calc.time_to_target(target: 100000)

    assert_not result[:achieved]
    assert result[:achievable]
    assert result[:months] > 0
    assert result[:years] > 0
    assert result[:projected_date].present?
  end

  test "time to target returns not achievable for unreachable target" do
    low_growth = OpenStruct.new(
      effective_return: 0.01,
      monthly_contribution: 0,
      effective_volatility: 0
    )

    calc = MilestoneCalculator.new(
      current_balance: 500,
      assumption: low_growth
    )

    result = calc.time_to_target(target: 10_000_000)

    assert_not result[:achieved]
    assert_not result[:achievable]
  end

  test "required contribution calculates monthly amount" do
    calc = MilestoneCalculator.new(
      current_balance: 10000,
      assumption: @assumption
    )

    result = calc.required_contribution(
      target: 50000,
      target_date: Date.current + 5.years
    )

    assert_not result[:achieved]
    assert result[:achievable]
    assert result[:required_monthly] > 0
    assert result[:required_annual] > 0
  end

  test "required contribution returns achieved when target met" do
    calc = MilestoneCalculator.new(
      current_balance: 100000,
      assumption: @assumption
    )

    result = calc.required_contribution(
      target: 50000,
      target_date: Date.current + 5.years
    )

    assert result[:achieved]
    assert_equal 0, result[:required]
  end

  test "required contribution fails for past date" do
    calc = MilestoneCalculator.new(
      current_balance: 10000,
      assumption: @assumption
    )

    result = calc.required_contribution(
      target: 50000,
      target_date: Date.current - 1.year
    )

    assert_not result[:achievable]
    assert result[:reason].present?
  end

  test "analyzes standard milestones" do
    calc = MilestoneCalculator.new(
      current_balance: 10000,
      assumption: @assumption
    )

    milestones = calc.analyze_standard_milestones

    assert milestones.count == Milestone::STANDARD_MILESTONES.count
    assert milestones.first[:progress] > 0

    # First milestone ($10K) should be achieved
    first = milestones.find { |m| m[:amount] == 10_000 }
    assert first[:achieved]
  end

  test "next achievable milestone returns first unachieved" do
    calc = MilestoneCalculator.new(
      current_balance: 10000,
      assumption: @assumption
    )

    next_milestone = calc.next_achievable_milestone

    assert_not_nil next_milestone
    assert_not next_milestone[:achieved]
    assert next_milestone[:achievable]
  end

  test "milestone probability returns probability estimate" do
    calc = MilestoneCalculator.new(
      current_balance: 10000,
      assumption: @assumption
    )

    result = calc.milestone_probability(
      target: 50000,
      months: 60,
      simulations: 100
    )

    assert_not_nil result
    assert result[:probability] >= 0
    assert result[:probability] <= 100
    assert result[:p10].present?
    assert result[:p50].present?
    assert result[:p90].present?
  end

  test "contribution sensitivity returns multiple scenarios" do
    calc = MilestoneCalculator.new(
      current_balance: 10000,
      assumption: @assumption
    )

    scenarios = calc.contribution_sensitivity(target: 100000)

    assert_equal 5, scenarios.count
    assert scenarios.any? { |s| s[:multiplier] == 0 }
    assert scenarios.any? { |s| s[:multiplier] == 2.0 }

    # Higher contributions should reach target faster
    zero_contrib = scenarios.find { |s| s[:multiplier] == 0 }
    double_contrib = scenarios.find { |s| s[:multiplier] == 2.0 }

    if zero_contrib[:achievable] && double_contrib[:achievable]
      assert double_contrib[:months] < zero_contrib[:months]
    end
  end

  # ============================================
  # Debt Milestone Calculator Tests
  # ============================================

  test "debt time to target returns achieved when already paid off" do
    debt_assumption = OpenStruct.new(
      effective_return: 0.05,  # 5% interest
      monthly_contribution: 1000,  # $1000/month payment
      effective_volatility: 0
    )

    calc = MilestoneCalculator.new(
      current_balance: 5000,
      assumption: debt_assumption,
      target_type: "reduce_to"
    )

    result = calc.time_to_target(target: 10000)  # Target higher than current = already achieved

    assert result[:achieved]
    assert_equal 0, result[:months]
  end

  test "debt time to target calculates payoff timeline" do
    debt_assumption = OpenStruct.new(
      effective_return: 0.05,  # 5% interest
      monthly_contribution: 500,  # $500/month payment
      effective_volatility: 0
    )

    calc = MilestoneCalculator.new(
      current_balance: 10000,  # $10,000 debt
      assumption: debt_assumption,
      target_type: "reduce_to"
    )

    result = calc.time_to_target(target: 0)  # Pay off completely

    assert_not result[:achieved]
    assert result[:achievable]
    assert result[:months] > 0
    assert result[:years] > 0
    assert result[:projected_date].present?
  end

  test "debt time to target fails without payment" do
    no_payment_assumption = OpenStruct.new(
      effective_return: 0.05,
      monthly_contribution: 0,
      effective_volatility: 0
    )

    calc = MilestoneCalculator.new(
      current_balance: 10000,
      assumption: no_payment_assumption,
      target_type: "reduce_to"
    )

    result = calc.time_to_target(target: 0)

    assert_not result[:achievable]
  end

  test "reduction_milestone? returns true for reduce_to type" do
    calc = MilestoneCalculator.new(
      current_balance: 10000,
      assumption: @assumption,
      target_type: "reduce_to"
    )

    assert calc.reduction_milestone?
  end

  test "reduction_milestone? returns false for reach type" do
    calc = MilestoneCalculator.new(
      current_balance: 10000,
      assumption: @assumption,
      target_type: "reach"
    )

    assert_not calc.reduction_milestone?
  end

  # ============================================
  # Smooth Probability Extrapolation Tests
  # ============================================

  test "probability for target below p10 is high but less than 100" do
    calc = MilestoneCalculator.new(
      current_balance: 10000,
      assumption: @assumption
    )

    values = [ 80_000, 90_000, 100_000, 110_000, 120_000 ]
    percentiles = [ 10, 25, 50, 75, 90 ]

    # Target well below p10 — should be high probability but not 100%
    prob = calc.send(:estimate_probability, target: 50_000, values: values, percentiles: percentiles)
    assert prob > 90, "Target below p10 should have probability > 90%, got #{prob}"
    assert prob < 100, "Target below p10 should have probability < 100%, got #{prob}"
  end

  test "probability for target above p90 is low but greater than 0" do
    calc = MilestoneCalculator.new(
      current_balance: 10000,
      assumption: @assumption
    )

    values = [ 80_000, 90_000, 100_000, 110_000, 120_000 ]
    percentiles = [ 10, 25, 50, 75, 90 ]

    # Target well above p90 — should be low probability but not 0%
    prob = calc.send(:estimate_probability, target: 150_000, values: values, percentiles: percentiles)
    assert prob < 10, "Target above p90 should have probability < 10%, got #{prob}"
    assert prob > 0, "Target above p90 should have probability > 0%, got #{prob}"
  end

  test "probability at p50 is approximately 50 percent" do
    calc = MilestoneCalculator.new(
      current_balance: 10000,
      assumption: @assumption
    )

    values = [ 80_000, 90_000, 100_000, 110_000, 120_000 ]
    percentiles = [ 10, 25, 50, 75, 90 ]

    prob = calc.send(:estimate_probability, target: 100_000, values: values, percentiles: percentiles)
    assert_in_delta 50.0, prob, 5.0, "Target at p50 should be ~50%, got #{prob}"
  end

  test "probability is clamped to 0.5-99.5 to avoid false certainty" do
    calc = MilestoneCalculator.new(
      current_balance: 10000,
      assumption: @assumption
    )

    values = [ 80_000, 90_000, 100_000, 110_000, 120_000 ]
    percentiles = [ 10, 25, 50, 75, 90 ]

    # Very low target — should still be capped at 99.5%
    prob_low = calc.send(:estimate_probability, target: 1_000, values: values, percentiles: percentiles)
    assert prob_low <= 99.5, "Probability should be clamped to 99.5% max, got #{prob_low}"

    # Very high target — should still be at least 0.5%
    prob_high = calc.send(:estimate_probability, target: 1_000_000, values: values, percentiles: percentiles)
    assert prob_high >= 0.5, "Probability should be clamped to 0.5% min, got #{prob_high}"
  end

  test "analyzes debt milestones for reduction calculator" do
    debt_assumption = OpenStruct.new(
      effective_return: 0.05,
      monthly_contribution: 1000,
      effective_volatility: 0
    )

    calc = MilestoneCalculator.new(
      current_balance: 100000,  # $100k debt
      assumption: debt_assumption,
      target_type: "reduce_to"
    )

    milestones = calc.analyze_standard_milestones

    assert_equal Milestone::DEBT_MILESTONES.count, milestones.count

    # Paid Off milestone should have target of 0 (using constant to get exact name)
    paid_off_name = Milestone::DEBT_MILESTONES.find { |m| m[:percentage] == 1.0 }[:name]
    paid_off = milestones.find { |m| m[:name] == paid_off_name }
    assert_not_nil paid_off
    assert_equal 0, paid_off[:amount]

    # 50% Paid Off should have target of 50000 (using constant to get exact name)
    half_paid_name = Milestone::DEBT_MILESTONES.find { |m| m[:percentage] == 0.50 }[:name]
    half_paid = milestones.find { |m| m[:name] == half_paid_name }
    assert_not_nil half_paid
    assert_equal 50000, half_paid[:amount]
  end
end
