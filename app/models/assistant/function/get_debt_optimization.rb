class Assistant::Function::GetDebtOptimization < Assistant::Function
  class << self
    def name
      "get_debt_optimization"
    end

    def description
      <<~INSTRUCTIONS
        Get debt optimization strategy analysis including Smith Manoeuvre results.

        This is great for:
        - "How much can I save with the Smith Manoeuvre?"
        - "What's my debt payoff strategy looking like?"
        - Comparing baseline vs optimized debt strategies
      INSTRUCTIONS
    end
  end

  def params_schema
    build_schema(
      required: [],
      properties: {
        strategy_name: {
          type: "string",
          description: "Filter to a specific strategy by name. Omit for an overview of all strategies."
        }
      }
    )
  end

  def strict_mode?
    false
  end

  def call(params = {})
    strategies = family.debt_optimization_strategies
    if params["strategy_name"].present?
      strategies = strategies.where(name: params["strategy_name"])
    end

    {
      as_of_date: Date.current,
      total_strategies: strategies.count,
      strategies: strategies.includes(:primary_mortgage, :heloc).map { |strategy|
        data = {
          name: strategy.name,
          strategy_type: strategy.strategy_type,
          status: strategy.status,
          province: strategy.province,
          simulation_months: strategy.simulation_months
        }

        if strategy.primary_mortgage.present?
          data[:primary_mortgage] = {
            name: strategy.primary_mortgage.name,
            balance: strategy.primary_mortgage.balance_money.format
          }
        end

        if strategy.heloc.present?
          data[:heloc] = {
            name: strategy.heloc.name,
            balance: strategy.heloc.balance_money.format,
            readvanceable: strategy.readvanceable_heloc?
          }
        end

        if strategy.simulated? || strategy.active?
          data[:results] = {
            total_interest_saved: strategy.total_interest_saved&.format,
            total_tax_benefit: strategy.total_tax_benefit&.format,
            net_benefit: strategy.net_benefit&.format,
            months_accelerated: strategy.months_accelerated
          }
        end

        data
      }
    }
  end
end
