class Provider::Frankfurter < Provider
  include ExchangeRateConcept

  Error = Class.new(Provider::Error)

  BASE_URL = "https://api.frankfurter.dev/v1"

  def healthy?
    with_provider_response do
      response = client.get("#{BASE_URL}/latest") do |req|
        req.params["base"] = "USD"
        req.params["symbols"] = "CAD"
      end

      parsed = JSON.parse(response.body)
      parsed["rates"].is_a?(Hash) && parsed["rates"].any?
    end
  end

  def fetch_exchange_rate(from:, to:, date:)
    with_provider_response do
      response = client.get("#{BASE_URL}/#{date.iso8601}") do |req|
        req.params["base"] = from
        req.params["symbols"] = to
      end

      parsed = JSON.parse(response.body)
      validate_response!(parsed)

      rate = parsed.dig("rates", to)
      raise Error, "No exchange rate found for #{from}/#{to} on #{date}" unless rate

      Rate.new(
        date: date,
        from: from,
        to: to,
        rate: rate.to_f
      )
    end
  end

  def fetch_exchange_rates(from:, to:, start_date:, end_date:)
    with_provider_response do
      response = client.get("#{BASE_URL}/#{start_date.iso8601}..#{end_date.iso8601}") do |req|
        req.params["base"] = from
        req.params["symbols"] = to
      end

      parsed = JSON.parse(response.body)
      validate_response!(parsed)

      rates = parsed["rates"] || {}

      rates.filter_map do |date_str, rate_data|
        rate = rate_data[to]&.to_f
        next unless rate

        Rate.new(
          date: Date.parse(date_str),
          from: from,
          to: to,
          rate: rate
        )
      end.sort_by(&:date)
    end
  end

  private
    def client
      provider_client
    end

    def validate_response!(parsed)
      if parsed.is_a?(Hash) && parsed["message"].present? && parsed["rates"].blank?
        raise Error, "Frankfurter API error: #{parsed['message']}"
      end
    end
end
