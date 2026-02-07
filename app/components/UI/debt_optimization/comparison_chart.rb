# D3.js chart for comparing baseline vs prepay-only vs modified strategy scenarios
class UI::DebtOptimization::ComparisonChart < ApplicationComponent
  attr_reader :chart_series, :chart_type

  CHART_TYPES = %w[debt_comparison cumulative_tax_benefit net_cost_comparison].freeze

  def initialize(chart_series:, chart_type: "debt_comparison")
    @chart_series = chart_series
    @chart_type = chart_type
  end

  def chart_id
    "debt-optimization-chart-#{chart_type}"
  end

  def chart_title
    case chart_type
    when "debt_comparison"
      "Primary Mortgage Balance"
    when "cumulative_tax_benefit"
      "Cumulative Tax Benefit"
    when "net_cost_comparison"
      "Monthly Net Interest Cost"
    else
      "Debt Optimization"
    end
  end

  def chart_description
    case chart_type
    when "debt_comparison"
      "Compare how quickly your mortgage is paid off with vs without the strategy"
    when "cumulative_tax_benefit"
      "Total tax savings accumulated over time from deductible interest"
    when "net_cost_comparison"
      "Monthly interest paid minus tax benefit"
    else
      ""
    end
  end

  def series_data
    case chart_type
    when "debt_comparison"
      chart_series[:debt_comparison]
    when "cumulative_tax_benefit"
      { strategy: chart_series[:cumulative_tax_benefit] }
    when "net_cost_comparison"
      chart_series[:net_cost_comparison]
    else
      {}
    end
  end

  def series_json
    series_data.to_json
  end

  def has_baseline?
    chart_type != "cumulative_tax_benefit"
  end

  def has_prepay_only?
    has_baseline? && series_data.is_a?(Hash) && series_data[:prepay_only].present?
  end
end
