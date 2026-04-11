class Assistant::Function::GenerateInvestmentReport < Assistant::Function
  include CsvReportable

  class << self
    def name
      "generate_investment_report"
    end

    def description
      "Generate a downloadable CSV report of the user's investment holdings and trades within a date range."
    end
  end

  def params_schema
    build_schema(
      required: %w[start_date end_date],
      properties: date_range_properties
    )
  end

  def call(params = {})
    start_date, end_date = parse_date_range(params)

    investment_accounts = full_access_accounts.where(accountable_type: "Investment")
    total_market_value = 0
    total_cost_basis = 0
    holdings_count = 0
    trade_count = 0

    export = generate_csv_report(export_type: "investment_report", start_date: start_date, end_date: end_date) do |csv|
      # Holdings section
      csv << [ "--- Holdings as of #{end_date.iso8601} ---" ]
      csv << %w[Account Ticker Name Qty Price MarketValue AvgCost GainLoss Weight%]

      account_ids = investment_accounts.pluck(:id)
      all_holdings = Holding.where(account_id: account_ids, date: end_date)
                            .includes(:security, :account)

      investment_accounts.each do |account|
        holdings = all_holdings.select { |h| h.account_id == account.id }
        avg_costs = Holding.preload_avg_costs(holdings, account)

        holdings.each do |holding|
          holding.preloaded_avg_cost = avg_costs[holding.security_id]

          market_value = holding.amount
          total_market_value += market_value
          holdings_count += 1

          gain_loss = nil
          if holding.avg_cost
            cost_basis = holding.avg_cost.amount * holding.qty
            total_cost_basis += cost_basis
            gain_loss = market_value - cost_basis
          end

          csv << [
            account.name,
            holding.ticker,
            holding.name,
            holding.qty.to_f,
            holding.price.to_f,
            market_value.to_f,
            holding.avg_cost&.amount&.to_f,
            gain_loss&.to_f,
            holding.weight&.round(2)
          ]
        end
      end

      # Trades section
      csv << []
      csv << [ "--- Trades from #{start_date.iso8601} to #{end_date.iso8601} ---" ]
      csv << %w[Date Account Ticker Qty Price Amount Currency]

      trades = family.trades
        .joins(:entry)
        .where(entries: { account_id: investment_accounts.select(:id) })
        .where(entries: { date: start_date..end_date })
        .includes(:security, entry: :account)
        .order("entries.date ASC")

      trades.each do |trade|
        trade_count += 1
        csv << [
          trade.entry.date.iso8601,
          trade.entry.account.name,
          trade.security.ticker,
          trade.qty.to_s,
          trade.price.to_s,
          trade.entry.amount.to_s,
          trade.currency
        ]
      end
    end

    unrealized = total_market_value - total_cost_basis

    report_result(
      export: export,
      summary: {
        currency: family.currency,
        total_market_value: Money.new(total_market_value, family.currency).format,
        unrealized_gain_loss: Money.new(unrealized, family.currency).format,
        holdings_count: holdings_count,
        trade_count: trade_count
      }
    )
  end
end
