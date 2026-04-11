class Assistant::Function::GetFinancialSummary < Assistant::Function
  class << self
    def name
      "get_financial_summary"
    end

    def description
      <<~INSTRUCTIONS
        Get a high-level overview of the user's financial situation.

        This is great for:
        - Understanding the user's overall financial picture
        - Answering "how am I doing?" type questions
        - Getting context before diving into specific areas
      INSTRUCTIONS
    end
  end

  def call(params = {})
    accounts = accessible_accounts.includes(:balances)

    assets = accounts.where(classification: "asset")
    liabilities = accounts.where(classification: "liability")

    total_assets = assets.sum(:balance)
    total_liabilities = liabilities.sum(:balance)
    net_worth = total_assets - total_liabilities

    account_counts = accounts.group(:accountable_type).count

    {
      as_of_date: Date.current,
      currency: family.currency,
      net_worth: Money.new(net_worth, family.currency).format,
      total_assets: Money.new(total_assets, family.currency).format,
      total_liabilities: Money.new(total_liabilities, family.currency).format,
      account_count: accounts.count,
      accounts_by_type: account_counts,
      top_accounts: accounts.order(balance: :desc).limit(5).map { |a|
        { name: a.name, balance: a.balance_money.format, type: a.accountable_type }
      }
    }
  end
end
