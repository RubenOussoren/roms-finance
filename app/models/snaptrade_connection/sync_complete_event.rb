class SnapTradeConnection::SyncCompleteEvent
  attr_reader :snaptrade_connection

  def initialize(snaptrade_connection)
    @snaptrade_connection = snaptrade_connection
  end

  def broadcast
    snaptrade_connection.accounts.each do |account|
      account.broadcast_sync_complete
    end

    snaptrade_connection.broadcast_replace_to(
      snaptrade_connection.family,
      target: "snaptrade_connection_#{snaptrade_connection.id}",
      partial: "snaptrade_connections/snaptrade_connection",
      locals: { snaptrade_connection: snaptrade_connection }
    )

    # Update the review page frame when discovery sync completes
    snaptrade_connection.broadcast_replace_to(
      snaptrade_connection,
      target: "#{ActionView::RecordIdentifier.dom_id(snaptrade_connection, :accounts)}",
      partial: "snaptrade_connections/accounts_review",
      locals: { snaptrade_connection: snaptrade_connection, snaptrade_accounts: snaptrade_connection.snaptrade_accounts.order(:created_at) }
    )

    snaptrade_connection.family.broadcast_sync_complete
  end
end
