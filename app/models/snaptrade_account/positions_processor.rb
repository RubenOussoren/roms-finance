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
      raw.is_a?(Array) ? raw : [ raw ]
    end

    def extract_symbol(position)
      position.dig("symbol", "symbol") ||
        position.dig("symbol", "description") ||
        position["symbol"]&.to_s
    end

    def extract_exchange(position)
      position.dig("symbol", "exchange", "mic_code") ||
        position.dig("symbol", "exchange", "code")
    end

    def extract_currency(position)
      position.dig("symbol", "currency", "code") ||
        position["currency"]
    end

    def extract_field(position, *keys)
      keys.each do |key|
        value = position[key]
        return value if value.present?
      end
      0
    end
end
