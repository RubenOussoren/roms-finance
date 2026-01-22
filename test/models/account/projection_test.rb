require "test_helper"

class Account::ProjectionTest < ActiveSupport::TestCase
  setup do
    @projection = account_projections(:month_6)
    @account = accounts(:investment)
  end

  test "calculates variance between projected and actual" do
    # Actual 13500 - Projected 13608.25 = -108.25
    assert_in_delta -108.25, @projection.variance, 0.01
  end

  test "calculates variance percentage" do
    # (13500 - 13608.25) / 13608.25 * 100 = -0.80%
    expected = ((13500 - 13608.25) / 13608.25 * 100).round(2)
    assert_in_delta expected, @projection.variance_percentage, 0.01
  end

  test "calculates absolute percentage error" do
    assert @projection.absolute_percentage_error > 0
    assert_in_delta 0.8, @projection.absolute_percentage_error, 0.1
  end

  test "on_track returns true when within 10% below projection" do
    assert @projection.on_track?
  end

  test "returns percentile values" do
    projection_with_percentiles = account_projections(:month_12)
    assert_equal 15000.0, projection_with_percentiles.percentile(10)
    assert_equal 17356.79, projection_with_percentiles.percentile(50)
    assert_equal 20000.0, projection_with_percentiles.percentile(90)
  end

  test "returns confidence range" do
    projection_with_percentiles = account_projections(:month_12)
    range = projection_with_percentiles.confidence_range(level: 50)

    # Fixture has p10, p25, p50, p75, p90
    assert_not_nil range[:median]  # p50
    # With level: 50, lower would be p25, upper would be p75
    assert_not_nil range[:lower]   # p25
    assert_not_nil range[:upper]   # p75
  end

  test "records actual balance" do
    projection = account_projections(:month_1)
    projection.record_actual!(10600)

    assert_equal 10600, projection.actual_balance
  end

  test "validates presence of required fields" do
    projection = Account::Projection.new
    assert_not projection.valid?
    assert projection.errors[:projection_date].present?
    assert projection.errors[:projected_balance].present?
    assert projection.errors[:currency].present?
  end

  test "validates uniqueness of projection date per account" do
    duplicate = Account::Projection.new(
      account: @projection.account,
      projection_date: @projection.projection_date,
      projected_balance: 10000,
      currency: "USD"
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:projection_date].present?
  end
end
