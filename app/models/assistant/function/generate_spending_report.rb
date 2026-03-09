class Assistant::Function::GenerateSpendingReport < Assistant::Function
  include CsvReportable

  class << self
    def name
      "generate_spending_report"
    end

    def description
      "Generate a downloadable CSV report of the user's transactions (income and expenses) within a date range, with category and merchant breakdowns."
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

    search = Transaction::Search.new(family, filters: {
      "start_date" => start_date.to_s,
      "end_date" => end_date.to_s
    })

    full_access_ids = full_access_accounts.select(:id)
    transactions = search.transactions_scope
      .joins(:entry)
      .where(entries: { account_id: full_access_ids })
      .includes({ entry: :account }, :category, :merchant, :tags)
      .order("entries.date ASC")

    total_income = 0
    total_expenses = 0
    category_totals = Hash.new(0)
    count = 0

    export = generate_csv_report(export_type: "spending_report", start_date: start_date, end_date: end_date) do |csv|
      csv << %w[Date Account Name Amount Currency Classification Category Merchant Tags]

      transactions.each do |txn|
        entry = txn.entry
        classification = entry.amount < 0 ? "income" : "expense"

        if classification == "income"
          total_income += entry.amount.abs
        else
          total_expenses += entry.amount.abs
          cat_name = txn.category&.name || "Uncategorized"
          category_totals[cat_name] += entry.amount.abs
        end

        count += 1

        csv << [
          entry.date.iso8601,
          entry.account.name,
          entry.name,
          entry.amount.to_s,
          entry.currency,
          classification,
          txn.category&.name,
          txn.merchant&.name,
          txn.tags.map(&:name).join(", ")
        ]
      end
    end

    top_categories = category_totals.sort_by { |_, v| -v }.first(5).map do |name, total|
      { name: name, total: Money.new(total, family.currency).format }
    end

    report_result(
      export: export,
      summary: {
        transaction_count: count,
        currency: family.currency,
        total_income: Money.new(total_income, family.currency).format,
        total_expenses: Money.new(total_expenses, family.currency).format,
        net: Money.new(total_income - total_expenses, family.currency).format,
        top_categories: top_categories
      }
    )
  end
end
