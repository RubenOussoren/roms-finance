class SnapTradeConnection::Importer
  def initialize(snaptrade_connection, snaptrade_provider:)
    @snaptrade_connection = snaptrade_connection
    @snaptrade_provider = snaptrade_provider
  end

  def import
    fetch_and_import_accounts_data
  rescue => e
    handle_error(e)
  end

  private
    attr_reader :snaptrade_connection, :snaptrade_provider

    def family
      snaptrade_connection.family
    end

    def user_id
      family.snaptrade_user_id
    end

    def user_secret
      family.snaptrade_user_secret
    end

    def handle_error(error)
      # If the connection is no longer valid, mark it for re-authentication
      if error.message.include?("403") || error.message.include?("expired")
        snaptrade_connection.update!(status: :requires_update)
      else
        raise error
      end
    end

    def fetch_and_import_accounts_data
      accounts_response = snaptrade_provider.list_accounts(
        user_id: user_id,
        user_secret: user_secret
      )

      raise Provider::SnapTrade::Error.new("Failed to fetch accounts") unless accounts_response.success?

      raw_accounts = Array(accounts_response.data)
      Rails.logger.info("[SnapTrade] Fetched #{raw_accounts.size} account(s) for user #{user_id}")

      SnapTradeConnection.transaction do
        raw_accounts.each do |raw_account|
          # brokerage_authorization is a flat UUID string in SDK v2.x (not a nested object)
          auth_id = raw_account.try(:brokerage_authorization) || raw_account.try(:[], "brokerage_authorization")
          next unless auth_id.to_s == snaptrade_connection.authorization_id

          account_id = (raw_account.try(:id) || raw_account.try(:[], "id")).to_s
          next if account_id.blank?

          Rails.logger.info("[SnapTrade] Processing account #{account_id} (auth: #{auth_id})")

          snaptrade_account = snaptrade_connection.snaptrade_accounts.find_or_initialize_by(
            snaptrade_account_id: account_id
          )

          # Fetch detailed data for this account
          positions_data = fetch_positions(account_id)
          balances_data = fetch_balances(account_id)
          activities_data = fetch_activities(account_id)

          SnapTradeAccount::Importer.new(
            snaptrade_account,
            account_data: raw_account,
            positions_data: positions_data,
            balances_data: balances_data,
            activities_data: activities_data
          ).import
        end
      end
    end

    def fetch_positions(account_id)
      response = snaptrade_provider.get_positions(
        user_id: user_id,
        user_secret: user_secret,
        account_id: account_id
      )
      response.success? ? response.data : []
    end

    def fetch_balances(account_id)
      response = snaptrade_provider.get_balances(
        user_id: user_id,
        user_secret: user_secret,
        account_id: account_id
      )
      response.success? ? response.data : []
    end

    def fetch_activities(account_id)
      response = snaptrade_provider.get_activities(
        user_id: user_id,
        user_secret: user_secret,
        account_id: account_id,
        start_date: 2.years.ago.to_date,
        end_date: Date.current
      )
      return [] unless response.success?

      raw = response.data
      return [] if raw.blank?

      # SDK v2 returns a paginated envelope object — convert to plain hash first
      if raw.respond_to?(:to_hash) && !raw.is_a?(Hash) && !raw.is_a?(Array)
        raw = raw.to_hash.deep_stringify_keys
      end

      # Unwrap {"data" => [...], "pagination" => {...}}
      if raw.is_a?(Hash) && raw.key?("data")
        raw = raw["data"]
      end

      data = Array(raw)
      Rails.logger.info("[SnapTrade] Fetched #{data.size} activities for account #{account_id}")
      data
    end
end
