class SnapTradeConnection::Syncer
  attr_reader :snaptrade_connection

  def initialize(snaptrade_connection)
    @snaptrade_connection = snaptrade_connection
  end

  def perform_sync(sync)
    snaptrade_connection.import_latest_snaptrade_data

    if snaptrade_connection.snaptrade_accounts.selected.any?
      snaptrade_connection.process_accounts

      snaptrade_connection.schedule_account_syncs(
        parent_sync: sync,
        window_start_date: sync.window_start_date,
        window_end_date: sync.window_end_date
      )
    else
      Rails.logger.info("[SnapTrade] No selected accounts for connection #{snaptrade_connection.id}, skipping processing")
    end
  end

  def perform_post_sync
    # no-op
  end
end
