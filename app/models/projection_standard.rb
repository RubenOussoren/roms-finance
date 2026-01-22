# 🇨🇦 PAG 2025 and CFP Board projection standards
class ProjectionStandard < ApplicationRecord
  belongs_to :jurisdiction
  has_many :projection_assumptions, dependent: :nullify

  validates :name, presence: true
  validates :code, presence: true, uniqueness: { scope: :jurisdiction_id }
  validates :effective_year, presence: true,
                             numericality: { only_integer: true, greater_than: 2000 }

  validates :equity_return, numericality: { allow_nil: true }
  validates :fixed_income_return, numericality: { allow_nil: true }
  validates :cash_return, numericality: { allow_nil: true }
  validates :inflation_rate, numericality: { allow_nil: true }

  scope :current, -> { order(effective_year: :desc).first }
  scope :for_year, ->(year) { where("effective_year <= ?", year).order(effective_year: :desc) }

  # 🇨🇦 PAG 2025 default values
  PAG_2025_DEFAULTS = {
    equity_return: 0.0628,       # 6.28% nominal
    fixed_income_return: 0.0409, # 4.09% nominal
    cash_return: 0.0295,         # 2.95% nominal
    inflation_rate: 0.021,       # 2.10%
    volatility_equity: 0.18,     # 18% standard deviation
    volatility_fixed_income: 0.05 # 5% standard deviation
  }.freeze

  def blended_return(equity_weight: 0.6, fixed_income_weight: 0.3, cash_weight: 0.1)
    (equity_return.to_d * equity_weight) +
      (fixed_income_return.to_d * fixed_income_weight) +
      (cash_return.to_d * cash_weight)
  end

  def real_return(nominal_return: nil)
    rate = nominal_return || blended_return
    ((1 + rate) / (1 + inflation_rate.to_d)) - 1
  end

  def pag_compliant?
    code == "PAG_2025"
  end

  def compliance_badge
    return "Prepared using FP Canada PAG 2025" if pag_compliant?
    "Custom assumptions"
  end

  class << self
    def pag_2025
      find_by(code: "PAG_2025")
    end
  end
end
