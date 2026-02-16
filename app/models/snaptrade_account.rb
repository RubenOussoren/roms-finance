class SnapTradeAccount < ApplicationRecord
  belongs_to :snaptrade_connection

  has_one :account, dependent: :destroy

  validates :name, :currency, presence: true

  def upsert_snapshot!(account_data:, positions_data: nil, balances_data: nil, activities_data: nil)
    assign_attributes(
      name: account_data.try(:name) || account_data.try(:[], "name") || name,
      currency: account_data.try(:currency) || account_data.try(:[], "currency") || currency || "CAD",
      snaptrade_type: account_data.try(:type) || account_data.try(:[], "type"),
      snaptrade_number: account_data.try(:number) || account_data.try(:[], "number"),
      current_balance: extract_balance(balances_data),
      raw_payload: serialize_data(account_data),
      raw_positions_payload: serialize_data(positions_data),
      raw_balances_payload: serialize_data(balances_data),
      raw_activities_payload: serialize_data(activities_data)
    )

    save!
  end

  private
    def extract_balance(balances_data)
      return current_balance if balances_data.blank?

      # SnapTrade returns an array of balance objects
      balances = Array(balances_data)

      # Look for a cash balance or total balance
      total = balances.sum do |b|
        amount = b.try(:cash) || b.try(:[], "cash") || b.try(:amount) || b.try(:[], "amount") || 0
        amount.to_d
      end

      total.nonzero? ? total : current_balance
    end

    def serialize_data(data)
      return {} if data.blank?

      if data.respond_to?(:to_hash)
        data.to_hash
      elsif data.respond_to?(:map)
        data.map { |d| d.respond_to?(:to_hash) ? d.to_hash : d }
      else
        data
      end
    end
end
