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

  def total_withdrawals
    acct = account
    return 0 unless acct

    acct.entries
      .where(entryable_type: "Transaction", currency: acct.currency)
      .where("amount > 0")
      .sum(:amount)
  end

  VESTING_ENTRY_PREFIX = "Vesting: "

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

    # Wrap delete + create in a transaction for atomicity (I4 fix)
    ActiveRecord::Base.transaction do
      # Delete old auto-generated vesting entries and opening balance
      acct.entries.where(entryable_type: "Valuation")
        .where("name LIKE ? OR name = ?", "#{VESTING_ENTRY_PREFIX}%", "Opening balance")
        .destroy_all

      # Find dates that already have manual valuations (don't overwrite)
      manual_dates = acct.entries.where(entryable_type: "Valuation")
        .where.not("name LIKE ?", "#{VESTING_ENTRY_PREFIX}%")
        .pluck(:date).to_set

      # Create valuation entries for each vesting date
      all_dates.each do |date|
        next if manual_dates.include?(date)

        total = grants.sum do |g|
          unit_price = price_cache[[ g.security_id, date ]]
          next 0 if unit_price.nil?
          g.vested_value(as_of: date, price: unit_price.to_d)
        end

        next if total.zero?

        acct.entries.create!(
          name: "#{VESTING_ENTRY_PREFIX}#{date.strftime('%b %Y')}",
          date: date,
          amount: total,
          currency: acct.currency,
          entryable: Valuation.new(kind: "reconciliation")
        )
      end

      # Update current balance: vested value minus any withdrawals (e.g., sold GSUs transferred out)
      acct.update!(balance: [ total_vested_value - total_withdrawals, 0 ].max)
    end

    # Trigger sync outside the transaction so job only fires on commit (I1 fix)
    acct.sync_later
  end
end
