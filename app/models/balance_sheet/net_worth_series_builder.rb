class BalanceSheet::NetWorthSeriesBuilder
  def initialize(family, viewer: nil, scope: :household)
    @family = family
    @viewer = viewer
    @scope = scope
  end

  def net_worth_series(period: Period.last_30_days)
    Rails.cache.fetch(cache_key(period)) do
      builder = Balance::ChartSeriesBuilder.new(
        account_ids: visible_account_ids,
        currency: family.currency,
        period: period,
        favorable_direction: "up",
        ownership_fractions: ownership_fractions
      )

      builder.balance_series
    end
  end

  private
    attr_reader :family, :viewer, :scope

    def visible_account_ids
      @visible_account_ids ||= begin
        base = family.accounts.visible.with_attached_logo
        if viewer.nil?
          base
        elsif scope == :personal
          base.with_ownership_for(viewer)
        else
          base.accessible_by(viewer)
        end.pluck(:id)
      end
    end

    def ownership_fractions
      return nil unless viewer && scope == :personal

      accounts = family.accounts.visible.with_ownership_for(viewer)
        .includes(:account_ownerships)
      member_count = family.users.count

      accounts.each_with_object({}) do |account, hash|
        hash[account.id] = account.ownership_fraction_for(viewer, member_count: member_count)
      end
    end

    def cache_key(period)
      key_parts = [
        "balance_sheet_net_worth_series",
        period.start_date,
        period.end_date
      ]
      key_parts << "viewer_#{viewer.id}" if viewer
      key_parts << scope.to_s if viewer

      family.build_cache_key(
        key_parts.compact.join("_"),
        invalidate_on_data_updates: true
      )
    end
end
