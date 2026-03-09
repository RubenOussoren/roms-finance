class Assistant::Function::GetConnectivityStatus < Assistant::Function
  class << self
    def name
      "get_connectivity_status"
    end

    def description
      "Get the health and status of the user's connected bank and brokerage accounts (Plaid, SnapTrade)."
    end
  end

  def call(params = {})
    plaid_items = PlaidItem.where(family: family).includes(:plaid_accounts)
    snaptrade_connections = SnapTradeConnection.where(family: family).includes(:snaptrade_accounts)

    {
      plaid: plaid_items.map { |item|
        {
          name: item.name,
          status: item.status,
          accounts: item.plaid_accounts.map { |pa|
            { name: pa.name, linked: pa.account_id.present? }
          }
        }
      },
      snaptrade: snaptrade_connections.map { |conn|
        {
          name: conn.brokerage_name,
          status: conn.status,
          accounts: conn.snaptrade_accounts.map { |sa|
            { name: sa.name, linked: sa.account_id.present? }
          }
        }
      }
    }
  end
end
