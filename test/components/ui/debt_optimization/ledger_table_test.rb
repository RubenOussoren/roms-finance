require "test_helper"

class UI::DebtOptimization::LedgerTableTest < ActiveSupport::TestCase
  setup do
    @strategy = debt_optimization_strategies(:baseline)

    # Create test entries with correct column names
    @entry1 = DebtOptimizationLedgerEntry.create!(
      debt_optimization_strategy: @strategy,
      month_number: 1,
      calendar_month: Date.current,
      primary_mortgage_balance: 400000,
      heloc_balance: 10000,
      total_debt: 410000,
      tax_benefit: 200,
      cumulative_tax_benefit: 200,
      scenario_type: "modified_smith",
      strategy_stopped: false
    )

    @entry2 = DebtOptimizationLedgerEntry.create!(
      debt_optimization_strategy: @strategy,
      month_number: 2,
      calendar_month: Date.current + 1.month,
      primary_mortgage_balance: 398000,
      heloc_balance: 12000,
      total_debt: 410000,
      tax_benefit: 210,
      cumulative_tax_benefit: 410,
      scenario_type: "modified_smith",
      strategy_stopped: false
    )
  end

  test "initializes with entries" do
    entries = DebtOptimizationLedgerEntry.where(id: [ @entry1.id, @entry2.id ])
    component = UI::DebtOptimization::LedgerTable.new(entries: entries)
    assert_equal entries, component.entries
  end

  test "show_baseline defaults to false" do
    entries = DebtOptimizationLedgerEntry.where(id: [ @entry1.id ])
    component = UI::DebtOptimization::LedgerTable.new(entries: entries)
    assert_not component.show_baseline
  end

  test "show_baseline can be set to true" do
    entries = DebtOptimizationLedgerEntry.where(id: [ @entry1.id ])
    component = UI::DebtOptimization::LedgerTable.new(entries: entries, show_baseline: true)
    assert component.show_baseline
  end

  test "currency returns strategy currency" do
    entries = DebtOptimizationLedgerEntry.where(id: [ @entry1.id ])
    component = UI::DebtOptimization::LedgerTable.new(entries: entries)
    assert_equal "CAD", component.currency
  end

  test "format_month returns formatted month and year" do
    entries = DebtOptimizationLedgerEntry.where(id: [ @entry1.id ])
    component = UI::DebtOptimization::LedgerTable.new(entries: entries)
    formatted = component.format_month(Date.new(2024, 6, 15))
    assert_equal "Jun 2024", formatted
  end

  test "row_classes returns empty when entry not stopped and not paid off" do
    entries = DebtOptimizationLedgerEntry.where(id: [ @entry1.id ])
    component = UI::DebtOptimization::LedgerTable.new(entries: entries)
    assert_equal "", component.row_classes(@entry1)
  end

  test "row_classes returns red background when strategy stopped" do
    @entry1.update!(strategy_stopped: true)
    entries = DebtOptimizationLedgerEntry.where(id: [ @entry1.id ])
    component = UI::DebtOptimization::LedgerTable.new(entries: entries)
    assert_equal "bg-red-50", component.row_classes(@entry1)
  end

  test "row_classes returns green background when primary mortgage paid off" do
    @entry1.update!(primary_mortgage_balance: 0)
    entries = DebtOptimizationLedgerEntry.where(id: [ @entry1.id ])
    component = UI::DebtOptimization::LedgerTable.new(entries: entries)
    assert_equal "bg-green-50", component.row_classes(@entry1)
  end

  teardown do
    DebtOptimizationLedgerEntry.where(debt_optimization_strategy: @strategy).delete_all
  end
end
