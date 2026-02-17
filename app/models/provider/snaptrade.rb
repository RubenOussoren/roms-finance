class Provider::SnapTrade < Provider
  class Error < Provider::Error; end

  def initialize(client_id:, consumer_key:)
    configuration = ::SnapTrade::Configuration.new
    configuration.client_id = client_id
    configuration.consumer_key = consumer_key
    @client = ::SnapTrade::Client.new(configuration)
  end

  def register_user(user_id:)
    with_provider_response do
      client.authentication.register_snap_trade_user(user_id: user_id)
    end
  end

  def login_user(user_id:, user_secret:, broker: nil, reconnect: nil)
    params = {
      user_id: user_id,
      user_secret: user_secret,
      connection_type: "read",
      connection_portal_version: "v4"
    }
    params[:broker] = broker if broker.present?
    params[:reconnect] = reconnect if reconnect.present?

    with_provider_response do
      client.authentication.login_snap_trade_user(**params)
    end
  end

  def delete_user(user_id:)
    with_provider_response do
      client.authentication.delete_snap_trade_user(user_id: user_id)
    end
  end

  def list_connections(user_id:, user_secret:)
    with_provider_response do
      client.connections.list_brokerage_authorizations(
        user_id: user_id,
        user_secret: user_secret
      )
    end
  end

  def remove_connection(authorization_id:, user_id:, user_secret:)
    with_provider_response do
      client.connections.remove_brokerage_authorization(
        authorization_id: authorization_id,
        user_id: user_id,
        user_secret: user_secret
      )
    end
  end

  def list_accounts(user_id:, user_secret:)
    with_provider_response do
      client.account_information.list_user_accounts(
        user_id: user_id,
        user_secret: user_secret
      )
    end
  end

  def get_positions(user_id:, user_secret:, account_id:)
    with_provider_response do
      client.account_information.get_user_account_positions(
        user_id: user_id,
        user_secret: user_secret,
        account_id: account_id
      )
    end
  end

  def get_balances(user_id:, user_secret:, account_id:)
    with_provider_response do
      client.account_information.get_user_account_balance(
        user_id: user_id,
        user_secret: user_secret,
        account_id: account_id
      )
    end
  end

  def get_activities(user_id:, user_secret:, account_id:, start_date: nil, end_date: nil)
    params = {
      user_id: user_id,
      user_secret: user_secret,
      account_id: account_id
    }
    params[:start_date] = start_date.to_s if start_date.present?
    params[:end_date] = end_date.to_s if end_date.present?

    with_provider_response do
      client.account_information.get_account_activities(**params)
    end
  end

  def validate_webhook!(signature_header, raw_body)
    expected_signature = OpenSSL::HMAC.hexdigest(
      "SHA256",
      consumer_key,
      raw_body
    )

    unless ActiveSupport::SecurityUtils.secure_compare(expected_signature, signature_header)
      raise Error.new("Invalid webhook signature")
    end
  end

  private
    attr_reader :client

    def consumer_key
      client.instance_variable_get(:@config).consumer_key
    end

    def default_error_transformer(error)
      Error.new(error.message, details: error.try(:response)&.dig(:body))
    end
end
