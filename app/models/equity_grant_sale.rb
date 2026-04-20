class EquityGrantSale < ApplicationRecord
  belongs_to :equity_grant
  belongs_to :entry, optional: true

  validates :date, presence: true
  validates :units, presence: true, numericality: { greater_than: 0 }
  validates :proceeds, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
end
