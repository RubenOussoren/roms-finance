# Month-by-month ledger display for debt optimization
class UI::DebtOptimization::LedgerTable < ApplicationComponent
  attr_reader :entries, :show_baseline

  def initialize(entries:, show_baseline: false)
    @entries = entries
    @show_baseline = show_baseline
  end

  def currency
    entries.first&.debt_optimization_strategy&.currency || "CAD"
  end

  def format_amount(amount)
    return "—" if amount.nil? || amount.zero?
    helpers.format_money(Money.new(amount, currency))
  end

  def format_month(date)
    date.strftime("%b %Y")
  end

  def row_classes(entry)
    classes = []
    classes << "bg-red-50" if entry.strategy_stopped
    classes << "bg-green-50" if entry.primary_mortgage_paid_off? && !entry.strategy_stopped
    classes.join(" ")
  end
end
