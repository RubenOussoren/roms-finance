# Seed: 20 accounts with permissions and opening valuations
#
# Creates a realistic Canadian household portfolio:
# - Joint real estate (primary residence + mortgage + HELOC)
# - Wife's investment property + rental mortgage
# - Personal checking/savings/credit cards for each spouse
# - Investment accounts (RRSP, TFSA, crypto)
# - Joint brokerage + household checking/credit card
#
# Permission model:
# - Joint accounts (is_joint: true): full visibility for both users automatically
# - Personal accounts: owner has full access, spouse gets balance_only permission

puts "Seeding accounts..."

family = Family.find_by(currency: "CAD")
return unless family

husband = family.users.find_by(email: "admin@roms.local")
wife    = family.users.find_by(email: "member@roms.local")

unless husband && wife
  puts "  Skipping accounts - users not found"
  return
end

# Helper to create an account with explicit created_by and optional opening valuation
def create_account!(family:, created_by:, accountable:, name:, balance:, currency: "CAD",
                    subtype: nil, is_joint: false, opening_date: nil, opening_balance: nil)
  account = Account.create!(
    family: family,
    created_by_user_id: created_by.id,
    accountable: accountable,
    name: name,
    balance: balance,
    cash_balance: balance,
    currency: currency,
    subtype: subtype,
    is_joint: is_joint
  )

  # Opening valuation
  if opening_date
    ob = opening_balance || balance
    account.entries.create!(
      entryable: Valuation.new(kind: "opening_anchor"),
      amount: ob.abs,
      name: Valuation.build_opening_anchor_name(account.accountable_type),
      currency: currency,
      date: opening_date
    )
  end

  account
end

# ============================================================================
# 1-3. Joint Real Estate
# ============================================================================

# 1. Primary Residence
primary_residence = create_account!(
  family: family, created_by: husband, is_joint: true,
  accountable: Property.new, name: "Primary Residence",
  balance: 1_050_000, subtype: "single_family_home",
  opening_date: Date.new(2024, 7, 1), opening_balance: 1_000_000
)

# 2. Primary Mortgage
primary_mortgage = create_account!(
  family: family, created_by: husband, is_joint: true,
  accountable: Loan.new(
    interest_rate: 4.90,
    rate_type: "fixed",
    term_months: 360,
    initial_balance: 840_000,
    renewal_date: Date.new(2027, 7, 1),
    renewal_term_months: 60,
    prepayment_privilege_percent: 15.0
  ),
  name: "Primary Mortgage", balance: -830_000, subtype: "mortgage",
  opening_date: Date.new(2024, 7, 1), opening_balance: 840_000
)

# 3. HELOC
heloc = create_account!(
  family: family, created_by: husband, is_joint: true,
  accountable: Loan.new(
    interest_rate: 4.65,
    rate_type: "variable",
    credit_limit: 660_000
  ),
  name: "HELOC", balance: -13_087.83, subtype: "other",
  opening_date: Date.new(2024, 7, 1), opening_balance: 0
)

# ============================================================================
# 4-5. Wife's Investment Property
# ============================================================================

# 4. Investment Property
investment_property = create_account!(
  family: family, created_by: wife, is_joint: false,
  accountable: Property.new, name: "Investment Property",
  balance: 450_000, subtype: "investment_property",
  opening_date: Date.new(2022, 1, 1), opening_balance: 380_000
)

# 5. Rental Mortgage
rental_mortgage = create_account!(
  family: family, created_by: wife, is_joint: false,
  accountable: Loan.new(
    interest_rate: 4.60,
    rate_type: "variable",
    term_months: 300,
    initial_balance: 360_000
  ),
  name: "Rental Mortgage", balance: -350_000, subtype: "mortgage",
  opening_date: Date.new(2022, 1, 1), opening_balance: 360_000
)

# Husband gets full access to wife's investment property accounts
AccountPermission.create!(account: investment_property, user: husband, visibility: "full")
AccountPermission.create!(account: rental_mortgage, user: husband, visibility: "full")

# ============================================================================
# 6-11. Wife's Personal Accounts
# ============================================================================
jan_2023 = Date.new(2023, 1, 1)

cibc_checking = create_account!(
  family: family, created_by: wife, accountable: Depository.new,
  name: "CIBC Checking", balance: 8_000, subtype: "checking",
  opening_date: jan_2023, opening_balance: 5_000
)

