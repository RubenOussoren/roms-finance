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
    heloc_interest_exceeds_benefit: "heloc_interest_exceeds_benefit", # Stop if HELOC interest > tax benefit
    cumulative_cost_exceeds_benefit: "cumulative_cost_exceeds_benefit", # Stop if cumulative HELOC cost > cumulative savings
    heloc_interest_ceiling: "heloc_interest_ceiling",           # Stop if monthly HELOC interest exceeds X
    tax_refund_coverage_ratio: "tax_refund_coverage_ratio",     # Stop if tax benefit < X% of HELOC interest
    manual_stop_date: "manual_stop_date"                        # Stop on a specific date
  }.freeze

  enum :rule_type, RULE_TYPES, prefix: true

  validates :rule_type, presence: true
  validates :threshold_value, numericality: true, allow_nil: true
  validates :threshold_unit, inclusion: { in: %w[percentage amount months date] }, allow_nil: true

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
    when "cumulative_cost_exceeds_benefit"
      check_cumulative_cost_exceeds_benefit(ledger_entry)
    when "heloc_interest_ceiling"
      check_heloc_interest_ceiling(ledger_entry)
    when "tax_refund_coverage_ratio"
      check_tax_refund_coverage_ratio(ledger_entry)
    when "manual_stop_date"
      check_manual_stop_date(ledger_entry)
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
    when "cumulative_cost_exceeds_benefit"
      "Stop if cumulative HELOC cost exceeds cumulative savings"
    when "heloc_interest_ceiling"
      "Stop if monthly HELOC interest exceeds $#{threshold_value.to_i.to_fs(:delimited)}"
    when "tax_refund_coverage_ratio"
      "Stop if tax benefit covers less than #{threshold_value}% of HELOC interest"
    when "manual_stop_date"
      "Stop on #{metadata['stop_date']}"
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

    def check_cumulative_cost_exceeds_benefit(ledger_entry)
      cumulative_net = ledger_entry.metadata&.dig("cumulative_net_benefit")
      return false unless cumulative_net.present?

      cumulative_net.to_f < 0
    end

    # Stop if monthly HELOC interest exceeds a ceiling amount
    def check_heloc_interest_ceiling(ledger_entry)
      return false unless threshold_value.present?
      ledger_entry.heloc_interest >= threshold_value
    end

    # Stop if tax benefit covers less than X% of HELOC interest
    def check_tax_refund_coverage_ratio(ledger_entry)
      return false unless threshold_value.present?
      return false if ledger_entry.heloc_interest.zero?

      coverage_ratio = (ledger_entry.tax_benefit / ledger_entry.heloc_interest) * 100
      coverage_ratio < threshold_value
    end

    # Stop on a specific calendar date
    def check_manual_stop_date(ledger_entry)
      stop_date = metadata&.dig("stop_date")
      return false unless stop_date.present?

      ledger_entry.calendar_month >= Date.parse(stop_date)
    rescue Date::Error
      false
    end
end
