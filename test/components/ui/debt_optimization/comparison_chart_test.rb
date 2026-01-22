require "test_helper"

class UI::DebtOptimization::ComparisonChartTest < ActiveSupport::TestCase
  setup do
    @chart_series = {
      debt_comparison: {
        baseline: [ { date: "2024-01", value: 400000 }, { date: "2024-02", value: 398000 } ],
        strategy: [ { date: "2024-01", value: 400000 }, { date: "2024-02", value: 396000 } ]
      },
      cumulative_tax_benefit: [ { date: "2024-01", value: 200 }, { date: "2024-02", value: 410 } ],
      net_cost_comparison: {
        baseline: [ { date: "2024-01", value: 1500 }, { date: "2024-02", value: 1480 } ],
        strategy: [ { date: "2024-01", value: 1300 }, { date: "2024-02", value: 1270 } ]
      }
    }
  end

  test "initializes with chart_series and default chart_type" do
    component = UI::DebtOptimization::ComparisonChart.new(chart_series: @chart_series)
    assert_equal @chart_series, component.chart_series
    assert_equal "debt_comparison", component.chart_type
  end

  test "can set custom chart_type" do
    component = UI::DebtOptimization::ComparisonChart.new(
      chart_series: @chart_series,
      chart_type: "cumulative_tax_benefit"
    )
    assert_equal "cumulative_tax_benefit", component.chart_type
  end

  test "chart_id includes chart_type" do
    component = UI::DebtOptimization::ComparisonChart.new(chart_series: @chart_series)
    assert_equal "debt-optimization-chart-debt_comparison", component.chart_id
  end

  test "chart_title returns Primary Mortgage Balance for debt_comparison" do
    component = UI::DebtOptimization::ComparisonChart.new(
      chart_series: @chart_series,
      chart_type: "debt_comparison"
    )
    assert_equal "Primary Mortgage Balance", component.chart_title
  end

  test "chart_title returns Cumulative Tax Benefit for cumulative_tax_benefit" do
    component = UI::DebtOptimization::ComparisonChart.new(
      chart_series: @chart_series,
      chart_type: "cumulative_tax_benefit"
    )
    assert_equal "Cumulative Tax Benefit", component.chart_title
  end

  test "chart_title returns Monthly Net Interest Cost for net_cost_comparison" do
    component = UI::DebtOptimization::ComparisonChart.new(
      chart_series: @chart_series,
      chart_type: "net_cost_comparison"
    )
    assert_equal "Monthly Net Interest Cost", component.chart_title
  end

  test "chart_description returns appropriate text for debt_comparison" do
    component = UI::DebtOptimization::ComparisonChart.new(
      chart_series: @chart_series,
      chart_type: "debt_comparison"
    )
    assert_match /mortgage/, component.chart_description.downcase
  end

  test "chart_description returns appropriate text for cumulative_tax_benefit" do
    component = UI::DebtOptimization::ComparisonChart.new(
      chart_series: @chart_series,
      chart_type: "cumulative_tax_benefit"
    )
    assert_match /tax/, component.chart_description.downcase
  end

  test "series_data returns debt_comparison data for debt_comparison type" do
    component = UI::DebtOptimization::ComparisonChart.new(
      chart_series: @chart_series,
      chart_type: "debt_comparison"
    )
    assert_equal @chart_series[:debt_comparison], component.series_data
  end

  test "series_data returns wrapped cumulative_tax_benefit data" do
    component = UI::DebtOptimization::ComparisonChart.new(
      chart_series: @chart_series,
      chart_type: "cumulative_tax_benefit"
    )
    assert_equal({ strategy: @chart_series[:cumulative_tax_benefit] }, component.series_data)
  end

  test "series_data returns net_cost_comparison data" do
    component = UI::DebtOptimization::ComparisonChart.new(
      chart_series: @chart_series,
      chart_type: "net_cost_comparison"
    )
    assert_equal @chart_series[:net_cost_comparison], component.series_data
  end

  test "series_json returns valid JSON" do
    component = UI::DebtOptimization::ComparisonChart.new(chart_series: @chart_series)
    json = component.series_json
    parsed = JSON.parse(json)
    assert_kind_of Hash, parsed
  end

  test "has_baseline? returns true for debt_comparison" do
    component = UI::DebtOptimization::ComparisonChart.new(
      chart_series: @chart_series,
      chart_type: "debt_comparison"
    )
    assert component.has_baseline?
  end

  test "has_baseline? returns false for cumulative_tax_benefit" do
    component = UI::DebtOptimization::ComparisonChart.new(
      chart_series: @chart_series,
      chart_type: "cumulative_tax_benefit"
    )
    assert_not component.has_baseline?
  end

  test "has_baseline? returns true for net_cost_comparison" do
    component = UI::DebtOptimization::ComparisonChart.new(
      chart_series: @chart_series,
      chart_type: "net_cost_comparison"
    )
    assert component.has_baseline?
  end

  test "CHART_TYPES constant includes expected types" do
    assert_includes UI::DebtOptimization::ComparisonChart::CHART_TYPES, "debt_comparison"
    assert_includes UI::DebtOptimization::ComparisonChart::CHART_TYPES, "cumulative_tax_benefit"
    assert_includes UI::DebtOptimization::ComparisonChart::CHART_TYPES, "net_cost_comparison"
  end
end
