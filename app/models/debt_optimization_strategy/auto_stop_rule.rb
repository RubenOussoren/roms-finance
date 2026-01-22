# 🇨🇦 Auto-stop rules for debt optimization strategies
# These rules determine when a strategy simulation should stop
class DebtOptimizationStrategy::AutoStopRule < ApplicationRecord
  self.table_name = "debt_optimization_auto_stop_rules"

  belongs_to :debt_optimization_strategy

  # Rule types that can trigger strategy stop
  # 🔧 Extensibility: Add more rule types for different jurisdictions
  RULE_TYPES = {
    heloc_limit_percentage: "heloc_limit_percentage",           # Stop when HELOC reaches X% of limit
    heloc_balance_threshold: "heloc_balance_threshold",         # Stop when HELOC balance reaches X amount
    primary_paid_off: "primary_paid_off",                       # Stop when primary mortgage is paid off
    all_debt_paid_off: "all_debt_paid_off",                     # Stop when all debt is paid off
    max_months: "max_months",                                   # Stop after X months
    negative_cash_flow: "negative_cash_flow",                   # Stop if net cash flow becomes negative
    heloc_interest_exceeds_benefit: "heloc_interest_exceeds_benefit" # Stop if HELOC interest > tax benefit
  }.freeze

  enum :rule_type, RULE_TYPES, prefix: true

  validates :rule_type, presence: true
  validates :threshold_value, numericality: true, allow_nil: true
  validates :threshold_unit, inclusion: { in: %w[percentage amount months] }, allow_nil: true

  scope :enabled, -> { where(enabled: true) }

  # Check if this rule is triggered by the given ledger entry
  def triggered?(ledger_entry)
    return false unless enabled?

    case rule_type
    when "heloc_limit_percentage"
      check_heloc_limit_percentage(ledger_entry)
    when "heloc_balance_threshold"
      check_heloc_balance_threshold(ledger_entry)
    when "primary_paid_off"
      check_primary_paid_off(ledger_entry)
    when "all_debt_paid_off"
      check_all_debt_paid_off(ledger_entry)
    when "max_months"
      check_max_months(ledger_entry)
    when "negative_cash_flow"
      check_negative_cash_flow(ledger_entry)
    when "heloc_interest_exceeds_benefit"
      check_heloc_interest_exceeds_benefit(ledger_entry)
    else
      false
    end
  end

  # Human-readable description of the rule
  def description
    case rule_type
    when "heloc_limit_percentage"
      "Stop when HELOC reaches #{threshold_value}% of credit limit"
    when "heloc_balance_threshold"
      "Stop when HELOC balance reaches $#{threshold_value.to_i.to_fs(:delimited)}"
    when "primary_paid_off"
      "Stop when primary mortgage is paid off"
    when "all_debt_paid_off"
      "Stop when all debt is paid off"
    when "max_months"
      "Stop after #{threshold_value.to_i} months"
    when "negative_cash_flow"
      "Stop if net cash flow becomes negative"
    when "heloc_interest_exceeds_benefit"
      "Stop if HELOC interest exceeds tax benefit"
    else
      "Unknown rule type"
    end
  end

  private

    def check_heloc_limit_percentage(ledger_entry)
      strategy = debt_optimization_strategy
      return false unless strategy.heloc.present?

      credit_limit = strategy.heloc.accountable&.credit_limit
      return false unless credit_limit.present? && credit_limit > 0

      current_percentage = (ledger_entry.heloc_balance / credit_limit) * 100
      current_percentage >= (threshold_value || 95)
    end

    def check_heloc_balance_threshold(ledger_entry)
      return false unless threshold_value.present?
      ledger_entry.heloc_balance >= threshold_value
    end

    def check_primary_paid_off(ledger_entry)
      ledger_entry.primary_mortgage_paid_off?
    end

    def check_all_debt_paid_off(ledger_entry)
      ledger_entry.all_debt_paid_off?
    end

    def check_max_months(ledger_entry)
      return false unless threshold_value.present?
      ledger_entry.month_number >= threshold_value.to_i
    end

    def check_negative_cash_flow(ledger_entry)
      ledger_entry.net_rental_cash_flow < 0
    end

    def check_heloc_interest_exceeds_benefit(ledger_entry)
      ledger_entry.heloc_interest > ledger_entry.tax_benefit
    end
end