cibc_savings = create_account!(
  family: family, created_by: wife, accountable: Depository.new,
  name: "CIBC Savings", balance: 12_000, subtype: "savings",
  opening_date: jan_2023, opening_balance: 8_000
)

cibc_cc = create_account!(
  family: family, created_by: wife, accountable: CreditCard.new(apr: 19.99),
  name: "CIBC Credit Card", balance: 0,
  opening_date: jan_2023, opening_balance: 0
)

manulife_rrsp = create_account!(
  family: family, created_by: wife, accountable: Investment.new,
  name: "Manulife RRSP", balance: 45_000, subtype: "retirement",
  opening_date: jan_2023, opening_balance: 25_000
)

ws_rrsp_wife = create_account!(
  family: family, created_by: wife, accountable: Investment.new,
  name: "Wealthsimple RRSP", balance: 120, subtype: "retirement",
  opening_date: Date.new(2025, 12, 1), opening_balance: 0
)

ws_tfsa_wife = create_account!(
  family: family, created_by: wife, accountable: Investment.new,
  name: "Wealthsimple TFSA", balance: 21_300, subtype: "retirement",
  opening_date: jan_2023, opening_balance: 10_000
)

# Husband gets balance_only for wife's personal accounts
[cibc_checking, cibc_savings, cibc_cc, manulife_rrsp, ws_rrsp_wife, ws_tfsa_wife].each do |acct|
  AccountPermission.create!(account: acct, user: husband, visibility: "balance_only")
end

# ============================================================================
# 12-17. Husband's Personal Accounts
# ============================================================================

scotia_checking = create_account!(
  family: family, created_by: husband, accountable: Depository.new,
  name: "Scotia Checking", balance: 7_000, subtype: "checking",
  opening_date: jan_2023, opening_balance: 4_000
)

scotia_savings = create_account!(
  family: family, created_by: husband, accountable: Depository.new,
  name: "Scotia Savings", balance: 3_000, subtype: "savings",
  opening_date: jan_2023, opening_balance: 2_000
)

scotia_cc = create_account!(
  family: family, created_by: husband, accountable: CreditCard.new(apr: 20.99),
  name: "Scotia Credit Card", balance: 0,
  opening_date: jan_2023, opening_balance: 0
)

ws_rrsp_husband = create_account!(
  family: family, created_by: husband, accountable: Investment.new,
  name: "Wealthsimple RRSP", balance: 8_600, subtype: "retirement",
  opening_date: Date.new(2025, 1, 1), opening_balance: 0
)

ws_tfsa_husband = create_account!(
  family: family, created_by: husband, accountable: Investment.new,
  name: "Wealthsimple TFSA", balance: 3_200, subtype: "retirement",
  opening_date: Date.new(2025, 2, 1), opening_balance: 0
)

ws_crypto = create_account!(
  family: family, created_by: husband, accountable: Crypto.new,
  name: "Wealthsimple Crypto", balance: 1_000,
  opening_date: Date.new(2025, 6, 1), opening_balance: 0
)

# Wife gets balance_only for husband's personal accounts
[scotia_checking, scotia_savings, scotia_cc, ws_rrsp_husband, ws_tfsa_husband, ws_crypto].each do |acct|
  AccountPermission.create!(account: acct, user: wife, visibility: "balance_only")
end

# ============================================================================
# 18-20. Joint Accounts
# ============================================================================

ws_nonreg = create_account!(
  family: family, created_by: husband, is_joint: true,
  accountable: Investment.new, name: "Wealthsimple Non-Registered",
  balance: 600, subtype: "brokerage",
  opening_date: Date.new(2025, 10, 1), opening_balance: 0
)

bmo_checking = create_account!(
  family: family, created_by: husband, is_joint: true,
  accountable: Depository.new, name: "BMO Checking",
  balance: 10_000, subtype: "checking",
  opening_date: jan_2023, opening_balance: 8_000
)

bmo_cc = create_account!(
  family: family, created_by: husband, is_joint: true,
  accountable: CreditCard.new(apr: 21.99),
  name: "BMO Credit Card", balance: 0,
  opening_date: jan_2023, opening_balance: 0
)

puts "  Created #{family.accounts.count} accounts"
puts "  Created #{AccountPermission.count} permission records"
puts "Accounts seed completed!"
