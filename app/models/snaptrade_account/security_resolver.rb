class SnapTradeAccount::SecurityResolver
  def initialize(snaptrade_account)
    @snaptrade_account = snaptrade_account
    @security_cache = {}
  end

  # Resolves an internal Security record for a given SnapTrade symbol
  def resolve(symbol:, exchange_mic: nil, currency: nil)
    cache_key = "#{symbol}:#{exchange_mic}"
    return @security_cache[cache_key] if @security_cache.key?(cache_key)

    if symbol.blank?
      @security_cache[cache_key] = nil
      return nil
    end

    # Use the existing Security::Resolver which handles DB lookups and provider searches
    security = Security::Resolver.new(
      symbol,
      exchange_operating_mic: exchange_mic,
      country_code: derive_country_code(currency)
    ).resolve

    @security_cache[cache_key] = security
    security
  end

  private
    attr_reader :snaptrade_account

    def derive_country_code(currency)
      case currency&.upcase
      when "CAD" then "CA"
      when "USD" then "US"
      end
    end
end
