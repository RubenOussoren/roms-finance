class EquityCompensation < ApplicationRecord
  include Accountable

  SUBTYPES = {
    "rsu" => { short: "RSU", long: "Restricted Stock Units (RSU)" },
    "stock_option" => { short: "Stock Option", long: "Stock Option" }
  }.freeze

  has_many :equity_grants, dependent: :destroy
  accepts_nested_attributes_for :equity_grants, allow_destroy: true

  class << self
    def color
      "#7C3AED"
    end

    def classification
      "asset"
    end

    def icon
      "award"
    end

    def display_name
      "Equity Compensation"
    end
  end

  def total_vested_units(as_of: Date.current)
    equity_grants.sum { |g| g.vested_units(as_of: as_of) }
  end

  def total_unvested_units(as_of: Date.current)
    equity_grants.sum { |g| g.unvested_units(as_of: as_of) }
  end

  def total_vested_value(as_of: Date.current)
    currency = account&.currency
    equity_grants.sum { |g| g.vested_value(as_of: as_of, currency: currency) }
  end

  def total_remaining_value(as_of: Date.current)
    currency = account&.currency
    equity_grants.sum { |g| g.remaining_value(as_of: as_of, currency: currency) }
  end

  def total_unvested_value(as_of: Date.current)
    currency = account&.currency
    equity_grants.sum { |g| g.unvested_value(as_of: as_of, currency: currency) }
  end

  def total_unrealized_gain_loss(as_of: Date.current)
    currency = account&.currency
    grants_with_price = equity_grants.select { |g| g.grant_price.present? }
    return nil if grants_with_price.empty?
    grants_with_price.sum { |g| g.unrealized_gain_loss(as_of: as_of, currency: currency) }
  end

  def total_unrealized_gain_loss_trend(as_of: Date.current)
    total_gl = total_unrealized_gain_loss(as_of: as_of)
    return nil if total_gl.nil?

    vested = total_vested_value(as_of: as_of)
    Trend.new(current: vested, previous: vested - total_gl)
  end

  def next_vesting_event(as_of: Date.current)
    equity_grants.filter_map { |g| g.next_vest_date(as_of: as_of) }.min
  end

  # Hook fired by Account::Anchorable#set_opening_anchor_balance. The opening balance
  # is baked into every vesting valuation, so an edit must refresh them to avoid drift.
  def on_opening_balance_changed
    regenerate_vesting_valuations!
  end

  def total_withdrawals
    acct = account
    return 0 unless acct

    acct.entries
      .where(entryable_type: "Transaction", currency: acct.currency)
      .where("amount > 0")
      .sum(:amount)
  end

  VESTING_ENTRY_PREFIX = "Vesting: "

  # Backfills EquityGrantSale rows for historical positive-amount Transaction entries
  # on this account that aren't already linked to a sale. Uses FIFO by grant_date and
  # derives units from the historical price on the entry date. Idempotent.
  def backfill_sales_from_transactions!
    acct = account
    return unless acct

    existing_entry_ids = EquityGrantSale.where(equity_grant: equity_grants).where.not(entry_id: nil).pluck(:entry_id).to_set

    sales_created = 0
    acct.entries
      .where(entryable_type: "Transaction", currency: acct.currency)
      .where("amount > 0")
      .order(:date, :created_at)
      .each do |entry|
        next if existing_entry_ids.include?(entry.id)

        grant = equity_grants.includes(:security).order(:grant_date)
          .find { |g| g.vested_units_remaining(as_of: entry.date) > 0 }
        next if grant.nil?

        price = grant.security.find_or_fetch_price(date: entry.date, cache: false)
        unit_price = price&.price&.to_d || grant.security.current_price&.amount&.to_d
        next if unit_price.nil? || unit_price <= 0

        divisor = if grant.stock_option?
          spread = [ unit_price - (grant.strike_price || 0).to_d, 0 ].max
          spread > 0 ? spread : nil
        else
          unit_price
        end
        next if divisor.nil?

        units = entry.amount.abs.to_d / divisor

        EquityGrantSale.create!(
          equity_grant: grant,
          entry: entry,
          date: entry.date,
          units: units,
          proceeds: entry.amount.abs,
          currency: acct.currency
        )
        sales_created += 1
      end

    sales_created
  end

  def regenerate_vesting_valuations!
    acct = account
    return unless acct

    grants = equity_grants.includes(:security).to_a
    return if grants.empty?

    # Collect all vesting dates across grants
    all_dates = grants.flat_map { |g| g.vesting_dates(up_to: Date.current) }.uniq.sort
    return if all_dates.empty?

    # Batch-fetch historical prices for each security
    securities = grants.map(&:security).uniq
    securities.each do |sec|
      sec.import_provider_prices(start_date: all_dates.first, end_date: Date.current)
    rescue => e
      Rails.logger.warn("Failed to import prices for #{sec.ticker}: #{e.message}")
    end

    # Build price cache: { [security_id, date] => price_amount }
    # Include nearest-earlier prices for dates without exact matches (I2 fix)
    price_cache = {}
    securities.each do |sec|
      sec.prices.where(date: all_dates).find_each do |sp|
        price_cache[[ sec.id, sp.date ]] = sp.price
      end

      # Pre-load nearest price for any dates missing from the cache (backward first, then forward).
      # Only use prices within 7 days to avoid stale LOCF gap-filled values distorting historical valuations.
      missing_dates = all_dates.reject { |d| price_cache.key?([ sec.id, d ]) }
      missing_dates.each do |date|
        nearest = sec.prices.where(date: (date - 7.days)..date)
          .order(date: :desc).limit(1).pick(:price, :date)
        nearest ||= sec.prices.where(date: date..(date + 7.days))
          .order(date: :asc).limit(1).pick(:price, :date)
        price_cache[[ sec.id, date ]] = nearest&.first
      end
    end

    # Convert cached prices to account currency if needed
    securities.each do |sec|
      price_currency = sec.prices.pick(:currency) || "USD"
      next if price_currency == acct.currency

      price_cache.each do |(sec_id, date), price|
        next unless sec_id == sec.id && price.present?
        price_money = Money.new(price, price_currency)
        price_cache[[ sec_id, date ]] = price_money.exchange_to(acct.currency, date: date, fallback_rate: 1).amount
      end
    end

    opening_balance = acct.opening_anchor_balance || 0

    # Wrap delete + create in a transaction for atomicity (I4 fix)
    ActiveRecord::Base.transaction do
      # Delete only auto-generated vesting entries. The opening anchor is preserved
      # so the user's entered Starting Balance survives grant edits.
      acct.entries.where(entryable_type: "Valuation")
        .where("name LIKE ?", "#{VESTING_ENTRY_PREFIX}%")
        .destroy_all

      # Find dates that already have manual valuations (don't overwrite)
      manual_dates = acct.entries.where(entryable_type: "Valuation")
        .where.not("name LIKE ?", "#{VESTING_ENTRY_PREFIX}%")
        .pluck(:date).to_set

      # Create valuation entries for each vesting date. Amount is opening balance
      # plus sale-aware remaining grant value (units already sold by `date` are excluded).
      all_dates.each do |date|
        next if manual_dates.include?(date)

        grant_total = grants.sum do |g|
          unit_price = price_cache[[ g.security_id, date ]]
          next 0 if unit_price.nil?
          g.remaining_value(as_of: date, price: unit_price.to_d)
        end

        total = opening_balance + grant_total
        next if total.zero?

        acct.entries.create!(
          name: "#{VESTING_ENTRY_PREFIX}#{date.strftime('%b %Y')}",
          date: date,
          amount: total,
          currency: acct.currency,
          entryable: Valuation.new(kind: "reconciliation")
        )
      end

      # Current balance: opening balance (shares outside grants) plus remaining
      # grant-derived value (vested minus sold, at current price).
      acct.update!(balance: [ opening_balance + total_remaining_value, 0 ].max)
    end

    # Run the sync inline so the balances table is populated before the caller returns.
    # Avoids Sidekiq races (stalled workers, cold restarts, duplicate enqueued jobs)
    # that previously left the Chart + Activity views empty.
    acct.sync_now
  end
end
