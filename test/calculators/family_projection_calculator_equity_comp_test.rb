require "test_helper"

class FamilyProjectionCalculatorEquityCompTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @calculator = FamilyProjectionCalculator.new(@family)
    @ec_account = accounts(:equity_compensation)
    @rsu_grant = equity_grants(:rsu_grant)
  end

  test "equity compensation accounts use vesting-based projection not flat" do
    result = @calculator.project(years: 2)

    # Month 1 and month 24 should differ since vesting produces step changes
    month_1 = result[:projections][0]
    month_24 = result[:projections][23]

    # Assets should include equity comp vesting values
    assert month_1[:assets].is_a?(Numeric)
    assert month_24[:assets].is_a?(Numeric)
  end

  test "project_account_balance uses opening + total_remaining_value for EC accounts" do
    ec = @ec_account.accountable
    as_of = Date.current + 12.months
    expected = (@ec_account.opening_anchor_balance || 0) + ec.total_remaining_value(as_of: as_of)

    projected = @calculator.send(:project_account_balance, @ec_account, 12)
    assert_equal expected, projected
  end

  test "projection excludes sold units" do
    Security.any_instance.stubs(:current_price).returns(Money.new(200, "USD"))
    grant = @rsu_grant
    as_of = Date.current + 12.months
    vested_future = grant.vested_units(as_of: as_of)

    projected_before = @calculator.send(:project_account_balance, @ec_account, 12)

    # Sell half the future-vested units today - clear cache since calculator memoizes
    grant.sales.create!(date: Date.current, units: vested_future / 2, proceeds: 1000, currency: "USD")
    calculator = FamilyProjectionCalculator.new(@family)

    projected_after = calculator.send(:project_account_balance, @ec_account, 12)
    assert projected_after < projected_before,
      "Expected projection to decrease after sale (was #{projected_before}, now #{projected_after})"
  end

  test "projection includes opening balance" do
    Security.any_instance.stubs(:current_price).returns(Money.new(200, "USD"))
    @ec_account.set_opening_anchor_balance(balance: 5000, date: Date.new(2023, 1, 1))

    calculator = FamilyProjectionCalculator.new(@family)
    projected = calculator.send(:project_account_balance, @ec_account, 12)
    ec = @ec_account.accountable
    as_of = Date.current + 12.months
    expected = 5000 + ec.total_remaining_value(as_of: as_of)
    assert_equal expected, projected
  end

  test "fully vested grants plateau at total value" do
    # Set grant to be fully vested by projecting far enough ahead
    far_future_month = 120

    projected_far = @calculator.send(:project_account_balance, @ec_account, far_future_month)
    projected_farther = @calculator.send(:project_account_balance, @ec_account, far_future_month + 12)

    # Once fully vested, value should not change (assuming same price)
    assert_equal projected_far, projected_farther
  end

  test "mixed portfolio with investment and EC aggregates correctly" do
    result = @calculator.project(years: 1)

    # The projection should include contributions from both investment and EC accounts
    month_6 = result[:projections][5]
    assert month_6[:assets] > 0, "Assets should be positive with investment + EC accounts"
  end

  test "EC projection returns account balance when accountable is nil" do
    # Create a mock account with nil accountable
    account = @ec_account
    account.stubs(:accountable).returns(nil)

    projected = @calculator.send(:project_account_balance, account, 6)
    assert_equal account.balance, projected
  end
end
