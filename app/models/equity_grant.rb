class EquityGrant < ApplicationRecord
  belongs_to :equity_compensation
  belongs_to :security
  has_many :sales, class_name: "EquityGrantSale", dependent: :destroy

  validates :grant_type, presence: true, inclusion: { in: %w[rsu stock_option] }
  validates :total_units, presence: true, numericality: { greater_than: 0 }
  validates :vesting_period_months, presence: true, numericality: { greater_than: 0 }
  validates :vesting_frequency, presence: true, inclusion: { in: %w[monthly quarterly annually] }
  validates :grant_date, presence: true
  validates :cliff_months, numericality: { greater_than_or_equal_to: 0 }, allow_nil: false

  validates :grant_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :strike_price, presence: true, if: :stock_option?
  validates :expiration_date, presence: true, if: :stock_option?
  validates :option_type, presence: true, inclusion: { in: %w[iso nso] }, if: :stock_option?

  POST_TERMINATION_EXERCISE_DAYS = 90

  # FIFO for inferred sales. Same-date grants resolve to the earlier-created grant,
  # then the lower ID, so reprocessing the same data always picks the same grant.
  scope :in_sale_order, -> { order(:grant_date, :created_at, :id) }

  def stock_option?
    grant_type == "stock_option"
  end

  def rsu?
    grant_type == "rsu"
  end

  def terminated?
    termination_date.present?
  end

  def exercise_deadline
    return nil unless terminated? && stock_option?
    termination_date + POST_TERMINATION_EXERCISE_DAYS.days
  end

  def withdrawn_units(as_of: Date.current)
    sales.where("date <= ?", as_of).sum(:units)
  end

  def vested_units_remaining(as_of: Date.current)
    [ vested_units(as_of: as_of) - withdrawn_units(as_of: as_of), 0 ].max
  end

  def remaining_value(as_of: Date.current, price: nil, currency: nil)
    return 0 if expired_at?(as_of)
    units = vested_units_remaining(as_of: as_of)
    return 0 if units.zero?
    unit_price = price || price_amount(currency: currency)
    if stock_option?
      units * [ unit_price - (strike_price || 0), 0 ].max
    else
      units * unit_price
    end
  end

  def vested_units(as_of: Date.current)
    periods_elapsed = 0
    each_vesting_event do |date, period|
      break if date > as_of
      periods_elapsed = period
    end

    return 0 if periods_elapsed.zero?

    (total_units * periods_elapsed / vesting_period_count.to_d).floor(4)
  end

  def unvested_units(as_of: Date.current)
    total_units - vested_units(as_of: as_of)
  end

  def current_price
    security.current_price
  end

  def price_amount(currency: nil)
    cp = current_price
    return 0 if cp.nil?
    if currency && cp.respond_to?(:exchange_to)
      cp.exchange_to(currency, fallback_rate: 1).amount
    else
      cp.respond_to?(:amount) ? cp.amount : cp.to_d
    end
  end

  def vested_value(as_of: Date.current, price: nil, currency: nil)
    return 0 if expired_at?(as_of)
    units = vested_units(as_of: as_of)
    unit_price = price || price_amount(currency: currency)
    if stock_option?
      units * [ unit_price - (strike_price || 0), 0 ].max
    else
      units * unit_price
    end
  end

  def unvested_value(as_of: Date.current, price: nil, currency: nil)
    return 0 if expired_at?(as_of)
    units = unvested_units(as_of: as_of)
    unit_price = price || price_amount(currency: currency)
    if stock_option?
      units * [ unit_price - (strike_price || 0), 0 ].max
    else
      units * unit_price
    end
  end

  def vesting_dates(up_to: Date.current)
    dates = []
    each_vesting_event do |date, _period|
      break if date > up_to
      dates << date
    end
    dates
  end

  def intrinsic_value_per_unit
    return nil unless stock_option?
    [ price_amount - (strike_price || 0), 0 ].max
  end

  def exercise_cost
    return nil unless stock_option?
    vested_units * (strike_price || 0)
  end

  def gross_proceeds
    vested_value
  end

  def estimated_tax(as_of: Date.current)
    rate = effective_tax_rate
    return 0 if rate.nil? || rate.zero?
    vested_value(as_of: as_of) * (rate / 100.0)
  end

  def net_proceeds(as_of: Date.current)
    vested_value(as_of: as_of) - estimated_tax(as_of: as_of)
  end

  def next_vest_date(as_of: Date.current)
    each_vesting_event do |date, _period|
      return date if date > as_of
    end

    nil
  end

  def fully_vested?(as_of: Date.current)
    vested_units(as_of: as_of) >= total_units
  end

  def vesting_progress(as_of: Date.current)
    return 0 if total_units.zero?
    (vested_units(as_of: as_of) / total_units.to_d * 100).round(1)
  end

  def grant_value(currency: nil)
    return nil unless grant_price.present?
    total_units * converted_grant_price(currency: currency)
  end

  def unrealized_gain_loss(as_of: Date.current, currency: nil)
    return nil unless grant_price.present?
    units = vested_units(as_of: as_of)
    return 0 if units.zero?
    (price_amount(currency: currency) - converted_grant_price(currency: currency)) * units
  end

  def unrealized_gain_loss_trend(as_of: Date.current, currency: nil)
    return nil unless grant_price.present?
    units = vested_units(as_of: as_of)
    return nil if units.zero?

    current = price_amount(currency: currency) * units
    previous = converted_grant_price(currency: currency) * units
    Trend.new(current: current, previous: previous)
  end

  private

    def converted_grant_price(currency: nil)
      return grant_price unless currency && current_price&.respond_to?(:currency)
      Money.new(grant_price, current_price.currency).exchange_to(currency, fallback_rate: 1).amount
    end

    def expired_at?(as_of)
      # Stock options expire at expiration_date
      return true if stock_option? && expiration_date.present? && as_of > expiration_date
      # Terminated stock options expire after exercise deadline
      return true if stock_option? && terminated? && as_of > exercise_deadline
      false
    end

    def each_vesting_event
      frequency = frequency_in_months
      first_period = [ cliff_months.ceildiv(frequency), 1 ].max

      (first_period..vesting_period_count).each do |period|
        # Always shift from the grant date so a short month does not move later anniversaries.
        date = grant_date >> (period * frequency)
        break if terminated? && date > termination_date

        # Keep the original period number so the first eligible vest includes the cliff catch-up.
        yield date, period
      end
    end

    def vesting_period_count
      vesting_period_months.ceildiv(frequency_in_months)
    end

    def frequency_in_months
      case vesting_frequency
      when "monthly" then 1
      when "quarterly" then 3
      when "annually" then 12
      else 1
      end
    end

    def effective_tax_rate
      estimated_tax_rate
    end
end
