class SnapTradeAccount::Importer
  def initialize(snaptrade_account, account_data:, positions_data: nil, balances_data: nil, activities_data: nil)
    @snaptrade_account = snaptrade_account
    @account_data = account_data
    @positions_data = positions_data
    @balances_data = balances_data
    @activities_data = activities_data
  end

  def import
    snaptrade_account.upsert_snapshot!(
      account_data: account_data,
      positions_data: positions_data,
      balances_data: balances_data,
      activities_data: activities_data
    )
  end

  private
    attr_reader :snaptrade_account, :account_data, :positions_data, :balances_data, :activities_data
end
