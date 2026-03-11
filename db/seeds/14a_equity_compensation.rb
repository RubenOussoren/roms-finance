# Seed: Equity compensation accounts with grants
#
# Creates 3 equity compensation accounts with 4 grants total:
# - Wife's Alphabet RSUs (personal)
# - Husband's Apple Stock Options (personal)
# - Husband's Previous Employer Options — terminated/expired (personal)
#
# Uses GOOG and AAPL securities created in 14_investments.rb.

puts "Seeding equity compensation..."

family = Family.find_by(currency: "CAD")
return unless family

# Skip if already seeded
if Account.where(accountable_type: "EquityCompensation").exists?
  puts "  Equity compensation data already exists, skipping..."
  return
end

husband = family.users.find_by(email: "admin@roms.local")
wife    = family.users.find_by(email: "member@roms.local")

unless husband && wife
  puts "  Skipping equity compensation - users not found"
  return
end

goog = Security.find_by(ticker: "GOOG")
aapl = Security.find_by(ticker: "AAPL")

unless goog && aapl
  puts "  Skipping equity compensation - GOOG/AAPL securities not found"
  return
end

# ============================================================================
# 1. Wife's RSU Account — "Alphabet RSUs"
# ============================================================================
alphabet_rsus = Account.create!(
  family: family,
  created_by_user_id: wife.id,
  accountable: EquityCompensation.new,
  name: "Alphabet RSUs",
  balance: 0,
  cash_balance: 0,
  currency: "USD",
  subtype: "rsu",
  is_joint: false
)

EquityGrant.create!(
  equity_compensation: alphabet_rsus.accountable,
  security: goog,
  name: "2023 Annual RSU",
  grant_type: "rsu",
  total_units: 1200,
  grant_date: Date.new(2023, 1, 15),
  cliff_months: 12,
  vesting_period_months: 48,
  vesting_frequency: "monthly",
  estimated_tax_rate: 30.0
)

puts "  Created Alphabet RSUs (wife) — 1 RSU grant"

# ============================================================================
# 2. Husband's Stock Option Account — "Apple Stock Options"
# ============================================================================
apple_options = Account.create!(
  family: family,
  created_by_user_id: husband.id,
  accountable: EquityCompensation.new,
  name: "Apple Stock Options",
  balance: 0,
  cash_balance: 0,
  currency: "USD",
  subtype: "stock_option",
  is_joint: false
)

EquityGrant.create!(
  equity_compensation: apple_options.accountable,
  security: aapl,
  name: "2024 ISO Grant",
  grant_type: "stock_option",
  option_type: "iso",
  total_units: 2000,
  grant_date: Date.new(2024, 3, 1),
  strike_price: 185.00,
  cliff_months: 12,
  vesting_period_months: 48,
  vesting_frequency: "quarterly",
  expiration_date: Date.new(2034, 3, 1),
  estimated_tax_rate: 15.0
)

puts "  Created Apple Stock Options (husband) — 1 ISO grant"

# ============================================================================
# 3. Husband's Terminated Option Account — "Previous Employer Options"
# ============================================================================
prev_employer = Account.create!(
  family: family,
  created_by_user_id: husband.id,
  accountable: EquityCompensation.new,
  name: "Previous Employer Options",
  balance: 0,
  cash_balance: 0,
  currency: "USD",
  subtype: "stock_option",
  is_joint: false
)

EquityGrant.create!(
  equity_compensation: prev_employer.accountable,
  security: goog,
  name: "2022 NSO Grant",
  grant_type: "stock_option",
  option_type: "nso",
  total_units: 500,
  grant_date: Date.new(2022, 6, 1),
  strike_price: 110.00,
  cliff_months: 12,
  vesting_period_months: 48,
  vesting_frequency: "monthly",
  expiration_date: Date.new(2032, 6, 1),
  termination_date: Date.new(2025, 9, 15),
  estimated_tax_rate: 30.0
)

puts "  Created Previous Employer Options (husband) — 1 terminated NSO grant"

# ============================================================================
# Permissions: cross-spouse balance_only
# ============================================================================
AccountPermission.create!(account: alphabet_rsus, user: husband, visibility: "balance_only")
AccountPermission.create!(account: apple_options, user: wife, visibility: "balance_only")
AccountPermission.create!(account: prev_employer, user: wife, visibility: "balance_only")

puts "  Created 3 cross-spouse permission records"
puts "Equity compensation seed completed!"
