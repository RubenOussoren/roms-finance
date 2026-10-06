class Assistant::Function::GenerateTaxReport < Assistant::Function
  include CsvReportable

  class << self
    def name
      "generate_tax_report"
    end

    def description
      "Generate a downloadable CSV report summarizing income, expenses by category, candidate HELOC interest entries requiring review, and trade proceeds for tax preparation. This is informational only, not tax advice."
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

    # Name matching is evidence for review, never evidence of tax eligibility.
    candidate_interest_entries = Entry.where(account: full_access_accounts.where(accountable_type: "Loan", subtype: "heloc"), date: start_date..end_date)
      .where("name ILIKE ?", "%interest%")
      .includes(:account)
      .order(:date, :id)
    interest_review_limitations = "Candidates match HELOC entry names containing 'interest'; amounts retain their recorded sign and currency. Account type, name matching and debt-strategy existence do not establish use of borrowed funds, jurisdictional eligibility or deductibility. Review source records with a qualified tax professional; no deductible total is calculated."
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

      # Source entries, not tax classifications or a cross-currency deductible total.
      csv << []
      csv << [ "--- Candidate HELOC Interest Entries (Requires Review) ---" ]
      csv << [ interest_review_limitations ]
      csv << %w[EntryID Date Account EntryName RecordedAmount Currency ReviewStatus]

      candidate_interest_entries.each do |entry|
        csv << [ entry.id, entry.date.iso8601, candidate_evidence_text(entry.account.name), candidate_evidence_text(entry.name), entry.amount.to_s, entry.currency, "Requires review; eligibility not established" ]
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
        candidate_interest_entries_count: candidate_interest_entries.size,
        interest_review_status: "Requires review; eligibility not established",
        interest_review_limitations: interest_review_limitations,
        total_sell_proceeds: Money.new(total_sell_proceeds, family.currency).format,
        disclaimer: "This report is for informational purposes only and does not constitute tax advice."
      }
    )
  end
  private
    # CSV quoting alone does not keep spreadsheet formulas literal. Apply only to
    # textual evidence; recorded negative amounts must retain their numeric sign.
    def candidate_evidence_text(value)
      text = value.to_s
      text.match?(/\A[ \t\r\n]*[=+@-]|\A[\t\r\n]/) ? "'#{text}" : text
    end
end
