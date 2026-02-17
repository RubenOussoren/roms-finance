class SnapTradeConnection::WebhookProcessor
  MissingConnectionError = Class.new(StandardError)

  def initialize(webhook_body)
    parsed = JSON.parse(webhook_body)
    @event_type = parsed["type"] || parsed["event"]
    @user_id = parsed["userId"] || parsed["user_id"]
    @authorization_id = parsed["authorizationId"] || parsed["authorization_id"]
    @account_id = parsed["accountId"] || parsed["account_id"]
  end

  def process
    case event_type
    when "ACCOUNT_UPDATED", "HOLDINGS_UPDATED", "TRANSACTIONS_UPDATED"
      if snaptrade_connection
        snaptrade_connection.sync_later
      else
        handle_missing_connection
      end
    when "CONNECTION_DELETED"
      if snaptrade_connection && !snaptrade_connection.scheduled_for_deletion?
        snaptrade_connection.destroy_later
      end
    when "CONNECTION_ERROR"
      if snaptrade_connection
        snaptrade_connection.update!(status: :requires_update)
      end
    else
      Rails.logger.warn("Unhandled SnapTrade webhook type: #{event_type}")
    end
  rescue => e
    Sentry.capture_exception(e)
  end

  private
    attr_reader :event_type, :user_id, :authorization_id, :account_id

    def snaptrade_connection
      @snaptrade_connection ||= if authorization_id.present?
        SnapTradeConnection.find_by(authorization_id: authorization_id)
      elsif user_id.present?
        family = Family.find_by(snaptrade_user_id: user_id)
        family&.snaptrade_connections&.first
      end
    end

    def handle_missing_connection
      Sentry.capture_exception(
        MissingConnectionError.new("Received SnapTrade webhook for connection not in our DB. Manual action required.")
      ) do |scope|
        scope.set_tags(
          snaptrade_authorization_id: authorization_id,
          snaptrade_user_id: user_id
        )
      end
    end
end
