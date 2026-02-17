class SnapTradeAccount::ActivitiesProcessor
  def initialize(snaptrade_account, security_resolver:)
    @snaptrade_account = snaptrade_account
    @security_resolver = security_resolver
  end

  def process
    Rails.logger.info("[SnapTrade] Processing #{activities.size} activities for account #{snaptrade_account.snaptrade_account_id}")
    processed = 0
    skipped = 0

    activities.each do |activity|
      activity_type = (activity["type"] || "").upcase
      external_id = activity["id"]&.to_s

      if external_id.blank?
        Rails.logger.warn("[SnapTrade] Skipping activity with blank ID: type=#{activity_type}")
        skipped += 1
        next
      end

      if trade_activity?(activity_type)
        process_trade_activity(activity, external_id)
      else
        process_cash_activity(activity, external_id)
      end
      processed += 1
    end

    Rails.logger.info("[SnapTrade] Activities complete: #{processed} processed, #{skipped} skipped")
  end

  private
    attr_reader :snaptrade_account, :security_resolver

    TRADE_TYPES = %w[BUY SELL].freeze
    CASH_TYPES = %w[DIVIDEND INTEREST CONTRIBUTION WITHDRAWAL FEE TRANSFER DEPOSIT].freeze
    INFLOW_TYPES = %w[DEPOSIT CONTRIBUTION DIVIDEND INTEREST].freeze

    def account
      snaptrade_account.account
    end

    def activities
      raw = snaptrade_account.raw_activities_payload
      return [] if raw.blank?
      # SDK v2 activities endpoint returns {"data" => [...], "pagination" => {...}}
      raw = raw["data"] if raw.is_a?(Hash) && raw.key?("data")
      return [] if raw.blank?
      items = raw.is_a?(Array) ? raw : [ raw ]
      # Handle legacy stored format: [{"data" => [...], "pagination" => {...}}]
      if items.size == 1 && items.first.is_a?(Hash) && items.first.key?("data")
        items = Array(items.first["data"])
      end
      items
    end

    def trade_activity?(type)
      TRADE_TYPES.include?(type)
    end

    def process_trade_activity(activity, external_id)
      symbol = extract_symbol(activity)
      if symbol.blank?
        Rails.logger.warn("[SnapTrade] Skipping trade activity #{external_id}: blank symbol")
        return
      end

      security = security_resolver.resolve(
        symbol: symbol,
        exchange_mic: extract_exchange(activity),
        currency: extract_currency(activity)
      )

      unless security.present?
        Rails.logger.warn("[SnapTrade] Skipping trade activity #{external_id}: could not resolve security for symbol=#{symbol}")
        return
      end

      entry = account.entries.find_or_initialize_by(plaid_id: external_id) do |e|
        e.entryable = Trade.new
      end

      qty = derived_qty(activity)
      price = (activity["price"] || 0).to_d
      currency = extract_currency(activity) || snaptrade_account.currency

      entry.assign_attributes(
        name: activity["description"] || "#{activity["type"]} #{symbol}",
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

      entry.save!
      Rails.logger.info("[SnapTrade] Saved trade entry #{external_id}: #{activity["type"]} #{qty} #{symbol} @ #{price}")
    end

    def process_cash_activity(activity, external_id)
      entry = account.entries.find_or_initialize_by(plaid_id: external_id) do |e|
        e.entryable = Transaction.new
      end

      raw_amount = (activity["amount"] || 0).to_d
      amount = signed_cash_amount(raw_amount, activity)
      currency = extract_currency(activity) || snaptrade_account.currency

      entry.assign_attributes(
        name: activity["description"] || activity["type"],
        amount: amount,
        currency: currency,
        date: parse_date(activity)
      )

      entry.save!
      Rails.logger.info("[SnapTrade] Saved cash entry #{external_id}: #{activity["type"]} #{amount} #{currency}")
    end

    # App convention: negative = inflow (money in), positive = outflow (money out)
    def signed_cash_amount(raw_amount, activity)
      type = (activity["type"] || "").upcase
      INFLOW_TYPES.include?(type) ? -raw_amount.abs : raw_amount.abs
    end

    def extract_symbol(activity)
      value = activity.dig("symbol", "symbol")
      return value if value.is_a?(String) && value.present?
      # Fallback: if symbol is a Hash (unexpected wrapping)
      return value["symbol"] if value.is_a?(Hash)
      activity["symbol"]&.to_s.presence
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
