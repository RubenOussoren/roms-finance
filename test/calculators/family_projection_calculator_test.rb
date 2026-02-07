require "test_helper"

class FamilyProjectionCalculatorTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @calculator = FamilyProjectionCalculator.new(@family)
  end

  test "project returns complete projection data" do
    result = @calculator.project(years: 5)

    assert_includes result.keys, :historical
    assert_includes result.keys, :projections
    assert_includes result.keys, :currency
    assert_includes result.keys, :today
    assert_includes result.keys, :summary
    assert_equal @family.currency, result[:currency]
    assert_equal 60, result[:projections].count # 5 years * 12 months
  end

  test "projection includes percentile bands" do
    result = @calculator.project(years: 1)
    first_month = result[:projections].first

    assert_includes first_month.keys, :p10
    assert_includes first_month.keys, :p25
    assert_includes first_month.keys, :p50
    assert_includes first_month.keys, :p75
    assert_includes first_month.keys, :p90
    assert_includes first_month.keys, :assets
    assert_includes first_month.keys, :liabilities
    assert_includes first_month.keys, :date
  end

  test "percentile bands are properly ordered" do
    result = @calculator.project(years: 2)
    final_month = result[:projections].last

    assert final_month[:p10] <= final_month[:p25], "p10 should be <= p25"
    assert final_month[:p25] <= final_month[:p50], "p25 should be <= p50"
    assert final_month[:p50] <= final_month[:p75], "p50 should be <= p75"
    assert final_month[:p75] <= final_month[:p90], "p75 should be <= p90"
  end

  test "percentile bands widen over time" do
    result = @calculator.project(years: 2)

    month_6 = result[:projections][5]
    month_24 = result[:projections][23]

    width_6 = month_6[:p90] - month_6[:p10]
    width_24 = month_24[:p90] - month_24[:p10]

    assert width_24 > width_6, "Bands should widen over time due to compounding uncertainty"
  end

  test "summary_metrics returns correct structure" do
    metrics = @calculator.summary_metrics

    assert_includes metrics.keys, :current_net_worth
    assert_includes metrics.keys, :total_assets
    assert_includes metrics.keys, :total_liabilities
    assert_includes metrics.keys, :currency
    assert_equal @family.currency, metrics[:currency]
  end

  test "currency warnings included when accounts have mixed currencies" do
    # Dylan family has USD currency but Smith accounts use CAD
    result = @calculator.project(years: 1)

    assert_includes result.keys, :currency_warnings
    assert result[:currency_warnings].any? { |w| w.include?("Mixed currencies") }
  end

  test "currency warnings absent when all accounts match family currency" do
    # Temporarily set all accounts to family currency to test no-warning case
    family_currency = @family.currency
    @family.accounts.active.update_all(currency: family_currency)

    calc = FamilyProjectionCalculator.new(@family)
    result = calc.project(years: 1)

    assert_not_includes result.keys, :currency_warnings
  end

  test "calculate_percentiles uses analytical bands" do
    # Test the internal percentile calculation method
    net_worth = 100_000
    month = 12
    volatility = 0.15

    percentiles = @calculator.send(:calculate_percentiles, net_worth, month, volatility)

    # Check z-score based calculations (approx)
    # p10 uses z = -1.28, p90 uses z = 1.28
    # At 12 months with 15% volatility, sigma = 0.15 * sqrt(1) = 0.15
    expected_p10 = net_worth * Math.exp(-1.28 * 0.15)
    expected_p90 = net_worth * Math.exp(1.28 * 0.15)

    assert_in_delta expected_p10, percentiles[:p10], 1.0
    assert_in_delta expected_p90, percentiles[:p90], 1.0
    # p50 (median) should be less than mean due to drift correction
    sigma = 0.15 * Math.sqrt(12 / 12.0)
    expected_p50 = (net_worth * Math.exp(-sigma**2 / 2.0)).round(2)
    assert_in_delta expected_p50, percentiles[:p50], 1.0
    assert percentiles[:p50] < net_worth.to_f, "p50 (median) should be less than mean"
  end

  test "p50 median is lower than mean for non-zero volatility" do
    net_worth = 100_000
    month = 60  # 5 years
    volatility = 0.18

    percentiles = @calculator.send(:calculate_percentiles, net_worth, month, volatility)

    sigma = volatility * Math.sqrt(month / 12.0)
    expected_p50 = (net_worth * Math.exp(-sigma**2 / 2.0)).round(2)
    assert_in_delta expected_p50, percentiles[:p50], 1.0
    assert percentiles[:p50] < net_worth.to_f, "median should be below mean at 18% volatility over 5 years"
  end

  test "aggregate_volatility with empty accounts returns default" do
    volatility = @calculator.send(:aggregate_volatility, [])
    assert_equal 0.15, volatility
  end

  test "aggregate_volatility uses portfolio variance formula" do
    asset_accounts = @family.accounts.where(classification: "asset").active

    # Should not raise and should return a reasonable value
    volatility = @calculator.send(:aggregate_volatility, asset_accounts)

    assert volatility >= 0, "Volatility should be non-negative"
    assert volatility <= 1.0, "Volatility should be <= 100%"
  end

  test "portfolio volatility is lower than weighted average due to diversification" do
    # Create two mock accounts with different asset classes (use BigDecimal for balance like AR)
    equity_account = OpenStruct.new(
      id: "eq-1", balance: BigDecimal("60000"), accountable_type: "Investment",
      projection_assumption: nil, currency: "CAD", family: @family
    )
    bond_account = OpenStruct.new(
      id: "bond-1", balance: BigDecimal("40000"), accountable_type: "Depository",
      projection_assumption: nil, currency: "CAD", family: @family
    )

    accounts = [ equity_account, bond_account ]

    # Stub ProjectionAssumption.for_account to return controlled volatilities
    equity_assumption = OpenStruct.new(effective_volatility: 0.18)
    bond_assumption = OpenStruct.new(effective_volatility: 0.06)

    ProjectionAssumption.stub(:for_account, ->(acct) {
      acct.id == "eq-1" ? equity_assumption : bond_assumption
    }) do
      volatility = @calculator.send(:aggregate_volatility, accounts)

      # Weighted average would be: 0.6 * 0.18 + 0.4 * 0.06 = 0.132
      weighted_avg = 0.6 * 0.18 + 0.4 * 0.06

      assert volatility < weighted_avg, "Portfolio volatility (#{volatility.round(4)}) should be less than weighted average (#{weighted_avg}) due to diversification"
      assert volatility > 0, "Portfolio volatility should be positive"
    end
  end

  test "single asset portfolio returns that asset volatility" do
    single_account = OpenStruct.new(
      id: "eq-only", balance: BigDecimal("100000"), accountable_type: "Investment",
      projection_assumption: nil, currency: "CAD", family: @family
    )

    assumption = OpenStruct.new(effective_volatility: 0.18)

    ProjectionAssumption.stub(:for_account, ->(_) { assumption }) do
      volatility = @calculator.send(:aggregate_volatility, [ single_account ])

      # Single asset: self-correlation = 1.0, so variance = 1² * 0.18² * 1.0 = 0.0324
      # volatility = sqrt(0.0324) = 0.18
      assert_in_delta 0.18, volatility, 0.001
    end
  end

  test "loan balance projection decreases over time" do
    loan_account = accounts(:loan)

    month_1 = @calculator.send(:project_loan_balance, loan_account, 1)
    month_12 = @calculator.send(:project_loan_balance, loan_account, 12)
    month_60 = @calculator.send(:project_loan_balance, loan_account, 60)

    assert month_12 < loan_account.balance.abs, "Balance should decrease after payments"
    assert month_60 < month_12, "Balance should continue decreasing"
  end

  test "depository uses default savings rate when no assumption exists" do
    depository = accounts(:depository)
    depository.projection_assumption&.destroy
    depository.reload

    calc = FamilyProjectionCalculator.new(@family)
    balance_12 = calc.send(:project_account_balance, depository, 12)

    expected = depository.balance * (1 + 0.02 / 12) ** 12
    assert_in_delta expected, balance_12, 0.01, "Should use DEFAULT_SAVINGS_RATE of 2%"
  end

  test "depository uses custom savings rate from projection assumption" do
    depository = accounts(:depository)
    ProjectionAssumption.create_for_account(depository, expected_return: 0.05, use_pag_defaults: false)
    depository.reload

    calc = FamilyProjectionCalculator.new(@family)
    balance_12 = calc.send(:project_account_balance, depository, 12)

    expected = depository.balance * (1 + 0.05 / 12) ** 12
    assert_in_delta expected, balance_12, 0.01, "Should use custom 5% rate from assumption"
  end

  test "investment balance projection increases over time" do
    investment_account = accounts(:investment)

    month_1 = @calculator.send(:project_investment_balance, investment_account, 1)
    month_12 = @calculator.send(:project_investment_balance, investment_account, 12)

    assert month_12 > investment_account.balance, "Investment should grow over time"
    assert month_12 > month_1, "Growth should compound"
  end

  test "calculate_percentiles handles negative net worth correctly" do
    net_worth = -50_000  # More debt than assets
    month = 12
    volatility = 0.15

    percentiles = @calculator.send(:calculate_percentiles, net_worth, month, volatility)

    # For negative net worth:
    # p10 (pessimistic) should be more negative than p50
    # p90 (optimistic) should be less negative than p50
    assert percentiles[:p10] < percentiles[:p50], "p10 should be more negative than p50"
    assert percentiles[:p50] < percentiles[:p90], "p50 should be more negative than p90"

    # Verify ordering: p10 < p25 < p50 < p75 < p90
    assert percentiles[:p10] < percentiles[:p25], "p10 should be < p25"
    assert percentiles[:p25] < percentiles[:p50], "p25 should be < p50"
    assert percentiles[:p50] < percentiles[:p75], "p50 should be < p75"
    assert percentiles[:p75] < percentiles[:p90], "p75 should be < p90"
  end

  test "calculate_percentiles handles zero net worth" do
    net_worth = 0
    month = 12
    volatility = 0.15

    percentiles = @calculator.send(:calculate_percentiles, net_worth, month, volatility)

    # Zero should result in all percentiles being zero
    assert_equal 0.0, percentiles[:p10]
    assert_equal 0.0, percentiles[:p50]
    assert_equal 0.0, percentiles[:p90]
  end

  test "percentile bands remain properly ordered at high volatility" do
    net_worth = 100_000
    month = 24
    volatility = 0.50  # 50% volatility

    percentiles = @calculator.send(:calculate_percentiles, net_worth, month, volatility)

    # Even with high volatility, ordering should be maintained
    assert percentiles[:p10] < percentiles[:p25], "p10 should be < p25 at high volatility"
    assert percentiles[:p25] < percentiles[:p50], "p25 should be < p50 at high volatility"
    assert percentiles[:p50] < percentiles[:p75], "p50 should be < p75 at high volatility"
    assert percentiles[:p75] < percentiles[:p90], "p75 should be < p90 at high volatility"
  end

  test "percentile bands remain properly ordered for negative net worth at high volatility" do
    net_worth = -100_000
    month = 24
    volatility = 0.50  # 50% volatility

    percentiles = @calculator.send(:calculate_percentiles, net_worth, month, volatility)

    # Even with high volatility and negative values, ordering should be maintained
    assert percentiles[:p10] < percentiles[:p25], "p10 should be < p25 at high volatility"
    assert percentiles[:p25] < percentiles[:p50], "p25 should be < p50 at high volatility"
    assert percentiles[:p50] < percentiles[:p75], "p50 should be < p75 at high volatility"
    assert percentiles[:p75] < percentiles[:p90], "p75 should be < p90 at high volatility"
  end
end
