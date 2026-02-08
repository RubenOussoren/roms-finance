class BalanceSheet::AccountTotals
  def initialize(family, viewer: nil, scope: :household, sync_status_monitor:)
    @family = family
    @viewer = viewer
    @scope = scope
    @sync_status_monitor = sync_status_monitor
  end

  def asset_accounts
    @asset_accounts ||= account_rows.filter { |t| t.classification == "asset" }
  end

  def liability_accounts
    @liability_accounts ||= account_rows.filter { |t| t.classification == "liability" }
  end

  private
    attr_reader :family, :viewer, :scope, :sync_status_monitor

    AccountRow = Data.define(:account, :converted_balance, :is_syncing) do
      def syncing? = is_syncing

      # Allows Rails path helpers to generate URLs from the wrapper
      def to_param = account.to_param
      delegate_missing_to :account
    end

    def visible_accounts
      @visible_accounts ||= begin
        base = family.accounts.visible.with_attached_logo
        if viewer.nil?
          base
        elsif scope == :personal
          base.owned_by(viewer)
        else # :household
          base.accessible_by(viewer)
        end
      end
    end

    def account_rows
      @account_rows ||= query.map do |account_row|
        AccountRow.new(
          account: account_row,
          converted_balance: account_row.converted_balance,
          is_syncing: sync_status_monitor.account_syncing?(account_row)
        )
      end
    end

    def cache_key
      key_parts = [ "balance_sheet_account_rows" ]
      key_parts << "viewer_#{viewer.id}" if viewer
      key_parts << scope.to_s if viewer

      family.build_cache_key(
        key_parts.join("_"),
        invalidate_on_data_updates: true
      )
    end

    def query
      @query ||= Rails.cache.fetch(cache_key) do
        visible_accounts
          .joins(ActiveRecord::Base.sanitize_sql_array([
            "LEFT JOIN exchange_rates ON exchange_rates.date = ? AND accounts.currency = exchange_rates.from_currency AND exchange_rates.to_currency = ?",
            Date.current,
            family.currency
          ]))
          .select(
            "accounts.*",
            "SUM(accounts.balance * COALESCE(exchange_rates.rate, 1)) as converted_balance"
          )
          .group(:classification, :accountable_type, :id)
          .to_a
      end
    end
end
