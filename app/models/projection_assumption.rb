# User-customizable projection assumptions
class ProjectionAssumption < ApplicationRecord
  belongs_to :family
  belongs_to :account, optional: true
  belongs_to :projection_standard, optional: true
  has_many :account_projections, class_name: "Account::Projection", dependent: :nullify

  validates :name, presence: true
  validate :account_belongs_to_family
  validates :expected_return, numericality: {
    greater_than_or_equal_to: -0.5,
    less_than_or_equal_to: 0.5,
    allow_nil: true
  }
  validates :volatility, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 1.0,
    allow_nil: true
  }
  validates :inflation_rate, numericality: {
    greater_than_or_equal_to: -0.2,
    less_than_or_equal_to: 0.3,
    allow_nil: true
  }
  validates :monthly_contribution, numericality: {
    greater_than_or_equal_to: 0,
    allow_nil: true
  }
  validates :extra_monthly_payment, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :target_payoff_date, comparison: { greater_than: -> { Date.current } }, allow_nil: true

  scope :active, -> { where(is_active: true) }
  scope :using_pag, -> { where(use_pag_defaults: true) }
  scope :family_default, -> { where(account_id: nil) }
  scope :for_account_id, ->(account_id) { where(account_id: account_id) }

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

  def effective_extra_payment
    extra_monthly_payment.to_d
  end

  def debt_settings?
    extra_monthly_payment&.positive? || target_payoff_date.present?
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
      family.projection_assumptions.family_default.active.first ||
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

    # Returns account-specific assumption or falls back to family default
    def for_account(account)
      account.projection_assumption || default_for(account.family)
    end

    # Create or update account-specific settings
    def create_for_account(account, overrides = {})
      existing = account.projection_assumption
      return existing.tap { |a| a.update!(overrides) } if existing

      family_default = default_for(account.family)
      create!(
        family: account.family,
        account: account,
        projection_standard: family_default.projection_standard,
        name: "#{account.name} Settings",
        expected_return: overrides[:expected_return] || family_default.expected_return,
        inflation_rate: overrides[:inflation_rate] || family_default.inflation_rate,
        volatility: overrides[:volatility] || family_default.volatility,
        monthly_contribution: overrides[:monthly_contribution] || family_default.monthly_contribution,
        use_pag_defaults: overrides.key?(:use_pag_defaults) ? overrides[:use_pag_defaults] : family_default.use_pag_defaults,
        is_active: true
      )
    end
  end

  private

    def account_belongs_to_family
      return unless account.present? && family.present?
      errors.add(:account, "must belong to the same family") unless account.family_id == family_id
    end
end
