require "test_helper"

class DebtOptimizationLedgerEntryTest < ActiveSupport::TestCase
  setup do
    @strategy = debt_optimization_strategies(:smith_manoeuvre)
    @entry = DebtOptimizationLedgerEntry.new(
      debt_optimization_strategy: @strategy,
      month_number: 1,
      calendar_month: Date.current,
      baseline: false,
      primary_mortgage_balance: 400000,
      primary_mortgage_payment: 2500,
      primary_mortgage_principal: 800,
      primary_mortgage_interest: 1700,
      primary_mortgage_prepayment: 500,
      heloc_balance: 10000,
      heloc_interest: 58,
      heloc_payment: 58,
      rental_mortgage_balance: 200000,
      rental_mortgage_payment: 1200,
      rental_mortgage_principal: 400,
      rental_mortgage_interest: 800,
      deductible_interest: 858,
      non_deductible_interest: 1700,
      tax_benefit: 343,
      cumulative_tax_benefit: 686
    )
  end

  test "requires month_number" do
    @entry.month_number = nil
    assert_not @entry.valid?
    assert_includes @entry.errors[:month_number], "can't be blank"
  end

  test "requires calendar_month" do
    @entry.calendar_month = nil
    assert_not @entry.valid?
    assert_includes @entry.errors[:calendar_month], "can't be blank"
  end

  test "total_monthly_payment sums all payments" do
    expected = @entry.primary_mortgage_payment + @entry.heloc_payment + @entry.rental_mortgage_payment
    assert_equal expected, @entry.total_monthly_payment
  end

  test "total_outstanding_debt sums all balances" do
    expected = @entry.primary_mortgage_balance + @entry.heloc_balance + @entry.rental_mortgage_balance
    assert_equal expected, @entry.total_outstanding_debt
  end

  test "total_interest_paid sums deductible and non-deductible" do
    expected = @entry.deductible_interest + @entry.non_deductible_interest
    assert_equal expected, @entry.total_interest_paid
  end

  test "primary_mortgage_paid_off when balance is zero" do
    @entry.primary_mortgage_balance = 0
    assert @entry.primary_mortgage_paid_off?
  end

  test "primary_mortgage_not_paid_off when balance is positive" do
    @entry.primary_mortgage_balance = 100
    assert_not @entry.primary_mortgage_paid_off?
  end

  test "all_debt_paid_off when total debt is zero" do
    @entry.primary_mortgage_balance = 0
    @entry.heloc_balance = 0
    @entry.rental_mortgage_balance = 0
    assert @entry.all_debt_paid_off?
  end

  test "not all_debt_paid_off when any balance remains" do
    @entry.primary_mortgage_balance = 0
    @entry.heloc_balance = 100
    @entry.rental_mortgage_balance = 0
    assert_not @entry.all_debt_paid_off?
  end

  test "to_summary_hash returns expected keys" do
    summary = @entry.to_summary_hash
    assert summary.key?(:month_number)
    assert summary.key?(:calendar_month)
    assert summary.key?(:heloc_balance)
    assert summary.key?(:tax_benefit)
    assert summary.key?(:cumulative_tax_benefit)
  end

  test "baseline_entries scope returns only baseline entries" do
    @entry.save!
    baseline_entry = DebtOptimizationLedgerEntry.create!(
      debt_optimization_strategy: @strategy,
      month_number: 1,
      calendar_month: Date.current,
      baseline: true
    )

    baseline_results = DebtOptimizationLedgerEntry.baseline_entries
    assert baseline_results.include?(baseline_entry)
    assert_not baseline_results.include?(@entry)
  end

  test "strategy_entries scope returns only non-baseline entries" do
    @entry.save!
    baseline_entry = DebtOptimizationLedgerEntry.create!(
      debt_optimization_strategy: @strategy,
      month_number: 2,
      calendar_month: Date.current + 1.month,
      baseline: true
    )

    strategy_results = DebtOptimizationLedgerEntry.strategy_entries
    assert strategy_results.include?(@entry)
    assert_not strategy_results.include?(baseline_entry)
  end
end
