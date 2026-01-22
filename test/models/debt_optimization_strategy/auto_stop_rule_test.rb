require "test_helper"

class DebtOptimizationStrategy::AutoStopRuleTest < ActiveSupport::TestCase
  setup do
    @strategy = debt_optimization_strategies(:smith_manoeuvre)
    @rule = @strategy.auto_stop_rules.create!(
      rule_type: "heloc_limit_percentage",
      threshold_value: 95,
      threshold_unit: "percentage",
      enabled: true
    )
    @entry = DebtOptimizationLedgerEntry.new(
      debt_optimization_strategy: @strategy,
      month_number: 12,
      calendar_month: Date.current,
      primary_mortgage_balance: 300000,
      heloc_balance: 50000,
      net_rental_cash_flow: 1500,
      heloc_interest: 300,
      tax_benefit: 200
    )
  end

  test "requires rule_type" do
    rule = DebtOptimizationStrategy::AutoStopRule.new(debt_optimization_strategy: @strategy)
    rule.rule_type = nil
    assert_not rule.valid?
  end

  test "enabled scope returns only enabled rules" do
    @rule.update!(enabled: true)
    assert DebtOptimizationStrategy::AutoStopRule.enabled.include?(@rule)

    @rule.update!(enabled: false)
    assert_not DebtOptimizationStrategy::AutoStopRule.enabled.include?(@rule)
  end

  test "description for heloc_limit_percentage" do
    @rule.rule_type = "heloc_limit_percentage"
    @rule.threshold_value = 90
    assert_includes @rule.description, "90"
    assert_includes @rule.description, "HELOC"
  end

  test "description for primary_paid_off" do
    @rule.rule_type = "primary_paid_off"
    assert_includes @rule.description, "primary mortgage"
    assert_includes @rule.description, "paid off"
  end

  test "description for max_months" do
    @rule.rule_type = "max_months"
    @rule.threshold_value = 120
    assert_includes @rule.description, "120"
    assert_includes @rule.description, "months"
  end

  test "triggered returns false when rule disabled" do
    @rule.enabled = false
    assert_not @rule.triggered?(@entry)
  end

  test "primary_paid_off rule triggers when balance is zero" do
    rule = DebtOptimizationStrategy::AutoStopRule.new(
      debt_optimization_strategy: @strategy,
      rule_type: "primary_paid_off",
      enabled: true
    )

    @entry.primary_mortgage_balance = 100
    assert_not rule.triggered?(@entry)

    @entry.primary_mortgage_balance = 0
    assert rule.triggered?(@entry)
  end

  test "all_debt_paid_off rule triggers when total debt is zero" do
    rule = DebtOptimizationStrategy::AutoStopRule.new(
      debt_optimization_strategy: @strategy,
      rule_type: "all_debt_paid_off",
      enabled: true
    )

    @entry.primary_mortgage_balance = 0
    @entry.heloc_balance = 100
    @entry.rental_mortgage_balance = 0
    assert_not rule.triggered?(@entry)

    @entry.heloc_balance = 0
    assert rule.triggered?(@entry)
  end

  test "max_months rule triggers after threshold" do
    rule = DebtOptimizationStrategy::AutoStopRule.new(
      debt_optimization_strategy: @strategy,
      rule_type: "max_months",
      threshold_value: 10,
      enabled: true
    )

    @entry.month_number = 9
    assert_not rule.triggered?(@entry)

    @entry.month_number = 10
    assert rule.triggered?(@entry)
  end

  test "negative_cash_flow rule triggers when cash flow is negative" do
    rule = DebtOptimizationStrategy::AutoStopRule.new(
      debt_optimization_strategy: @strategy,
      rule_type: "negative_cash_flow",
      enabled: true
    )

    @entry.net_rental_cash_flow = 100
    assert_not rule.triggered?(@entry)

    @entry.net_rental_cash_flow = -100
    assert rule.triggered?(@entry)
  end

  test "heloc_interest_exceeds_benefit triggers when interest > benefit" do
    rule = DebtOptimizationStrategy::AutoStopRule.new(
      debt_optimization_strategy: @strategy,
      rule_type: "heloc_interest_exceeds_benefit",
      enabled: true
    )

    @entry.heloc_interest = 100
    @entry.tax_benefit = 200
    assert_not rule.triggered?(@entry)

    @entry.heloc_interest = 300
    @entry.tax_benefit = 200
    assert rule.triggered?(@entry)
  end
end
