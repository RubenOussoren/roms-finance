class EquityGrant < ApplicationRecord
  belongs_to :equity_compensation
  belongs_to :security

  validates :grant_type, presence: true, inclusion: { in: %w[rsu stock_option] }
  validates :total_units, presence: true, numericality: { greater_than: 0 }
  validates :vesting_period_months, presence: true, numericality: { greater_than: 0 }
  validates :vesting_frequency, presence: true, inclusion: { in: %w[monthly quarterly annually] }
  validates :grant_date, presence: true
  validates :cliff_months, numericality: { greater_than_or_equal_to: 0 }, allow_nil: false

  validates :strike_price, presence: true, if: :stock_option?
  validates :expiration_date, presence: true, if: :stock_option?
  validates :option_type, presence: true, inclusion: { in: %w[iso nso] }, if: :stock_option?

  POST_TERMINATION_EXERCISE_DAYS = 90

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

  def vested_units(as_of: Date.current)
    return 0 if as_of < grant_date

    effective_as_of = terminated? ? [ as_of, termination_date ].min : as_of
    elapsed = months_between(grant_date, effective_as_of)
    return 0 if elapsed < cliff_months

    freq = frequency_in_months
    periods_total = (vesting_period_months / freq.to_f).ceil
    periods_elapsed = [elapsed / freq, periods_total].min
    (total_units * periods_elapsed / periods_total.to_d).floor(4)
  end

  def unvested_units(as_of: Date.current)
    total_units - vested_units(as_of: as_of)
  end

  def current_price
    security.current_price
  end

  def price_amount
    cp = current_price
    return 0 if cp.nil?
    cp.respond_to?(:amount) ? cp.amount : cp.to_d
  end

  def vested_value(as_of: Date.current)
    return 0 if expired_at?(as_of)
    units = vested_units(as_of: as_of)
    if stock_option?
      units * [price_amount - (strike_price || 0), 0].max
    else
      units * price_amount
    end
  end

  def unvested_value(as_of: Date.current)
    return 0 if expired_at?(as_of)
    units = unvested_units(as_of: as_of)
    if stock_option?
      units * [price_amount - (strike_price || 0), 0].max
    else
      units * price_amount
    end
  end

  def intrinsic_value_per_unit
    return nil unless stock_option?
    [price_amount - (strike_price || 0), 0].max
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
    return nil if fully_vested?(as_of: as_of)
    return nil if terminated? && as_of >= termination_date

    freq = frequency_in_months
    periods_total = (vesting_period_months / freq.to_f).ceil

    (1..periods_total).each do |period|
      vest_date = grant_date + (period * freq).months
      next unless vest_date > as_of
      return nil if terminated? && vest_date > termination_date
      return vest_date
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

  private

    def expired_at?(as_of)
      # Stock options expire at expiration_date
      return true if stock_option? && expiration_date.present? && as_of > expiration_date
      # Terminated stock options expire after exercise deadline
      return true if stock_option? && terminated? && as_of > exercise_deadline
      false
    end

    def months_between(start_date, end_date)
      (end_date.year - start_date.year) * 12 + (end_date.month - start_date.month)
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
