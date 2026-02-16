class SnapTradeAccount::ActivitiesProcessor
  def initialize(snaptrade_account, security_resolver:)
    @snaptrade_account = snaptrade_account
    @security_resolver = security_resolver
  end

  def process
    activities.each do |activity|
      activity_type = (activity["type"] || "").upcase
      external_id = activity["id"]&.to_s

      next if external_id.blank?

      if trade_activity?(activity_type)
        process_trade_activity(activity, external_id)
      else
        process_cash_activity(activity, external_id)
      end
    end
  end

  private
    attr_reader :snaptrade_account, :security_resolver

    TRADE_TYPES = %w[BUY SELL].freeze
    CASH_TYPES = %w[DIVIDEND INTEREST CONTRIBUTION WITHDRAWAL FEE TRANSFER DEPOSIT].freeze

    def account
      snaptrade_account.account
    end

    def activities
      raw = snaptrade_account.raw_activities_payload
      return [] if raw.blank?
      raw.is_a?(Array) ? raw : [ raw ]
    end

    def trade_activity?(type)
      TRADE_TYPES.include?(type)
    end

    def process_trade_activity(activity, external_id)
      symbol = extract_symbol(activity)
      return if symbol.blank?

      security = security_resolver.resolve(
        symbol: symbol,
        exchange_mic: extract_exchange(activity),
        currency: extract_currency(activity)
      )

      return unless security.present?

      entry = account.entries.find_or_initialize_by(plaid_id: external_id) do |e|
        e.entryable = Trade.new
      end

      qty = derived_qty(activity)
      price = (activity["price"] || 0).to_d
      currency = extract_currency(activity) || snaptrade_account.currency

      entry.assign_attributes(
        amount: qty * price,
        currency: currency,
        date: parse_date(activity)
      )

      entry.trade.assign_attributes(
        security: security,
        qty: qty,
        price: price,
        currency: currency
      )

      entry.enrich_attribute(
        :name,
        activity["description"] || "#{activity["type"]} #{symbol}",
        source: "snaptrade"
      )

      entry.save!
    end

    def process_cash_activity(activity, external_id)
      entry = account.entries.find_or_initialize_by(plaid_id: external_id) do |e|
        e.entryable = Transaction.new
      end

      amount = (activity["amount"] || 0).to_d
      currency = extract_currency(activity) || snaptrade_account.currency

      entry.assign_attributes(
        amount: amount,
        currency: currency,
        date: parse_date(activity)
      )

      entry.enrich_attribute(
        :name,
        activity["description"] || activity["type"],
        source: "snaptrade"
      )

      entry.save!
    end

    def extract_symbol(activity)
      activity.dig("symbol", "symbol") ||
        activity["symbol"]&.to_s
    end

    def extract_exchange(activity)
      activity.dig("symbol", "exchange", "mic_code")
    end

    def extract_currency(activity)
      activity.dig("symbol", "currency", "code") ||
        activity["currency"]&.dig("code") ||
        activity["currency"]&.to_s
    end

    def parse_date(activity)
      date_str = activity["trade_date"] || activity["settlement_date"] || activity["date"]
      date_str.present? ? Date.parse(date_str.to_s) : Date.current
    end

    # Normalize quantity signage based on activity type
    def derived_qty(activity)
      reported_qty = (activity["units"] || activity["quantity"] || 0).to_d
      abs_qty = reported_qty.abs
      activity_type = (activity["type"] || "").upcase

      if activity_type == "SELL"
        -abs_qty
      elsif activity_type == "BUY"
        abs_qty
      else
        reported_qty
      end
    end
end
