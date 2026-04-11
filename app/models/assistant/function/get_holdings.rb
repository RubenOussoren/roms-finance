class Assistant::Function::GetHoldings < Assistant::Function
  class << self
    def name
      "get_holdings"
    end

    def description
      <<~INSTRUCTIONS
        Get the user's current investment holdings with performance data.

        This is great for:
        - Portfolio overview (what stocks/ETFs does the user own?)
        - Analyzing investment performance and gains/losses
        - Understanding portfolio allocation and weights
      INSTRUCTIONS
    end
  end

  def params_schema
    build_schema(
      required: [],
      properties: {
        account_name: {
          type: "string",
          description: "Filter holdings to a specific investment account by name. Omit for all investment accounts."
        }
      }
    )
  end

  def strict_mode?
    false
  end

  def call(params = {})
    investment_accounts = accessible_accounts.where(accountable_type: "Investment")

    if params["account_name"].present?
      investment_accounts = investment_accounts.where(name: params["account_name"])
    end

    all_holdings = []

    investment_accounts.each do |account|
      holdings = account.holdings.where(date: account.holdings.maximum(:date))
                        .includes(:security)

      avg_costs = Holding.preload_avg_costs(holdings, account)

      holdings.each do |holding|
        holding.preloaded_avg_cost = avg_costs[holding.security_id]

        all_holdings << {
          account: account.name,
          ticker: holding.ticker,
          name: holding.name,
          quantity: holding.qty.to_f,
          price: holding.price.to_f,
          currency: holding.currency,
          market_value: holding.amount_money.format,
          avg_cost: holding.avg_cost&.format,
          weight: holding.weight&.round(2),
          unrealized_gain_loss: unrealized_gain_loss(holding)
        }
      end
    end

    {
      as_of_date: Date.current,
      total_holdings: all_holdings.size,
      holdings: all_holdings
    }
  end

  private
    def unrealized_gain_loss(holding)
      return nil unless holding.avg_cost

      cost_basis = holding.avg_cost.amount * holding.qty
      current_value = holding.amount
      gain_loss = current_value - cost_basis

      {
        amount: Money.new(gain_loss, holding.currency).format,
        percent: cost_basis.zero? ? 0 : ((gain_loss / cost_basis) * 100).round(2)
      }
    end
end
