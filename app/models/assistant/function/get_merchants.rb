class Assistant::Function::GetMerchants < Assistant::Function
  class << self
    def name
      "get_merchants"
    end

    def description
      <<~INSTRUCTIONS
        Get the user's merchants with total spending.

        This is great for:
        - "Where am I spending the most money?"
        - "How much have I spent at Amazon?"
      INSTRUCTIONS
    end
  end

  def params_schema
    build_schema(
      required: [],
      properties: {
        limit: {
          type: "integer",
          description: "Number of merchants to return, ordered by spend. Defaults to 20."
        }
      }
    )
  end

  def strict_mode?
    false
  end

  def call(params = {})
    limit = (params["limit"] || 20).to_i.clamp(1, 50)
    account_ids = full_access_accounts.pluck(:id)

    merchants_with_spend = family.merchants
      .joins(transactions: :entry)
      .where(entries: { account_id: account_ids })
      .where("entries.amount > 0")
      .group("merchants.id", "merchants.name")
      .select("merchants.id, merchants.name, SUM(entries.amount) as total_spend, COUNT(entries.id) as transaction_count")
      .order("total_spend DESC")
      .limit(limit)

    {
      currency: family.currency,
      merchants: merchants_with_spend.map { |m|
        {
          name: m.name,
          total_spend: Money.new(m.total_spend, family.currency).format,
          transaction_count: m.transaction_count
        }
      }
    }
  end
end
