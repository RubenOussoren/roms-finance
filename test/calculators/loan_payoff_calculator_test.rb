require "test_helper"

class LoanPayoffCalculatorTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:loan)
  end

  test "initializes with default extra payment of zero" do
    calc = LoanPayoffCalculator.new(@account)

    assert_equal 0, calc.extra_payment
  end

  test "initializes with custom extra payment" do
    calc = LoanPayoffCalculator.new(@account, extra_payment: 500)

    assert_equal 500, calc.extra_payment
  end

  test "total_monthly_payment includes extra payment" do
    baseline_calc = LoanPayoffCalculator.new(@account)
    extra_calc = LoanPayoffCalculator.new(@account, extra_payment: 500)

    expected = baseline_calc.send(:monthly_payment) + 500
    assert_in_delta expected, extra_calc.total_monthly_payment, 0.01
  end

  test "extra payment reduces months to payoff" do
    baseline_calc = LoanPayoffCalculator.new(@account)
    extra_calc = LoanPayoffCalculator.new(@account, extra_payment: 500)

    baseline_months = baseline_calc.amortization_schedule.length
    extra_months = extra_calc.amortization_schedule.length

    assert extra_months < baseline_months, "Extra payment should reduce months to payoff"
  end

  test "extra payment reduces total interest" do
    baseline_calc = LoanPayoffCalculator.new(@account)
    extra_calc = LoanPayoffCalculator.new(@account, extra_payment: 500)

    baseline_interest = baseline_calc.amortization_schedule.sum { |e| e[:interest] }
    extra_interest = extra_calc.amortization_schedule.sum { |e| e[:interest] }

    assert extra_interest < baseline_interest, "Extra payment should reduce total interest"
  end

  test "interest_saved_with_extra_payment returns positive value" do
    calc = LoanPayoffCalculator.new(@account, extra_payment: 500)

    saved = calc.interest_saved_with_extra_payment

    assert saved > 0, "Should save interest with extra payment"
  end

  test "interest_saved_with_extra_payment returns zero without extra payment" do
    calc = LoanPayoffCalculator.new(@account)

    saved = calc.interest_saved_with_extra_payment

    assert_equal 0, saved
  end

  test "months_saved_with_extra_payment returns positive value" do
    calc = LoanPayoffCalculator.new(@account, extra_payment: 500)

    saved = calc.months_saved_with_extra_payment

    assert saved > 0, "Should save months with extra payment"
  end

  test "months_saved_with_extra_payment returns zero without extra payment" do
    calc = LoanPayoffCalculator.new(@account)

    saved = calc.months_saved_with_extra_payment

    assert_equal 0, saved
  end

  test "summary includes correct values" do
    calc = LoanPayoffCalculator.new(@account, extra_payment: 500)

    summary = calc.summary

    assert_equal @account, summary[:account]
    assert_equal 500000, summary[:current_balance]
    assert summary[:months_to_payoff].present?
    assert summary[:payoff_date].present?
    assert summary[:total_interest_remaining] > 0
  end

  test "chart_data returns array of points" do
    calc = LoanPayoffCalculator.new(@account)

    data = calc.chart_data

    assert data.is_a?(Array)
    assert data.length > 0

    first_point = data.first
    assert first_point[:date].present?
    assert first_point[:balance].present?
  end
end
