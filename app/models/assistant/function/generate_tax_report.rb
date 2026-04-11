class Assistant::Function::GenerateTaxReport < Assistant::Function
  include CsvReportable

  class << self
    def name
      "generate_tax_report"
    end

    def description
      "Generate a downloadable CSV report summarizing income, expenses by category, deductible interest, and capital gains for tax preparation. This is informational only, not tax advice."
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

    period = Period.custom(start_date: start_date, end_date: end_date)
    statement = IncomeStatement.new(family, viewer: user)
    income_data = statement.income_totals(period: period)
    expense_data = statement.expense_totals(period: period)

    total_deductible_interest = 0
    total_sell_proceeds = 0

    export = generate_csv_report(export_type: "tax_report", start_date: start_date, end_date: end_date) do |csv|
      # Income section
      csv << [ "--- Income by Category ---" ]
      csv << %w[Category Amount Currency]

      income_data.category_totals.sort_by { |ct| -ct.total }.each do |ct|
        csv << [ ct.category.name, ct.total.to_s, family.currency ]
      end

      csv << [ "Total Income", income_data.total.to_s, family.currency ]

      # Expense section
      csv << []
      csv << [ "--- Expenses by Category ---" ]
      csv << %w[Category Amount Currency]

      expense_data.category_totals.sort_by { |ct| -ct.total }.each do |ct|
        csv << [ ct.category.name, ct.total.to_s, family.currency ]
      end

      csv << [ "Total Expenses", expense_data.total.to_s, family.currency ]

      # Deductible HELOC interest (if Smith Manoeuvre exists)
      if family.debt_optimization_strategies.exists?
        csv << []
        csv << [ "--- Deductible Interest (Smith Manoeuvre) ---" ]
        csv << %w[Account InterestPaid Currency]

        heloc_accounts = full_access_accounts.where(accountable_type: "Loan", subtype: "heloc")
        interest_by_account = Entry.where(account: heloc_accounts, date: start_date..end_date)
          .where("name ILIKE ?", "%interest%")
          .group(:account_id)
          .sum(:amount)

        heloc_accounts.each do |account|
          interest = (interest_by_account[account.id] || 0).abs
          total_deductible_interest += interest
          csv << [ account.name, interest.to_s, account.currency ]
        end

        csv << [ "Total Deductible Interest", total_deductible_interest.to_s, family.currency ]
      end

      # Capital gains from trades (if investment accounts exist)
      investment_accounts = full_access_accounts.where(accountable_type: "Investment")
      if investment_accounts.exists?
        csv << []
        csv << [ "--- Trade Activity (proceeds are not capital gains — consult your tax professional) ---" ]
        csv << %w[Date Account Ticker Qty Price Amount Currency]

        trades = family.trades
          .joins(:entry)
          .where(entries: { account_id: investment_accounts.select(:id) })
          .where(entries: { date: start_date..end_date })
          .includes(:security, entry: :account)
          .order("entries.date ASC")

        trades.each do |trade|
          total_sell_proceeds += trade.entry.amount if trade.entry.amount > 0
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

        csv << [ "Total Proceeds (sells)", total_sell_proceeds.to_s, family.currency ]
      end

      # Disclaimer
      csv << []
      csv << [ "DISCLAIMER: This report is for informational purposes only and does not constitute tax advice." ]
      csv << [ "Consult a qualified tax professional for tax filing guidance." ]
    end

    report_result(
      export: export,
      summary: {
        currency: family.currency,
        total_income: Money.new(income_data.total, family.currency).format,
        total_expenses: Money.new(expense_data.total, family.currency).format,
        deductible_interest: Money.new(total_deductible_interest, family.currency).format,
        total_sell_proceeds: Money.new(total_sell_proceeds, family.currency).format,
        disclaimer: "This report is for informational purposes only and does not constitute tax advice."
      }
    )
  end
end
