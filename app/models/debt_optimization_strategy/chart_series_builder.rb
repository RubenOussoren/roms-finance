# Chart series builder for debt optimization visualizations
class DebtOptimizationStrategy::ChartSeriesBuilder
  attr_reader :strategy

  def initialize(strategy)
    @strategy = strategy
  end

  # Primary mortgage balance comparison: baseline vs prepay-only vs modified strategy
  def debt_comparison_series
    series = {
      baseline: build_series(strategy.baseline_entries, :primary_mortgage_balance),
      strategy: build_series(strategy.strategy_entries, :primary_mortgage_balance)
    }
    prepay_only = strategy.prepay_only_entries
    series[:prepay_only] = build_series(prepay_only, :primary_mortgage_balance) if prepay_only.any?
    series
  end

  # Total debt comparison (all debts combined)
  def total_debt_series
    series = {
      baseline: build_series(strategy.baseline_entries, :total_debt),
      strategy: build_series(strategy.strategy_entries, :total_debt)
    }
    prepay_only = strategy.prepay_only_entries
    series[:prepay_only] = build_series(prepay_only, :total_debt) if prepay_only.any?
    series
  end

  # Cumulative tax benefit over time
  def cumulative_tax_benefit_series
    build_series(strategy.strategy_entries, :cumulative_tax_benefit)
  end

  # Monthly tax benefit
  def monthly_tax_benefit_series
    build_series(strategy.strategy_entries, :tax_benefit)
  end

  # HELOC balance over time
  def heloc_balance_series
    build_series(strategy.strategy_entries, :heloc_balance)
  end

  # Interest breakdown: deductible vs non-deductible
  def interest_breakdown_series
    {
      deductible: build_series(strategy.strategy_entries, :deductible_interest),
      non_deductible: build_series(strategy.strategy_entries, :non_deductible_interest)
    }
  end

  # Net cost comparison (interest paid minus tax benefit)
  def net_cost_comparison_series
    baseline_series = strategy.baseline_entries.map do |entry|
      {
        date: entry.calendar_month.iso8601,
        value: entry.primary_mortgage_interest + entry.rental_mortgage_interest
      }
    end

    strategy_series = strategy.strategy_entries.map do |entry|
      total_interest = entry.primary_mortgage_interest +
                       entry.rental_mortgage_interest +
                       entry.heloc_interest
      net_cost = total_interest - entry.tax_benefit
      {
        date: entry.calendar_month.iso8601,
        value: net_cost
      }
    end

    series = {
      baseline: baseline_series,
      strategy: strategy_series
    }

    prepay_only = strategy.prepay_only_entries
    if prepay_only.any?
      series[:prepay_only] = prepay_only.map do |entry|
        {
          date: entry.calendar_month.iso8601,
          value: entry.primary_mortgage_interest + entry.rental_mortgage_interest
        }
      end
    end

    series
  end

  # Cash flow series
  def cash_flow_series
    build_series(strategy.strategy_entries, :net_rental_cash_flow)
  end

  # All series combined for dashboard
  def all_series
    {
      debt_comparison: debt_comparison_series,
      total_debt: total_debt_series,
      cumulative_tax_benefit: cumulative_tax_benefit_series,
      monthly_tax_benefit: monthly_tax_benefit_series,
      heloc_balance: heloc_balance_series,
      interest_breakdown: interest_breakdown_series,
      net_cost_comparison: net_cost_comparison_series,
      cash_flow: cash_flow_series
    }
  end

  # Summary metrics for display
  def summary_metrics
    baseline_final = strategy.baseline_entries.last
    strategy_final = strategy.strategy_entries.where(strategy_stopped: false).last ||
                     strategy.strategy_entries.last

    return {} unless baseline_final && strategy_final

    # Find payoff months
    baseline_payoff = strategy.baseline_entries.find { |e| e.primary_mortgage_balance <= 0 }
    strategy_payoff = strategy.strategy_entries.find { |e| e.primary_mortgage_balance <= 0 }

    total_heloc_interest = strategy.strategy_entries.sum(&:heloc_interest)

    {
      net_benefit: strategy.net_benefit || 0,
      total_tax_benefit: strategy_final.cumulative_tax_benefit,
      total_interest_saved: strategy.total_interest_saved || 0,
      total_heloc_interest_paid: total_heloc_interest,
      months_accelerated: strategy.months_accelerated || 0,
      baseline_payoff_month: baseline_payoff&.month_number,
      strategy_payoff_month: strategy_payoff&.month_number,
      final_heloc_balance: strategy_final.heloc_balance,
      strategy_stopped: strategy_final.strategy_stopped,
      stop_reason: strategy_final.stop_reason
    }
  end

  private

    def build_series(entries, attribute)
      entries.map do |entry|
        {
          date: entry.calendar_month.iso8601,
          value: entry.send(attribute)
        }
      end
    end
end
