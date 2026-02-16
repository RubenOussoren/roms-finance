module SnapTradeAccount::TypeMappable
  extend ActiveSupport::Concern

  UnknownAccountTypeError = Class.new(StandardError)

  # Maps SnapTrade account type string to an Accountable instance
  def map_accountable(snaptrade_type)
    mapping = TYPE_MAPPING[snaptrade_type.to_s.upcase]

    unless mapping
      # Default to Investment for unknown brokerage account types
      return Investment.new
    end

    mapping[:accountable].new
  end

  # Maps SnapTrade account type to an internal subtype string
  def map_subtype(snaptrade_type)
    mapping = TYPE_MAPPING[snaptrade_type.to_s.upcase]
    mapping&.dig(:subtype) || "brokerage"
  end

  # SnapTrade Account Types -> Accountable Types
  # https://docs.snaptrade.com
  TYPE_MAPPING = {
    # Canadian registered account types
    "TFSA" => { accountable: Investment, subtype: "tfsa" },
    "RRSP" => { accountable: Investment, subtype: "rrsp" },
    "FHSA" => { accountable: Investment, subtype: "fhsa" },
    "RESP" => { accountable: Investment, subtype: "resp" },
    "LIRA" => { accountable: Investment, subtype: "lira" },
    "RDSP" => { accountable: Investment, subtype: "rdsp" },
    "RRIF" => { accountable: Investment, subtype: "retirement" },
    "LIF" => { accountable: Investment, subtype: "retirement" },

    # Canadian non-registered
    "INDIVIDUAL" => { accountable: Investment, subtype: "non_registered" },
    "JOINT" => { accountable: Investment, subtype: "non_registered" },
    "CORPORATE" => { accountable: Investment, subtype: "non_registered" },
    "NON_REGISTERED" => { accountable: Investment, subtype: "non_registered" },

    # US account types
    "401K" => { accountable: Investment, subtype: "401k" },
    "ROTH_401K" => { accountable: Investment, subtype: "roth_401k" },
    "IRA" => { accountable: Investment, subtype: "ira" },
    "ROTH_IRA" => { accountable: Investment, subtype: "roth_ira" },
    "529" => { accountable: Investment, subtype: "529_plan" },
    "HSA" => { accountable: Investment, subtype: "hsa" },

    # Generic types
    "MARGIN" => { accountable: Investment, subtype: "brokerage" },
    "CASH" => { accountable: Depository, subtype: "savings" },
    "CRYPTO" => { accountable: Crypto, subtype: nil }
  }.freeze
end
