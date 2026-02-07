# 🇨🇦 Month-by-month ledger entry for debt optimization simulations
class DebtOptimizationLedgerEntry < ApplicationRecord
  belongs_to :debt_optimization_strategy

  validates :month_number, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :calendar_month, presence: true

  scope :baseline_entries, -> { where(scenario_type: "baseline").order(:month_number) }
  scope :strategy_entries, -> { where(scenario_type: "modified_smith").order(:month_number) }
  scope :prepay_only_entries, -> { where(scenario_type: "prepay_only").order(:month_number) }
  scope :active_months, -> { where(strategy_stopped: false) }

  # Calculate total monthly payment across all debts
  def total_monthly_payment
    primary_mortgage_payment + heloc_payment + rental_mortgage_payment
  end

  # Calculate total outstanding debt
  def total_outstanding_debt
    primary_mortgage_balance + heloc_balance + rental_mortgage_balance
  end

  # Calculate total interest paid this month (deductible + non-deductible)
  def total_interest_paid
    deductible_interest + non_deductible_interest
  end

  # Check if primary mortgage is paid off
  def primary_mortgage_paid_off?
    primary_mortgage_balance <= 0
  end

  # Check if all debt is paid off
  def all_debt_paid_off?
    total_outstanding_debt <= 0
  end

  # Compare with baseline entry at same month
  def interest_savings_vs_baseline
    baseline_entry = debt_optimization_strategy.baseline_entries.find_by(month_number: month_number)
    return 0 unless baseline_entry

    baseline_entry.total_interest_paid - total_interest_paid
  end

  # Summary hash for display/API
  def to_summary_hash
    {
      month_number: month_number,
      calendar_month: calendar_month,
      rental_income: rental_income,
      rental_expenses: rental_expenses,
      net_rental_cash_flow: net_rental_cash_flow,
      heloc_draw: heloc_draw,
      heloc_balance: heloc_balance,
      heloc_interest: heloc_interest,
      primary_mortgage_balance: primary_mortgage_balance,
      primary_mortgage_prepayment: primary_mortgage_prepayment,
      deductible_interest: deductible_interest,
      tax_benefit: tax_benefit,
      cumulative_tax_benefit: cumulative_tax_benefit,
      total_debt: total_debt,
      strategy_stopped: strategy_stopped,
      stop_reason: stop_reason
    }
  end
end
