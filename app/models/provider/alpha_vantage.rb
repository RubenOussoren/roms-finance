class Provider::AlphaVantage < Provider
  include ExchangeRateConcept, SecurityConcept

  Error = Class.new(Provider::Error)
  InvalidExchangeRateError = Class.new(Error)
  InvalidSecurityPriceError = Class.new(Error)

  BASE_URL = "https://www.alphavantage.co/query"

  # Alpha Vantage uses suffix-based ticker format for non-US exchanges
  MIC_TO_SUFFIX = {
    "XTSE" => ".TRT",  # Toronto Stock Exchange
    "XTSX" => ".TRV"   # TSX Venture Exchange
  }.freeze

  def initialize(api_key)
    @api_key = api_key
  end

  def healthy?
    with_provider_response do
      response = client.get(BASE_URL) do |req|
        req.params["function"] = "TIME_SERIES_DAILY"
        req.params["symbol"] = "AAPL"
        req.params["outputsize"] = "compact"
        req.params["apikey"] = api_key
      end

      parsed = JSON.parse(response.body)
      parsed.key?("Time Series (Daily)")
    end
  end

  def usage
    with_provider_response do
      UsageData.new(
        used: nil,
        limit: 25,
        utilization: nil,
        plan: "free"
      )
    end
  end

  # ================================
  #          Exchange Rates
  # ================================

  def fetch_exchange_rate(from:, to:, date:)
    with_provider_response do
      outputsize = (Date.current - date).to_i > 100 ? "full" : "compact"

      response = client.get(BASE_URL) do |req|
        req.params["function"] = "FX_DAILY"
        req.params["from_symbol"] = from
        req.params["to_symbol"] = to
        req.params["outputsize"] = outputsize
        req.params["apikey"] = api_key
      end

      parsed = JSON.parse(response.body)
      validate_response!(parsed)

      series = parsed["Time Series FX (Daily)"]
      rate_data = series[date.to_s]

      unless rate_data
        closest_date = series.keys.sort.reverse.find { |d| Date.parse(d) <= date }
        rate_data = series[closest_date] if closest_date
      end

      raise Error, "No exchange rate found for #{from}/#{to} on #{date}" unless rate_data

      Rate.new(
        date: date.to_date,
        from: from,
        to: to,
        rate: rate_data["4. close"].to_f
      )
    end
  end

  def fetch_exchange_rates(from:, to:, start_date:, end_date:)
    with_provider_response do
      outputsize = (Date.current - start_date).to_i > 100 ? "full" : "compact"

      response = client.get(BASE_URL) do |req|
        req.params["function"] = "FX_DAILY"
        req.params["from_symbol"] = from
        req.params["to_symbol"] = to
        req.params["outputsize"] = outputsize
        req.params["apikey"] = api_key
      end

      parsed = JSON.parse(response.body)
      validate_response!(parsed)

      series = parsed["Time Series FX (Daily)"]

      series.filter_map do |date_str, rate_data|
        date = Date.parse(date_str)
        next unless date >= start_date && date <= end_date

        rate = rate_data["4. close"]&.to_f

        if rate.nil?
          Rails.logger.warn("#{self.class.name} returned invalid rate data for pair from: #{from} to: #{to} on: #{date_str}")
          Sentry.capture_exception(InvalidExchangeRateError.new("#{self.class.name} returned invalid rate data"), level: :warning) do |scope|
            scope.set_context("rate", { from: from, to: to, date: date_str })
          end
          next
        end

        Rate.new(date: date, from: from, to: to, rate: rate)
      end.sort_by(&:date)
    end
  end

  # ================================
  #           Securities
  # ================================

  def search_securities(symbol, country_code: nil, exchange_operating_mic: nil)
    with_provider_response do
      response = client.get(BASE_URL) do |req|
        req.params["function"] = "SYMBOL_SEARCH"
        req.params["keywords"] = symbol
        req.params["apikey"] = api_key
      end

      parsed = JSON.parse(response.body)
      matches = parsed["bestMatches"] || []

      matches.filter_map do |match|
        match_region = match["4. region"]

        # Filter by country if specified
        if country_code.present?
          next unless region_matches_country?(match_region, country_code)
        end

        # Filter by exchange MIC if specified
        mic = resolve_operating_mic(match["8. currency"], match_region)
        if exchange_operating_mic.present?
          next unless mic == exchange_operating_mic
        end

        Security.new(
          symbol: strip_suffix(match["1. symbol"]),
          name: match["2. name"],
          logo_url: nil,
          exchange_operating_mic: mic,
          country_code: resolve_country_code(match_region)
        )
      end
    end
  end

  def fetch_security_info(symbol:, exchange_operating_mic:)
    with_provider_response do
      av_symbol = apply_suffix(symbol, exchange_operating_mic)

      response = client.get(BASE_URL) do |req|
        req.params["function"] = "OVERVIEW"
        req.params["symbol"] = av_symbol
        req.params["apikey"] = api_key
      end

      data = JSON.parse(response.body)

      logo_url = if data["OfficialSite"].present?
        domain = URI.parse(data["OfficialSite"]).host rescue nil
        domain ? "https://logo.clearbit.com/#{domain}" : nil
      end

      SecurityInfo.new(
        symbol: symbol,
        name: data["Name"],
        links: data["OfficialSite"].present? ? { "website" => data["OfficialSite"] } : nil,
        logo_url: logo_url,
        description: data["Description"],
        kind: map_asset_type(data["AssetType"]),
        exchange_operating_mic: exchange_operating_mic
      )
    end
  end

  def fetch_security_price(symbol:, exchange_operating_mic: nil, date:)
    with_provider_response do
      historical_data = fetch_security_prices(symbol: symbol, exchange_operating_mic: exchange_operating_mic, start_date: date, end_date: date)

      raise ProviderError, "No prices found for security #{symbol} on date #{date}" if historical_data.data.empty?

      historical_data.data.first
    end
  end

  def fetch_security_prices(symbol:, exchange_operating_mic: nil, start_date:, end_date:)
    with_provider_response do
      av_symbol = apply_suffix(symbol, exchange_operating_mic)
      outputsize = (Date.current - start_date).to_i > 100 ? "full" : "compact"

      response = client.get(BASE_URL) do |req|
        req.params["function"] = "TIME_SERIES_DAILY"
        req.params["symbol"] = av_symbol
        req.params["outputsize"] = outputsize
        req.params["apikey"] = api_key
      end

      parsed = JSON.parse(response.body)
      validate_response!(parsed)

      series = parsed["Time Series (Daily)"]
      currency = detect_currency(exchange_operating_mic)

      series.filter_map do |date_str, price_data|
        date = Date.parse(date_str)
        next unless date >= start_date && date <= end_date

        price = price_data["4. close"]&.to_f || price_data["1. open"]&.to_f

        if price.nil?
          Rails.logger.warn("#{self.class.name} returned invalid price data for security #{symbol} on: #{date_str}")
          Sentry.capture_exception(InvalidSecurityPriceError.new("#{self.class.name} returned invalid security price data"), level: :warning) do |scope|
            scope.set_context("security", { symbol: symbol, date: date_str })
          end
          next
        end

        Price.new(
          symbol: symbol,
          date: date,
          price: price,
          currency: currency,
          exchange_operating_mic: exchange_operating_mic
        )
      end.sort_by(&:date)
    end
  end

  private
    attr_reader :api_key

    def client
      @client ||= Faraday.new do |faraday|
        faraday.request(:retry, {
          max: 2,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2
        })

        faraday.response :raise_error
      end
    end

    def validate_response!(parsed)
      if parsed.key?("Error Message")
        raise Error, "Alpha Vantage API error: #{parsed['Error Message']}"
      end

      if parsed.key?("Note")
        raise Error, "Alpha Vantage rate limit reached: #{parsed['Note']}"
      end

      if parsed.key?("Information") && parsed["Information"].include?("rate limit")
        raise Error, "Alpha Vantage rate limit reached: #{parsed['Information']}"
      end
    end

    def apply_suffix(symbol, exchange_operating_mic)
      suffix = MIC_TO_SUFFIX[exchange_operating_mic]
      suffix ? "#{symbol}#{suffix}" : symbol
    end

    def strip_suffix(av_symbol)
      MIC_TO_SUFFIX.each_value do |suffix|
        return av_symbol.delete_suffix(suffix) if av_symbol.end_with?(suffix)
      end
      av_symbol
    end

    def resolve_operating_mic(currency, region)
      case region
      when /Toronto/i
        "XTSE"
      when /TSX Venture/i
        "XTSX"
      when /NYSE/i, /New York/i
        "XNYS"
      when /NASDAQ/i
        "XNAS"
      else
        currency == "CAD" ? "XTSE" : "XNAS"
      end
    end

    def resolve_country_code(region)
      case region
      when /United States/i
        "US"
      when /Toronto/i, /TSX/i, /Canada/i
        "CA"
      when /London/i, /United Kingdom/i
        "GB"
      else
        "US"
      end
    end

    def region_matches_country?(region, country_code)
      resolve_country_code(region) == country_code
    end

    def detect_currency(exchange_operating_mic)
      case exchange_operating_mic
      when "XTSE", "XTSX"
        "CAD"
      when "XLON"
        "GBP"
      else
        "USD"
      end
    end

    def map_asset_type(asset_type)
      case asset_type&.downcase
      when "common stock"
        "common stock"
      when "etf"
        "etf"
      when "mutual fund"
        "mutual fund"
      else
        asset_type&.downcase
      end
    end
end
