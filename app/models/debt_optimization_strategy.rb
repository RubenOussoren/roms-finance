# 🇨🇦 Canadian Modified Smith Manoeuvre Strategy
# 🔧 Extensibility: Architecture supports future US/UK debt optimization strategies
class DebtOptimizationStrategy < ApplicationRecord
  belongs_to :family
  belongs_to :jurisdiction, optional: true
  belongs_to :primary_mortgage, class_name: "Account", optional: true
  belongs_to :heloc, class_name: "Account", optional: true
  belongs_to :rental_mortgage, class_name: "Account", optional: true

  has_many :ledger_entries, class_name: "DebtOptimizationLedgerEntry", dependent: :destroy
  has_many :auto_stop_rules, class_name: "DebtOptimizationStrategy::AutoStopRule", dependent: :destroy

  DEFAULT_PROVINCE = "ON".freeze

  CANADIAN_PROVINCES = {
    "AB" => "Alberta",
    "BC" => "British Columbia",
    "MB" => "Manitoba",
    "NB" => "New Brunswick",
    "NL" => "Newfoundland and Labrador",
    "NS" => "Nova Scotia",
    "NT" => "Northwest Territories",
    "NU" => "Nunavut",
    "ON" => "Ontario",
    "PE" => "Prince Edward Island",
    "QC" => "Quebec",
    "SK" => "Saskatchewan",
    "YT" => "Yukon"
  }.freeze

  # 🇨🇦 Strategy types - Canadian-first with extensibility hooks
  # 🔧 Future: us_heloc_arbitrage, uk_offset_mortgage
  enum :strategy_type, {
    baseline: "baseline",
    modified_smith: "modified_smith"
  }

  enum :status, {
    draft: "draft",
    simulated: "simulated",
    active: "active",
    completed: "completed"
  }

  validates :name, presence: true
  validates :family, presence: true
  validates :strategy_type, presence: true
  validates :simulation_months, numericality: { greater_than: 0, less_than_or_equal_to: 600 }
  validates :province, inclusion: { in: CANADIAN_PROVINCES.keys, allow_blank: true }

  validate :validate_accounts_for_strategy
  validate :validate_jurisdiction_supports_strategy

  scope :for_family, ->(family) { where(family: family) }
  scope :simulated_or_active, -> { where(status: %w[simulated active]) }

  # Factory method to get appropriate simulator
  def simulator
    case strategy_type
    when "baseline"
      BaselineSimulator.new(self)
    when "modified_smith"
      CanadianSmithManoeuvrSimulator.new(self)
    else
      raise ArgumentError, "Unknown strategy type: #{strategy_type}"
    end
  end

  def run_simulation!
    transaction do
      # Clear existing ledger entries
      ledger_entries.destroy_all

      # Run both baseline and strategy simulations
      simulator.simulate!

      # Update cached results
      calculate_summary_metrics!

      self.last_simulated_at = Time.current
      self.status = "simulated"
      save!
    end
  end

  def baseline_entries
    ledger_entries.where(scenario_type: "baseline").order(:month_number)
  end

  def strategy_entries
    ledger_entries.where(scenario_type: "modified_smith").order(:month_number)
  end

  def prepay_only_entries
    ledger_entries.where(scenario_type: "prepay_only").order(:month_number)
  end

  def chart_series_builder
    @chart_series_builder ||= ChartSeriesBuilder.new(self)
  end

  def audit_trail
    @audit_trail ||= AuditTrail.new(self)
  end

  # Check all auto-stop rules against a ledger entry
  def check_auto_stop_rules(ledger_entry)
    auto_stop_rules.enabled.each do |rule|
      if rule.triggered?(ledger_entry)
        return { triggered: true, rule: rule }
      end
    end
    { triggered: false, rule: nil }
  end

  # Get the combined federal + provincial marginal tax rate for this strategy's family
  def effective_marginal_tax_rate
    family_income = family&.respond_to?(:annual_income) ? family.annual_income : 100_000
    province_code = effective_province

    rate = effective_jurisdiction&.combined_marginal_rate(income: family_income, province: province_code)
    rate.present? && rate > 0 ? rate : BigDecimal("0.4")
  end

  # Resolve the effective province, falling back to DEFAULT_PROVINCE when the
  # selected province has no bracket data in the jurisdiction.
  def effective_province
    resolved = province.presence || DEFAULT_PROVINCE

    if !effective_jurisdiction&.available_provinces&.include?(resolved)
      Rails.logger.warn("Province #{resolved} has no bracket data, defaulting to #{DEFAULT_PROVINCE}")
      resolved = DEFAULT_PROVINCE
    end

    resolved
  end

  # Calculate HELOC available credit
  def heloc_available_credit
    return 0 unless heloc.present?

    credit_limit = effective_heloc_limit
    current_balance = heloc.balance.abs
    [ credit_limit - current_balance, 0 ].max
  end

  # Get effective HELOC limit (considers max limit cap)
  def effective_heloc_limit
    base_limit = heloc&.accountable&.credit_limit || 0
    return base_limit unless heloc_max_limit.present? && heloc_max_limit > 0

    [ base_limit, heloc_max_limit ].min
  end

  # Check if this strategy uses a readvanceable HELOC
  def readvanceable_heloc?
    heloc_readvanceable == true
  end

  private

    def calculate_summary_metrics!
      baseline_final = baseline_entries.last
      strategy_final = strategy_entries.where(strategy_stopped: false).last || strategy_entries.last

      return unless baseline_final && strategy_final

      # Mortgage-only interest comparison (excludes HELOC — always positive if strategy works)
      baseline_mortgage_interest = baseline_entries.sum(&:primary_mortgage_interest) +
                                   baseline_entries.sum(&:rental_mortgage_interest)
      strategy_mortgage_interest = strategy_entries.sum(&:primary_mortgage_interest) +
                                   strategy_entries.sum(&:rental_mortgage_interest)
      strategy_heloc_interest = strategy_entries.sum(&:heloc_interest)

      self.total_interest_saved = baseline_mortgage_interest - strategy_mortgage_interest

      # Total tax benefit from deductible interest
      self.total_tax_benefit = strategy_final.cumulative_tax_benefit

      # Net economic benefit = mortgage savings + tax benefit - HELOC cost
      self.net_benefit = total_interest_saved + total_tax_benefit - strategy_heloc_interest

      # Months accelerated = how many months earlier primary mortgage is paid off
      baseline_payoff_month = baseline_entries.find { |e| e.primary_mortgage_balance <= 0 }&.month_number
      strategy_payoff_month = strategy_entries.find { |e| e.primary_mortgage_balance <= 0 }&.month_number

      if baseline_payoff_month && strategy_payoff_month
        self.months_accelerated = baseline_payoff_month - strategy_payoff_month
      end
    end

    def validate_accounts_for_strategy
      return if strategy_type == "baseline"

      if modified_smith?
        errors.add(:primary_mortgage, "is required for Modified Smith Manoeuvre") if primary_mortgage.blank?
        errors.add(:heloc, "is required for Modified Smith Manoeuvre") if heloc.blank?
        errors.add(:rental_mortgage, "is required for Modified Smith Manoeuvre") if rental_mortgage.blank?
      end
    end

    def validate_jurisdiction_supports_strategy
      return if strategy_type == "baseline"
      return if jurisdiction.blank? && family&.country.blank?

      if modified_smith? && !supports_smith_manoeuvre?
        errors.add(:strategy_type, "Smith Manoeuvre is not supported in this jurisdiction")
      end
    end

    # Get the effective jurisdiction (uses explicit jurisdiction or family's country)
    def effective_jurisdiction
      return jurisdiction if jurisdiction.present?
      Jurisdiction.for_country(family&.country) || Jurisdiction.default
    end

    # Check if Smith Manoeuvre is supported
    def supports_smith_manoeuvre?
      effective_jurisdiction&.supports_smith_manoeuvre? || false
    end
end
