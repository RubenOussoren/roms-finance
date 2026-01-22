require "test_helper"

class UI::Account::ProjectionChartTest < ActiveSupport::TestCase
  setup do
    @investment_account = accounts(:investment)
    @depository_account = accounts(:depository)
  end

  test "show_chart? returns true for investment accounts" do
    component = UI::Account::ProjectionChart.new(account: @investment_account)
    assert component.show_chart?
  end

  test "show_chart? returns true for crypto accounts" do
    crypto_account = accounts(:crypto)
    component = UI::Account::ProjectionChart.new(account: crypto_account)
    assert component.show_chart?
  end

  test "show_chart? returns false for non-investment accounts" do
    component = UI::Account::ProjectionChart.new(account: @depository_account)
    assert_not component.show_chart?
  end

  test "chart_data returns historical and projection data" do
    component = UI::Account::ProjectionChart.new(account: @investment_account, years: 5)
    data = component.chart_data

    assert_includes data.keys, :historical
    assert_includes data.keys, :projections
    assert_includes data.keys, :currency
    assert_includes data.keys, :today

    assert_kind_of Array, data[:projections]
    # 5 years * 12 months = 60 data points
    assert_equal 60, data[:projections].length
  end

  test "projection data contains percentile values" do
    component = UI::Account::ProjectionChart.new(account: @investment_account, years: 1)
    data = component.chart_data

    projection_point = data[:projections].first
    assert_includes projection_point.keys, :date
    assert_includes projection_point.keys, :p10
    assert_includes projection_point.keys, :p25
    assert_includes projection_point.keys, :p50
    assert_includes projection_point.keys, :p75
    assert_includes projection_point.keys, :p90
  end

  test "projected_balance_formatted returns formatted median projection" do
    component = UI::Account::ProjectionChart.new(account: @investment_account, years: 10)

    formatted = component.projected_balance_formatted
    assert_not_nil formatted
    assert_match(/\$/, formatted)
  end

  test "assumption_summary shows default when no assumption provided" do
    component = UI::Account::ProjectionChart.new(account: @investment_account)

    summary = component.assumption_summary
    assert_not_nil summary
  end
end
