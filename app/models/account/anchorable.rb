# All accounts are "anchored" with start/end valuation records, with transactions,
# trades, and reconciliations between them.
# Also handles reconciliation (balance adjustments between anchors).
module Account::Anchorable
  extend ActiveSupport::Concern

  included do
    include Monetizable

    monetize :opening_balance
  end

  def set_opening_anchor_balance(**opts)
    result = opening_balance_manager.set_opening_balance(**opts)
    sync_later if result.success?
    result
  end

  def opening_anchor_date
    opening_balance_manager.opening_date
  end

  def opening_anchor_balance
    opening_balance_manager.opening_balance
  end

  def has_opening_anchor?
    opening_balance_manager.has_opening_anchor?
  end

  def set_current_balance(balance)
    result = current_balance_manager.set_current_balance(balance)
    sync_later if result.success?
    result
  end

  def current_anchor_balance
    current_balance_manager.current_balance
  end

  def current_anchor_date
    current_balance_manager.current_date
  end

  def has_current_anchor?
    current_balance_manager.has_current_anchor?
  end

  # Reconciliation: adjust balance at a specific date
  def create_reconciliation(balance:, date:, dry_run: false)
    result = reconciliation_manager.reconcile_balance(balance: balance, date: date, dry_run: dry_run)
    sync_later if result.success? && !dry_run
    result
  end

  def update_reconciliation(existing_valuation_entry, balance:, date:, dry_run: false)
    result = reconciliation_manager.reconcile_balance(balance: balance, date: date, existing_valuation_entry: existing_valuation_entry, dry_run: dry_run)
    sync_later if result.success? && !dry_run
    result
  end

  private
    def opening_balance_manager
      @opening_balance_manager ||= Account::OpeningBalanceManager.new(self)
    end

    def current_balance_manager
      @current_balance_manager ||= Account::CurrentBalanceManager.new(self)
    end

    def reconciliation_manager
      @reconciliation_manager ||= Account::ReconciliationManager.new(self)
    end
end
