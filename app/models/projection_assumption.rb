# User-customizable projection assumptions
class ProjectionAssumption < ApplicationRecord
  belongs_to :family
  belongs_to :projection_standard, optional: true
  has_many :account_projections, dependent: :nullify

  validates :name, presence: true
  validates :expected_return, numericality: { allow_nil: true }
  validates :inflation_rate, numericality: { allow_nil: true }
  validates :monthly_contribution, numericality: { allow_nil: true }
  validates :volatility, numericality: { allow_nil: true }

  scope :active, -> { where(is_active: true) }
  scope :using_pag, -> { where(use_pag_defaults: true) }

  def effective_return
    if use_pag_defaults && projection_standard.present?
      projection_standard.blended_return
    else
      expected_return.to_d
    end
  end

  def effective_inflation
    if use_pag_defaults && projection_standard.present?
      projection_standard.inflation_rate
    else
      inflation_rate.to_d
    end
  end

  def effective_volatility
    if use_pag_defaults && projection_standard.present?
      projection_standard.volatility_equity
    else
      volatility.to_d
    end
  end

  def real_return
    ((1 + effective_return) / (1 + effective_inflation)) - 1
  end

  def pag_compliant?
    use_pag_defaults && projection_standard&.pag_compliant?
  end

  def compliance_badge
    return projection_standard.compliance_badge if pag_compliant?
    "Custom assumptions"
  end

  def apply_pag_defaults!
    return unless projection_standard.present?

    update!(
      expected_return: projection_standard.blended_return,
      inflation_rate: projection_standard.inflation_rate,
      volatility: projection_standard.volatility_equity,
      use_pag_defaults: true
    )
  end

  class << self
    def default_for(family)
      family.projection_assumptions.active.first ||
        create_default_for(family)
    end

    def create_default_for(family)
      jurisdiction = Jurisdiction.default
      standard = jurisdiction&.current_projection_standard

      create!(
        family: family,
        projection_standard: standard,
        name: "Default Assumptions",
        expected_return: standard&.blended_return || 0.06,
        inflation_rate: standard&.inflation_rate || 0.02,
        volatility: standard&.volatility_equity || 0.18,
        use_pag_defaults: standard.present?,
        is_active: true
      )
    end
  end
end
