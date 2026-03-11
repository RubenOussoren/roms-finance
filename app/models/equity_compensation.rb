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
end
