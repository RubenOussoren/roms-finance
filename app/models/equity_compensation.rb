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
    equity_grants.sum { |g| g.vested_value(as_of: as_of) }
  end

  def total_unvested_value(as_of: Date.current)
    equity_grants.sum { |g| g.unvested_value(as_of: as_of) }
  end

  def next_vesting_event(as_of: Date.current)
    equity_grants.filter_map { |g| g.next_vest_date(as_of: as_of) }.min
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

      # Pre-load nearest-earlier price for any dates missing from the cache
      missing_dates = all_dates.reject { |d| price_cache.key?([ sec.id, d ]) }
      missing_dates.each do |date|
        price_cache[[ sec.id, date ]] = sec.prices.where("date <= ?", date)
          .order(date: :desc).limit(1).pick(:price)
      end
    end

    # Wrap delete + create in a transaction for atomicity (I4 fix)
    ActiveRecord::Base.transaction do
      # Delete old auto-generated vesting entries
      acct.entries.where(entryable_type: "Valuation")
        .where("name LIKE ?", "#{VESTING_ENTRY_PREFIX}%")
        .destroy_all

      # Find dates that already have manual valuations (don't overwrite)
      manual_dates = acct.entries.where(entryable_type: "Valuation")
        .where.not("name LIKE ?", "#{VESTING_ENTRY_PREFIX}%")
        .pluck(:date).to_set

      # Create valuation entries for each vesting date
      all_dates.each do |date|
        next if manual_dates.include?(date)

        total = grants.sum do |g|
          unit_price = price_cache[[ g.security_id, date ]] || 0
          g.vested_value(as_of: date, price: unit_price.to_d)
        end

        acct.entries.create!(
          name: "#{VESTING_ENTRY_PREFIX}#{date.strftime('%b %Y')}",
          date: date,
          amount: total,
          currency: acct.currency,
          entryable: Valuation.new(kind: "reconciliation")
        )
      end

      # Update current balance
      acct.update!(balance: total_vested_value)
    end

    # Trigger sync outside the transaction so job only fires on commit (I1 fix)
    acct.sync_later
  end
end
