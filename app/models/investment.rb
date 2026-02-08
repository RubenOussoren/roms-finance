class Investment < ApplicationRecord
  include Accountable

  SUBTYPES = {
    # General
    "brokerage" => { short: "Brokerage", long: "Brokerage", group: "General" },
    "pension" => { short: "Pension", long: "Pension", group: "General" },
    "retirement" => { short: "Retirement", long: "Retirement", group: "General" },
    "mutual_fund" => { short: "Mutual Fund", long: "Mutual Fund", group: "General" },
    "angel" => { short: "Angel", long: "Angel", group: "General" },
    # Canadian
    "tfsa" => { short: "TFSA", long: "Tax-Free Savings Account (TFSA)", group: "Canadian" },
    "rrsp" => { short: "RRSP", long: "Registered Retirement Savings Plan (RRSP)", group: "Canadian" },
    "resp" => { short: "RESP", long: "Registered Education Savings Plan (RESP)", group: "Canadian" },
    "fhsa" => { short: "FHSA", long: "First Home Savings Account (FHSA)", group: "Canadian" },
    "lira" => { short: "LIRA", long: "Locked-In Retirement Account (LIRA)", group: "Canadian" },
    "rdsp" => { short: "RDSP", long: "Registered Disability Savings Plan (RDSP)", group: "Canadian" },
    "non_registered" => { short: "Non-Registered", long: "Non-Registered Account", group: "Canadian" },
    # US
    "401k" => { short: "401(k)", long: "401(k)", group: "US" },
    "roth_401k" => { short: "Roth 401(k)", long: "Roth 401(k)", group: "US" },
    "529_plan" => { short: "529 Plan", long: "529 Plan", group: "US" },
    "hsa" => { short: "HSA", long: "Health Savings Account (HSA)", group: "US" },
    "ira" => { short: "IRA", long: "Traditional IRA", group: "US" },
    "roth_ira" => { short: "Roth IRA", long: "Roth IRA", group: "US" }
  }.freeze

  SUBTYPE_GROUPS = SUBTYPES.group_by { |_k, v| v[:group] }.transform_values { |pairs| pairs.map(&:first) }.freeze

  class << self
    def color
      "#1570EF"
    end

    def classification
      "asset"
    end

    def icon
      "line-chart"
    end
  end
end
