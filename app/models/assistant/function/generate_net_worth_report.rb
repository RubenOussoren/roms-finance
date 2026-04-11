class Assistant::Function::GenerateNetWorthReport < Assistant::Function
  include CsvReportable

  class << self
    def name
      "generate_net_worth_report"
    end

    def description
      "Generate a downloadable CSV report of the user's net worth over time, showing monthly balances within the date range."
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
    accounts = accessible_accounts
    account_ids = accounts.pluck(:id)
    period = Period.custom(start_date: start_date, end_date: end_date)

    builder = Balance::ChartSeriesBuilder.new(
      account_ids: account_ids,
      currency: family.currency,
      period: period,
      favorable_direction: "up",
      interval: "1 month"
    )

    series = builder.balance_series

    export = generate_csv_report(export_type: "net_worth_report", start_date: start_date, end_date: end_date) do |csv|
      csv << %w[Date NetWorth Currency]

      series.values.each do |value|
        csv << [
          value.date.iso8601,
          value.value.amount.to_s,
          family.currency
        ]
      end

      # Current account breakdown
      csv << []
      csv << [ "--- Account Breakdown (current) ---" ]
      csv << %w[Account Type Classification Balance Currency]

      accounts.each do |account|
        csv << [
          account.name,
          account.accountable_type,
          account.classification,
          account.balance.to_s,
          account.currency
        ]
      end
    end

    start_value = series.values.first&.value&.amount || 0
    end_value = series.values.last&.value&.amount || 0

    report_result(
      export: export,
      summary: {
        account_count: accounts.size,
        currency: family.currency,
        start_net_worth: Money.new(start_value, family.currency).format,
        end_net_worth: Money.new(end_value, family.currency).format,
        change: Money.new(end_value - start_value, family.currency).format
      }
    )
  end
end
