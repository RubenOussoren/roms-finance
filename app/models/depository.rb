class Depository < ApplicationRecord
  include Accountable

  SUBTYPES = {
    # General
    "checking" => { short: "Checking", long: "Checking" },
    "savings" => { short: "Savings", long: "Savings" },
    "money_market" => { short: "MM", long: "Money Market" },
    # Canadian
    "gic" => { short: "GIC", long: "Guaranteed Investment Certificate (GIC)" },
    "high_interest_savings" => { short: "HISA", long: "High-Interest Savings Account" },
    # US
    "hsa" => { short: "HSA", long: "Health Savings Account (HSA)" },
    "cd" => { short: "CD", long: "Certificate of Deposit" },
  }.freeze

  class << self
    def display_name
      "Cash"
    end

    def color
      "#875BF7"
    end

    def classification
      "asset"
    end

    def icon
      "landmark"
    end
  end
end
