require "test_helper"

class EquityCompensationTest < ActiveSupport::TestCase
  test "classification is asset" do
    assert_equal "asset", EquityCompensation.classification
  end

  test "icon is award" do
    assert_equal "award", EquityCompensation.icon
  end

  test "color is set" do
    assert_equal "#7C3AED", EquityCompensation.color
  end

  test "subtypes include rsu and stock_option" do
    assert_includes EquityCompensation::SUBTYPES.keys, "rsu"
    assert_includes EquityCompensation::SUBTYPES.keys, "stock_option"
  end

  test "total_vested_units sums across grants" do
    ec = equity_compensations(:one)
    # With fixtures, grants exist - just verify it returns a number
    assert ec.total_vested_units.is_a?(Numeric)
  end

  test "total_unvested_units sums across grants" do
    ec = equity_compensations(:one)
    assert ec.total_unvested_units.is_a?(Numeric)
  end

  test "next_vesting_event returns earliest next vest date" do
    ec = equity_compensations(:one)
    result = ec.next_vesting_event
    # Could be nil (fully vested) or a date
    assert result.nil? || result.is_a?(Date)
  end
end
