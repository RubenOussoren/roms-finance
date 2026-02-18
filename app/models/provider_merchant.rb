class ProviderMerchant < Merchant
  enum :source, { plaid: "plaid", ai: "ai" }

  validates :name, uniqueness: { scope: [ :source ] }
  validates :source, presence: true
end
