class SnapTradeAccount::PositionsProcessor
  def initialize(snaptrade_account, security_resolver:)
    @snaptrade_account = snaptrade_account
    @security_resolver = security_resolver
  end

  def process
    positions.each do |position|
      symbol = extract_symbol(position)
      next if symbol.blank?

      security = security_resolver.resolve(
        symbol: symbol,
        exchange_mic: extract_exchange(position),
        currency: extract_currency(position)
      )

      next unless security.present?

      qty = extract_field(position, "units", "quantity").to_d
      price = extract_field(position, "price").to_d
      currency = extract_currency(position) || snaptrade_account.currency

      holding = account.holdings.find_or_initialize_by(
        security: security,
        date: Date.current,
        currency: currency
      )

      holding.assign_attributes(
        qty: qty,
        price: price,
        amount: qty * price
      )

      ActiveRecord::Base.transaction do
        holding.save!

        # Delete stale holdings for this security after today
        account.holdings
          .where(security: security)
          .where("date > ?", Date.current)
          .destroy_all
      end
    end
  end

  private
    attr_reader :snaptrade_account, :security_resolver

    def account
      snaptrade_account.account
    end

    def positions
      raw = snaptrade_account.raw_positions_payload
      return [] if raw.blank?
      # SDK v2 may return {"data" => [...], "pagination" => {...}} — unwrap
      raw = raw["data"] if raw.is_a?(Hash) && raw.key?("data")
      return [] if raw.blank?
      items = raw.is_a?(Array) ? raw : [ raw ]
      # Handle legacy stored format: [{"data" => [...], "pagination" => {...}}]
      if items.size == 1 && items.first.is_a?(Hash) && items.first.key?("data")
        items = Array(items.first["data"])
      end
      items
    end

    def extract_symbol(position)
      # SDK v2: position.symbol is PositionSymbol wrapping UniversalSymbol
      position.dig("symbol", "symbol", "symbol") ||
        position.dig("symbol", "symbol", "raw_symbol") ||
        # Flat format (activities-style or older SDK)
        ticker_from_value(position.dig("symbol", "symbol")) ||
        position.dig("symbol", "raw_symbol") ||
        position.dig("symbol", "description") ||
        nil
    end

    def extract_exchange(position)
      # SDK v2: nested under UniversalSymbol
      position.dig("symbol", "symbol", "exchange", "mic_code") ||
        position.dig("symbol", "symbol", "exchange", "code") ||
        # Flat format
        position.dig("symbol", "exchange", "mic_code") ||
        position.dig("symbol", "exchange", "code")
    end

    def extract_currency(position)
      # SDK v2: nested under UniversalSymbol
      position.dig("symbol", "symbol", "currency", "code") ||
        # Flat format
        position.dig("symbol", "currency", "code") ||
        # Top-level currency
        position.dig("currency", "code") ||
        position["currency"]
    end

    def ticker_from_value(value)
      return value if value.is_a?(String) && value.present?
      value["symbol"] if value.is_a?(Hash)
    end

    def extract_field(position, *keys)
      keys.each do |key|
        value = position[key]
        return value if value.present?
      end
      0
    end
end
