# 🇨🇦 Canadian-first jurisdiction registry
# 🔧 Extensibility: Architecture supports future US/UK expansion
class Jurisdiction < ApplicationRecord
  has_many :projection_standards, dependent: :destroy

  validates :country_code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :currency_code, presence: true

  scope :canada, -> { find_by(country_code: "CA") }
  scope :active, -> { all }

  # 🇨🇦 Canadian tax-specific helper
  def interest_deductible?
    interest_deductible
  end

  # 🇨🇦 Smith Manoeuvre availability
  def supports_smith_manoeuvre?
    has_smith_manoeuvre
  end

  # 🇨🇦 Check if PAG 2025 standard is available
  def pag_compliant?
    projection_standards.exists?(code: "PAG_2025")
  end

  def current_projection_standard
    projection_standards.order(effective_year: :desc).first
  end

  def marginal_tax_rate(income:)
    brackets = tax_config["brackets"] || []
    return 0 if brackets.empty?

    applicable_rate = 0
    brackets.each do |bracket|
      if income > bracket["min"]
        applicable_rate = bracket["rate"]
      end
    end

    applicable_rate.to_d
  end

  class << self
    def default
      find_by(country_code: "CA") || first
    end

    def for_country(code)
      find_by(country_code: code.to_s.upcase)
    end
  end
end
