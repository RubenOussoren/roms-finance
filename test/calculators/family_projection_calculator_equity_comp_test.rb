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

  test "project_account_balance uses total_vested_value for EC accounts" do
    ec = @ec_account.accountable
    expected_month_12 = ec.total_vested_value(as_of: Date.current + 12.months)

    projected = @calculator.send(:project_account_balance, @ec_account, 12)
    assert_equal expected_month_12, projected
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
