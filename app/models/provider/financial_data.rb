class Provider::FinancialData < Provider
  include SecurityConcept

  Error = Class.new(Provider::Error)
  InvalidSecurityPriceError = Class.new(Error)

  BASE_URL = "https://financialdata.net/api/v1"

  SYMBOL_CACHE_KEY = "financial_data:symbols"
  SYMBOL_CACHE_TTL = 24.hours

  # financialdata.net uses Yahoo-style suffixes for non-US exchanges
  MIC_TO_SUFFIX = {
    "XTSE" => ".TO",   # Toronto Stock Exchange
    "XTSX" => ".V",    # TSX Venture Exchange
    "XLON" => ".L"     # London Stock Exchange
  }.freeze

  SUFFIX_TO_MIC = MIC_TO_SUFFIX.invert.freeze

  def initialize(api_key)
    @api_key = api_key
  end

  def healthy?
    with_provider_response do
      response = client.get("#{BASE_URL}/stock-prices") do |req|
        req.params["identifier"] = "AAPL"
        req.params["key"] = api_key
      end

      parsed = JSON.parse(response.body)
      parsed.is_a?(Array) && parsed.any?
    end
  end

  def usage
    with_provider_response do
      UsageData.new(
        used: nil,
        limit: 300,
        utilization: nil,
        plan: "free"
      )
    end
  end

  # ================================
  #           Securities
  # ================================

  def search_securities(symbol, country_code: nil, exchange_operating_mic: nil)
    with_provider_response do
      # DB search first — fast, indexed, includes logos
      db_results = search_database_fallback(symbol, country_code: country_code, exchange_operating_mic: exchange_operating_mic)

      remaining = 20 - db_results.size
      if remaining > 0
        cached_symbols = Rails.cache.read(SYMBOL_CACHE_KEY)
        if cached_symbols.present?
          db_tickers = db_results.map { |s| s.symbol.upcase }.to_set
          cache_results = search_cached_symbols(cached_symbols, symbol,
            country_code: country_code, exchange_operating_mic: exchange_operating_mic,
            limit: remaining, exclude_tickers: db_tickers)
          db_results + cache_results
        else
          db_results
        end
      else
        db_results
      end
    end
  end

  def fetch_security_info(symbol:, exchange_operating_mic:)
    with_provider_response do
      fd_symbol = apply_suffix(symbol, exchange_operating_mic)
      endpoint = international_exchange?(exchange_operating_mic) ? "international-company-information" : "company-information"

      response = client.get("#{BASE_URL}/#{endpoint}") do |req|
        req.params["identifier"] = fd_symbol
        req.params["key"] = api_key
      end

      data = JSON.parse(response.body)
      data = data.first if data.is_a?(Array)
      data ||= {}

      website = data["website"].presence
      logo_url = if website.present?
        domain = URI.parse(website).host rescue nil
        domain ? "https://logo.clearbit.com/#{domain}" : nil
      end

      SecurityInfo.new(
        symbol: symbol,
        name: data["registrant_name"] || data["companyName"] || data["name"],
        links: website ? { "website" => website } : nil,
        logo_url: logo_url,
        description: data["description"],
        kind: map_asset_type(data["sic_description"] || data["industry"] || data["type"]),
        exchange_operating_mic: exchange_operating_mic
      )
    end
  end

  def fetch_security_price(symbol:, exchange_operating_mic: nil, date:)
    with_provider_response do
      historical_data = fetch_security_prices(symbol: symbol, exchange_operating_mic: exchange_operating_mic, start_date: date, end_date: date)

      raise Error, "No prices found for security #{symbol} on date #{date}" if historical_data.data.empty?

      historical_data.data.first
    end
  end

  def fetch_security_prices(symbol:, exchange_operating_mic: nil, start_date:, end_date:)
    with_provider_response do
      fd_symbol, endpoint = resolve_price_endpoint(symbol, exchange_operating_mic)
      currency = detect_currency(exchange_operating_mic)
      all_prices = []
      offset = 0
      max_pages = 50 # ~15,000 trading days ≈ 60 years of history

      loop do
        break if offset / 300 >= max_pages

        response = client.get("#{BASE_URL}/#{endpoint}") do |req|
          req.params["identifier"] = fd_symbol
          req.params["key"] = api_key
          req.params["offset"] = offset if offset > 0
        end

        parsed = JSON.parse(response.body)
        validate_response!(parsed)

        batch = parsed.is_a?(Array) ? parsed : []
        break if batch.empty?

        # API returns newest-first; check if we've passed the start_date
        oldest_in_batch = begin
          Date.parse(batch.last["date"])
        rescue ArgumentError, TypeError
          nil
        end

        batch.each do |price_data|
          date = Date.parse(price_data["date"])
          next unless date >= start_date && date <= end_date

          price = price_data["close"]&.to_f || price_data["open"]&.to_f

          if price.nil?
            Rails.logger.warn("#{self.class.name} returned invalid price data for security #{symbol} on: #{price_data['date']}")
            Sentry.capture_exception(InvalidSecurityPriceError.new("#{self.class.name} returned invalid security price data"), level: :warning) do |scope|
              scope.set_context("security", { symbol: symbol, date: price_data["date"] })
            end
            next
          end

          all_prices << Price.new(
            symbol: symbol,
            date: date,
            price: price,
            currency: currency,
            exchange_operating_mic: exchange_operating_mic
          )
        end

        # Stop if this batch didn't fill a full page or we've gone past start_date
        break if batch.size < 300
        break if oldest_in_batch && oldest_in_batch < start_date

        offset += 300
      end

      all_prices.sort_by(&:date)
    end
  end

  # ================================
  #        Symbol Cache
  # ================================

  def warm_symbol_cache!
    symbols = []

    symbols.concat(fetch_symbol_list("stock-symbols"))
    symbols.concat(fetch_symbol_list("etf-symbols"))
    symbols.concat(fetch_symbol_list("international-stock-symbols"))

    Rails.cache.write(SYMBOL_CACHE_KEY, symbols, expires_in: SYMBOL_CACHE_TTL)
    symbols.size
  end

  private
    attr_reader :api_key

    def client
      provider_client
    end

    def validate_response!(parsed)
      if parsed.is_a?(Hash) && parsed["error"].present?
        raise Error, "FinancialData API error: #{parsed['error']}"
      end
    end

    def apply_suffix(symbol, exchange_operating_mic)
      suffix = MIC_TO_SUFFIX[exchange_operating_mic]
      suffix ? "#{symbol}#{suffix}" : symbol
    end

    def strip_suffix(fd_symbol)
      MIC_TO_SUFFIX.each_value do |suffix|
        return fd_symbol.delete_suffix(suffix) if fd_symbol.end_with?(suffix)
      end
      fd_symbol
    end

    def resolve_mic_from_suffix(fd_symbol)
      SUFFIX_TO_MIC.each do |suffix, mic|
        return mic if fd_symbol.end_with?(suffix)
      end
      "XNAS" # Default to NASDAQ for unsuffixed symbols
    end

    CRYPTO_SYMBOLS = %w[BTC ETH XRP SOL DOGE ADA DOT AVAX MATIC LINK].freeze

    def resolve_price_endpoint(symbol, exchange_operating_mic)
      if crypto_symbol?(symbol, exchange_operating_mic)
        [ "#{symbol}USD", "crypto-prices" ]
      elsif international_exchange?(exchange_operating_mic)
        [ apply_suffix(symbol, exchange_operating_mic), "international-stock-prices" ]
      else
        [ apply_suffix(symbol, exchange_operating_mic), "stock-prices" ]
      end
    end

    def crypto_symbol?(symbol, exchange_operating_mic)
      exchange_operating_mic.nil? && CRYPTO_SYMBOLS.include?(symbol.upcase)
    end

    def international_exchange?(exchange_operating_mic)
      %w[XTSE XTSX XLON].include?(exchange_operating_mic)
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
      when "common stock", "stock"
        "common stock"
      when "etf"
        "etf"
      when "mutual fund"
        "mutual fund"
      else
        asset_type&.downcase
      end
    end

    # ================================
    #   Symbol List Fetching
    # ================================

    MAX_SYMBOL_PAGES = 200

    def fetch_symbol_list(endpoint)
      symbols = []
      page = 0

      loop do
        break if page >= MAX_SYMBOL_PAGES

        response = client.get("#{BASE_URL}/#{endpoint}") do |req|
          req.params["key"] = api_key
          req.params["page"] = page
        end

        parsed = JSON.parse(response.body)
        items = parsed.is_a?(Array) ? parsed : []
        break if items.empty?

        items.each do |item|
          trading_symbol = item["trading_symbol"] || item["symbol"]
          next unless trading_symbol.present?

          mic = resolve_mic_from_suffix(trading_symbol)
          clean_symbol = strip_suffix(trading_symbol)

          symbols << {
            symbol: clean_symbol,
            name: item["registrant_name"] || item["name"],
            country_code: mic_to_country(mic),
            exchange_mic: mic,
            raw_symbol: trading_symbol
          }
        end

        page += 1
        break if items.size < 500 # Last page
      end

      symbols
    end

    def mic_to_country(mic)
      case mic
      when "XTSE", "XTSX"
        "CA"
      when "XLON"
        "GB"
      else
        "US"
      end
    end

    # ================================
    #   Symbol Search (cached)
    # ================================

    def search_cached_symbols(cached_symbols, query, country_code: nil, exchange_operating_mic: nil,
                              limit: 20, exclude_tickers: Set.new)
      return [] if query.length < 2

      query_downcase = query.downcase
      max_collect = [ limit * 5, 100 ].min

      # Filter by country and exchange if specified
      filtered = cached_symbols
      filtered = filtered.select { |s| s[:country_code] == country_code } if country_code.present?
      filtered = filtered.select { |s| s[:exchange_mic] == exchange_operating_mic } if exchange_operating_mic.present?

      # Score matches: exact symbol > prefix > name substring
      exact = []
      prefix = []
      name_match = []

      filtered.each do |s|
        next if exclude_tickers.include?(s[:symbol].upcase)

        sym = s[:symbol].downcase

        if sym == query_downcase
          exact << s
        elsif sym.start_with?(query_downcase) && prefix.size < max_collect
          prefix << s
        elsif exact.size + prefix.size < limit # skip name matching once we have enough ticker matches
          name = s[:name]&.downcase || ""
          if name.include?(query_downcase) && name_match.size < max_collect
            name_match << s
          end
        end
      end

      results = (exact + prefix + name_match).first(limit)

      tickers = results.map { |s| s[:symbol].upcase }
      logo_map = ::Security.where(ticker: tickers)
                           .where.not(logo_url: nil)
                           .pluck(:ticker, :logo_url).to_h

      results.map do |s|
        Security.new(
          symbol: s[:symbol],
          name: s[:name],
          logo_url: logo_map[s[:symbol].upcase],
          exchange_operating_mic: s[:exchange_mic],
          country_code: s[:country_code]
        )
      end
    end

    def search_database_fallback(query, country_code: nil, exchange_operating_mic: nil)
      sanitized = ::Security.sanitize_sql_like(query)
      scope = ::Security.where("ticker ILIKE :q OR name ILIKE :q", q: "%#{sanitized}%")
      scope = scope.where(country_code: country_code) if country_code.present?
      scope = scope.where(exchange_operating_mic: exchange_operating_mic) if exchange_operating_mic.present?

      # Prioritize exact ticker matches, then ticker prefix, then name matches
      scope = scope.order(
        Arel.sql(::Security.sanitize_sql_array([
          "CASE WHEN ticker ILIKE ? THEN 0 WHEN ticker ILIKE ? THEN 1 ELSE 2 END",
          sanitized, "#{sanitized}%"
        ])),
        :ticker
      )

      scope.limit(20).map do |sec|
        Security.new(
          symbol: sec.ticker,
          name: sec.name,
          logo_url: sec.logo_url,
          exchange_operating_mic: sec.exchange_operating_mic,
          country_code: sec.country_code
        )
      end
    end
end
