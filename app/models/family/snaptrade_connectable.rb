module Family::SnapTradeConnectable
  extend ActiveSupport::Concern

  included do
    has_many :snaptrade_connections, dependent: :destroy

    if Rails.application.credentials.active_record_encryption.present?
      encrypts :snaptrade_user_secret, deterministic: true
    end
  end

  def can_connect_snaptrade?
    snaptrade_provider.present?
  end

  # Registers this family as a SnapTrade user (if not already registered)
  # and returns the user_id + user_secret
  def ensure_snaptrade_user!
    return if snaptrade_user_id.present? && snaptrade_user_secret.present?

    response = snaptrade_provider.register_user(user_id: id)
    raise Provider::SnapTrade::Error.new("Failed to register SnapTrade user") unless response.success?

    update!(
      snaptrade_user_id: response.data.try(:user_id) || response.data.try(:[], "userId") || id,
      snaptrade_user_secret: response.data.try(:user_secret) || response.data.try(:[], "userSecret")
    )
  end

  # Gets a redirect URL to the SnapTrade connection portal
  def snaptrade_connection_url(redirect_uri:, broker: nil, reconnect: nil)
    ensure_snaptrade_user!

    response = snaptrade_provider.login_user(
      user_id: snaptrade_user_id,
      user_secret: snaptrade_user_secret,
      custom_redirect: redirect_uri,
      broker: broker,
      reconnect: reconnect
    )

    raise Provider::SnapTrade::Error.new("Failed to generate SnapTrade login URL") unless response.success?

    response.data.try(:redirect_uri) ||
      response.data.try(:redirectURI) ||
      response.data.try(:[], "redirectURI")
  end

  # Creates a SnapTradeConnection from a completed authorization
  def create_snaptrade_connection!(authorization_id:)
    # Fetch connection details from SnapTrade
    connections_response = snaptrade_provider.list_connections(
      user_id: snaptrade_user_id,
      user_secret: snaptrade_user_secret
    )

    connection_data = if connections_response.success?
      Array(connections_response.data).find do |c|
        (c.try(:id) || c.try(:[], "id"))&.to_s == authorization_id.to_s
      end
    end

    snaptrade_connection = snaptrade_connections.create!(
      authorization_id: authorization_id,
      brokerage_name: extract_brokerage_name(connection_data),
      brokerage_slug: extract_brokerage_slug(connection_data),
      raw_payload: connection_data.respond_to?(:to_hash) ? connection_data.to_hash : (connection_data || {})
    )

    snaptrade_connection.sync_later

    snaptrade_connection
  end

  private
    def snaptrade_provider
      Provider::Registry.snaptrade_provider
    end

    def extract_brokerage_name(data)
      return nil unless data
      data.try(:brokerage, :name) ||
        data.dig("brokerage", "name") rescue
        data.try(:name) || "Unknown Brokerage"
    end

    def extract_brokerage_slug(data)
      return nil unless data
      data.try(:brokerage, :slug) ||
        data.dig("brokerage", "slug") rescue nil
    end
end
