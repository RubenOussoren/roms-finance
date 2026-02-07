require "test_helper"

class CanadianMortgageTest < ActiveSupport::TestCase
  # Reference table: Canadian semi-annual compounding
  # For a quoted annual rate, the effective monthly rate is (1 + r/2)^(1/6) - 1
  #
  # Rate  | Monthly Rate (CA)  | Monthly Rate (US)  | Payment $400K/25yr (CA) | Payment (US)
  # 4.00% | 0.003305890        | 0.003333333        | $2,104.08               | $2,111.36
  # 5.00% | 0.004123915        | 0.004166667        | $2,326.42               | $2,338.36
  # 6.00% | 0.004938622        | 0.005000000        | $2,559.23               | $2,577.15
  # 7.00% | 0.005750039        | 0.005833333        | $2,801.66               | $2,827.08

  # --- monthly_rate tests ---

  test "monthly_rate for 5% annual returns approximately 0.004123915" do
    rate = CanadianMortgage.monthly_rate(0.05)
    assert_in_delta 0.004123915, rate, 0.000001
  end

  test "monthly_rate for 5% differs from US convention (annual/12)" do
    ca_rate = CanadianMortgage.monthly_rate(0.05)
    us_rate = 0.05 / 12.0

    assert ca_rate < us_rate, "Canadian semi-annual rate should be lower than US monthly"
    assert_in_delta 0.00004276, us_rate - ca_rate, 0.00000001
  end

  test "monthly_rate for 4% annual" do
    rate = CanadianMortgage.monthly_rate(0.04)
    assert_in_delta 0.003305841, rate, 0.000001
  end

  test "monthly_rate for 6% annual" do
    rate = CanadianMortgage.monthly_rate(0.06)
    assert_in_delta 0.004938622, rate, 0.000001
  end

  test "monthly_rate for 7% annual" do
    rate = CanadianMortgage.monthly_rate(0.07)
    assert_in_delta 0.005750039, rate, 0.000001
  end

  test "monthly_rate returns 0 for zero rate" do
    assert_equal 0.0, CanadianMortgage.monthly_rate(0)
  end

  test "monthly_rate returns 0 for nil rate" do
    assert_equal 0.0, CanadianMortgage.monthly_rate(nil)
  end

  # --- monthly_rate_simple tests ---

  test "monthly_rate_simple returns annual/12" do
    assert_in_delta 0.004166667, CanadianMortgage.monthly_rate_simple(0.05), 0.000001
  end

  test "monthly_rate_simple returns 0 for nil" do
    assert_equal 0.0, CanadianMortgage.monthly_rate_simple(nil)
  end

  # --- monthly_payment tests ---

  test "monthly payment for $400K at 5% over 25 years is approximately $2,326" do
    payment = CanadianMortgage.monthly_payment(400_000, 0.05, 300)
    assert_in_delta 2326.42, payment, 1.0
  end

  test "monthly payment differs from US convention" do
    ca_payment = CanadianMortgage.monthly_payment(400_000, 0.05, 300)
    # US monthly compounding: 0.05/12 = 0.004166667
    us_rate = 0.05 / 12.0
    us_payment = (400_000 * us_rate * (1 + us_rate)**300) / ((1 + us_rate)**300 - 1)

    assert ca_payment < us_payment, "Canadian payment should be lower"
    assert_in_delta 12.0, us_payment - ca_payment, 1.0
  end

  test "monthly payment at 4% matches reference" do
    payment = CanadianMortgage.monthly_payment(400_000, 0.04, 300)
    assert_in_delta 2104.08, payment, 1.0
  end

  test "monthly payment at 6% matches reference" do
    payment = CanadianMortgage.monthly_payment(400_000, 0.06, 300)
    assert_in_delta 2559.23, payment, 1.0
  end

  test "monthly payment at 7% matches reference" do
    payment = CanadianMortgage.monthly_payment(400_000, 0.07, 300)
    assert_in_delta 2801.66, payment, 1.0
  end

  test "monthly payment returns 0 for zero principal" do
    assert_equal 0, CanadianMortgage.monthly_payment(0, 0.05, 300)
  end

  test "monthly payment returns 0 for zero term" do
    assert_equal 0, CanadianMortgage.monthly_payment(400_000, 0.05, 0)
  end

  test "monthly payment with zero rate divides evenly" do
    payment = CanadianMortgage.monthly_payment(300_000, 0, 300)
    assert_in_delta 1000.0, payment, 0.01
  end

  # --- Total interest over life of mortgage ---

  test "total interest over 25 years is less than US convention" do
    ca_payment = CanadianMortgage.monthly_payment(400_000, 0.05, 300)
    ca_total_interest = (ca_payment * 300) - 400_000

    us_rate = 0.05 / 12.0
    us_payment = (400_000 * us_rate * (1 + us_rate)**300) / ((1 + us_rate)**300 - 1)
    us_total_interest = (us_payment * 300) - 400_000

    assert ca_total_interest < us_total_interest,
           "Canadian total interest ($#{ca_total_interest.round(2)}) should be less than US ($#{us_total_interest.round(2)})"

    # Difference should be roughly $3,600 over 25 years (~$12/month * 300)
    diff = us_total_interest - ca_total_interest
    assert_in_delta 3600, diff, 300
  end

  # --- monthly_interest tests ---

  test "monthly_interest uses semi-annual compounding" do
    interest = CanadianMortgage.monthly_interest(400_000, 0.05)
    expected = 400_000 * CanadianMortgage.monthly_rate(0.05)
    assert_in_delta expected, interest, 0.01
    # Should NOT equal 400_000 * 0.05 / 12
    assert (interest - 400_000 * 0.05 / 12).abs > 1.0
  end

  test "monthly_interest returns 0 for zero balance" do
    assert_equal 0, CanadianMortgage.monthly_interest(0, 0.05)
  end

  # --- monthly_interest_simple tests ---

  test "monthly_interest_simple uses monthly compounding" do
    interest = CanadianMortgage.monthly_interest_simple(100_000, 0.07)
    assert_in_delta 100_000 * 0.07 / 12, interest, 0.01
  end
end
