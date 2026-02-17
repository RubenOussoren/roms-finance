class SnapTradeAccount < ApplicationRecord
  belongs_to :snaptrade_connection

  has_one :account, dependent: :destroy

  validates :name, :currency, presence: true

  scope :selected, -> { where(selected_for_import: true) }

  def display_name
    custom_name.presence || name
  end

  def display_currency
    resolve_currency_code(currency).presence || "CAD"
  end

  def upsert_snapshot!(account_data:, positions_data: nil, balances_data: nil, activities_data: nil)
    assign_attributes(
      name: account_data.try(:name) || account_data.try(:[], "name") || name,
      currency: extract_currency(account_data, balances_data),
      snaptrade_type: account_data.try(:raw_type) || account_data.try(:[], "raw_type") ||
                      account_data.try(:type) || account_data.try(:[], "type"),
      snaptrade_number: account_data.try(:number) || account_data.try(:[], "number"),
      current_balance: extract_balance(account_data, balances_data),
      raw_payload: serialize_data(account_data),
      raw_positions_payload: serialize_data(positions_data),
      raw_balances_payload: serialize_data(balances_data),
      raw_activities_payload: serialize_data(activities_data)
    )

    save!
  end

  private
    def extract_currency(account_data, balances_data)
      # Try from inline balance: account.balance.total.currency (String in SDK)
      balance_obj = account_data.try(:balance) || account_data.try(:[], "balance")
      if balance_obj
        total = balance_obj.try(:total) || balance_obj.try(:[], "total")
        if total
          code = resolve_currency_code(total.try(:currency) || total.try(:[], "currency"))
          return code if code.present?
        end
      end

      # Try from separate balances endpoint: Balance.currency (BalanceCurrency object)
      if balances_data.present?
        Array(balances_data).each do |b|
          code = resolve_currency_code(b.try(:currency) || b.try(:[], "currency"))
          return code if code.present?
        end
      end

      currency || "CAD"
    end

    def resolve_currency_code(value)
      return nil if value.blank?
      return value if value.is_a?(String) && value.match?(/\A[A-Z]{3}\z/)

      # BalanceCurrency/Currency object or Hash with code field
      value.try(:code) || (value.is_a?(Hash) && (value[:code] || value["code"])) || nil
    end

    def extract_balance(account_data, balances_data)
      # Prefer inline balance.total.amount from list_accounts response
      balance_obj = account_data.try(:balance) || account_data.try(:[], "balance")
      if balance_obj
        total = balance_obj.try(:total) || balance_obj.try(:[], "total")
        if total
          amount = total.try(:amount) || total.try(:[], "amount")
          return amount.to_d if amount.present? && amount.to_d.nonzero?
        end
      end

      # Fallback: sum cash from separate balances endpoint
      return current_balance if balances_data.blank?
      balances = Array(balances_data)
      total = balances.sum do |b|
        amt = b.try(:cash) || b.try(:[], "cash") || b.try(:amount) || b.try(:[], "amount") || 0
        amt.to_d
      end
      total.nonzero? ? total : current_balance
    end

    def extract_cash_balance(balances_data)
      return 0 if balances_data.blank?
      Array(balances_data).sum do |b|
        amt = b.try(:cash) || b.try(:[], "cash") || 0
        amt.to_d
      end
    end

    def serialize_data(data)
      return {} if data.blank?

      if data.respond_to?(:to_hash)
        data.to_hash.deep_stringify_keys
      elsif data.respond_to?(:map)
        data.map { |d| d.respond_to?(:to_hash) ? d.to_hash.deep_stringify_keys : d }
      else
        data
      end
    end
end
