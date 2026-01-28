# Comprehensive historical data seed for investment projections and calculators
# Creates securities, price history, property accounts, transactions, and syncs accounts
#
# This file loads AFTER projection_test_data.rb and debt_optimization.rb
# and adds the historical transaction/price data needed for calculators to work properly

puts "Seeding projection historical data..."

# Find the Canadian Test Family (created by projection_test_data.rb)
family = Family.find_by(name: "Canadian Test Family", currency: "CAD")

unless family.present?
  puts "  Skipping projection historical data - Canadian Test Family not found"
  puts "  Run projection_test_data seeds first"
  return
end

# Skip if already seeded (check for securities we create)
if Security.exists?(ticker: "VCN")
  puts "  Projection historical data already exists, skipping..."
  puts "Projection historical data seeded successfully!"
  return
end

# ============================================================================
# A. Securities with Price History
# ============================================================================
puts "  Creating securities with price history..."

# HELOC Tool portfolio securities with target returns:
# VCN (RRSP +20.52%, TFSA +6.17%)
# XEC (RRSP +22.47%, TFSA +7.03%)
# XEF (RRSP +13.71%, TFSA +3.98%)
# XUU (RRSP +8.14%, TFSA -0.57%, Non-Reg -0.86%)
# BTC (-11.80%)
# ETH (-5.55%)

securities_data = [
  { ticker: "VCN", name: "Vanguard FTSE Canada All Cap Index ETF", exchange: "XTSE", base_price: 40.00 },
  { ticker: "XEC", name: "iShares Core MSCI Emerging Markets IMI Index ETF", exchange: "XTSE", base_price: 28.00 },
  { ticker: "XEF", name: "iShares Core MSCI EAFE IMI Index ETF", exchange: "XTSE", base_price: 35.00 },
  { ticker: "XUU", name: "iShares Core S&P U.S. Total Market Index ETF", exchange: "XTSE", base_price: 45.00 },
  { ticker: "BTC", name: "Bitcoin", exchange: nil, base_price: 55_000.00 },
  { ticker: "ETH", name: "Ethereum", exchange: nil, base_price: 3_200.00 }
]

securities = {}
rng = Random.new(42) # Deterministic seed for reproducible prices

securities_data.each do |sec_data|
  security = Security.create!(
    ticker: sec_data[:ticker],
    name: sec_data[:name],
    country_code: sec_data[:exchange] ? "CA" : nil,
    exchange_operating_mic: sec_data[:exchange]
  )
  securities[sec_data[:ticker]] = security

  # Generate 18 months of daily prices
  # Start date is 18 months ago to cover all account start dates
  start_date = 18.months.ago.to_date
  price = sec_data[:base_price]

  # Set drift based on target returns (annualized)
  # We'll calibrate to achieve roughly the RRSP returns (longer history)
  annual_drift = case sec_data[:ticker]
  when "VCN" then 0.15   # Target ~20% over 13 months
  when "XEC" then 0.17   # Target ~22% over 13 months
  when "XEF" then 0.10   # Target ~14% over 13 months
  when "XUU" then 0.06   # Target ~8% over 13 months
  when "BTC" then -0.10  # Target ~-12% over 8 months
  when "ETH" then -0.05  # Target ~-6% over 8 months
  else 0.05
  end

  daily_drift = annual_drift / 252.0
  daily_vol = 0.015 # ~24% annual volatility

  (start_date..Date.current).each do |date|
    next if date.saturday? || date.sunday? # Skip weekends

    # Random walk with drift
    random_shock = daily_vol * (rng.rand * 2 - 1)
    price = price * (1 + daily_drift + random_shock)
    price = [ price, 0.01 ].max # Floor at $0.01

    Security::Price.create!(
      security: security,
      date: date,
      price: price.round(4),
      currency: "CAD"
    )
  end

  puts "    Created #{sec_data[:ticker]} with #{security.prices.count} price records"
end

# ============================================================================
# B. Property Accounts (Primary Residence paired with mortgage)
# ============================================================================
puts "  Creating property accounts..."

# Primary Residence (paired with Primary Residence Mortgage from debt_optimization.rb)
# Shows 2 years of appreciation: $1,000,000 -> $1,050,000 -> $1,100,000 (~10% total)
primary_residence = Account.create!(
  family: family,
  name: "Primary Residence",
  balance: 1_100_000, # Current value ~$1.1M (supports $820K readvanceable HELOC)
  currency: "CAD",
  subtype: "single_family_home",
  accountable: Property.create!(year_built: 2015, area_value: 2800, area_unit: "sqft")
)

# Opening valuation 2 years ago (purchase price)
primary_residence.entries.create!(
  entryable: Valuation.new(kind: "opening_anchor"),
  amount: 1_000_000.00, # Purchase price 2 years ago
  name: Valuation.build_opening_anchor_name(primary_residence.accountable_type),
  currency: "CAD",
  date: 2.years.ago.to_date
)

# Reconciliation valuation 1 year ago (~5% appreciation)
primary_residence.entries.create!(
  entryable: Valuation.new(kind: "reconciliation"),
  amount: 1_050_000.00, # Value after 1 year
  name: "Annual Property Valuation",
  currency: "CAD",
  date: 1.year.ago.to_date
)

# Current anchor valuation (~10% total appreciation)
primary_residence.entries.create!(
  entryable: Valuation.new(kind: "current_anchor"),
  amount: 1_100_000.00, # Current value
  name: Valuation.build_current_anchor_name(primary_residence.accountable_type),
  currency: "CAD",
  date: Date.current
)

# Rental Property (paired with Rental Property Mortgage from debt_optimization.rb)
# Shows 2 years of appreciation: $420,000 -> $435,000 -> $450,000 (~7% total)
rental_property = Account.create!(
  family: family,
  name: "Rental Property",
  balance: 450_000, # Current value ~$450K
  currency: "CAD",
  subtype: "condo",
  accountable: Property.create!(year_built: 2018, area_value: 1200, area_unit: "sqft")
)

# Opening valuation 2 years ago (purchase price)
rental_property.entries.create!(
  entryable: Valuation.new(kind: "opening_anchor"),
  amount: 420_000.00, # Purchase price 2 years ago
  name: Valuation.build_opening_anchor_name(rental_property.accountable_type),
  currency: "CAD",
  date: 2.years.ago.to_date
)

# Reconciliation valuation 1 year ago (~3.5% appreciation)
rental_property.entries.create!(
  entryable: Valuation.new(kind: "reconciliation"),
  amount: 435_000.00, # Value after 1 year
  name: "Annual Property Valuation",
  currency: "CAD",
  date: 1.year.ago.to_date
)

# Current anchor valuation (~7% total appreciation)
rental_property.entries.create!(
  entryable: Valuation.new(kind: "current_anchor"),
  amount: 450_000.00, # Current value
  name: Valuation.build_current_anchor_name(rental_property.accountable_type),
  currency: "CAD",
  date: Date.current
)

puts "    Created #{primary_residence.name} and #{rental_property.name}"

# ============================================================================
# C. Depository Accounts (Chequing and Savings)
# ============================================================================
puts "  Creating depository accounts..."

chequing = Account.create!(
  family: family,
  name: "Scotia Bank Chequing",
  balance: 6_279.42,
  currency: "CAD",
  subtype: "checking",
  accountable: Depository.create!
)

# Opening anchor for chequing (2 years ago)
chequing.entries.create!(
  entryable: Valuation.new(kind: "opening_anchor"),
  amount: 4_000.00,  # Started with ~$4K
  name: Valuation.build_opening_anchor_name(chequing.accountable_type),
  currency: "CAD",
  date: 2.years.ago.to_date
)

savings = Account.create!(
  family: family,
  name: "Scotia Bank Savings",
  balance: 4_000.00,
  currency: "CAD",
  subtype: "savings",
  accountable: Depository.create!
)

# Opening anchor for savings (2 years ago)
savings.entries.create!(
  entryable: Valuation.new(kind: "opening_anchor"),
  amount: 2_000.00,  # Started with $2K
  name: Valuation.build_opening_anchor_name(savings.accountable_type),
  currency: "CAD",
  date: 2.years.ago.to_date
)

joint_account = Account.create!(
  family: family,
  name: "BMO Bank (Joint)",
  balance: 10_100.00,
  currency: "CAD",
  subtype: "checking",
  accountable: Depository.create!
)

# Opening anchor for joint account (2 years ago)
joint_account.entries.create!(
  entryable: Valuation.new(kind: "opening_anchor"),
  amount: 5_000.00,  # Started with $5K
  name: Valuation.build_opening_anchor_name(joint_account.accountable_type),
  currency: "CAD",
  date: 2.years.ago.to_date
)

puts "    Created #{chequing.name}, #{savings.name}, and #{joint_account.name}"

# ============================================================================
# D. Credit Card Account
# ============================================================================
puts "  Creating credit card account..."

credit_card = Account.create!(
  family: family,
  name: "TD Cash Back Visa",
  balance: -2_500, # Negative for liability
  currency: "CAD",
  subtype: "credit_card",
  accountable: CreditCard.create!(
    apr: 19.99,
    available_credit: 9_500, # 12000 - 2500
    minimum_payment: 75.00,
    annual_fee: 0
  )
)

# Opening anchor for credit card (2 years ago)
credit_card.entries.create!(
  entryable: Valuation.new(kind: "opening_anchor"),
  amount: -1_500.00,  # Started with $1,500 balance
  name: Valuation.build_opening_anchor_name(credit_card.accountable_type),
  currency: "CAD",
  date: 2.years.ago.to_date
)

puts "    Created #{credit_card.name}"

# ============================================================================
# E. Create Categories for Transactions
# ============================================================================
puts "  Creating expense categories..."

income_cat = family.categories.find_or_create_by!(name: "Salary", classification: "income") do |c|
  c.color = "#10b981"
end

rental_income_cat = family.categories.find_or_create_by!(name: "Rental Income", classification: "income") do |c|
  c.color = "#059669"
end

mortgage_cat = family.categories.find_or_create_by!(name: "Mortgage Payment", classification: "expense") do |c|
  c.color = "#dc2626"
end

utilities_cat = family.categories.find_or_create_by!(name: "Utilities", classification: "expense") do |c|
  c.color = "#f59e0b"
end

groceries_cat = family.categories.find_or_create_by!(name: "Groceries", classification: "expense") do |c|
  c.color = "#8b5cf6"
end

transport_cat = family.categories.find_or_create_by!(name: "Transportation", classification: "expense") do |c|
  c.color = "#3b82f6"
end

dining_cat = family.categories.find_or_create_by!(name: "Dining & Entertainment", classification: "expense") do |c|
  c.color = "#ec4899"
end

insurance_cat = family.categories.find_or_create_by!(name: "Insurance", classification: "expense") do |c|
  c.color = "#6366f1"
end

# ============================================================================
# F. Transaction History (24 months - 2 years of usage)
# ============================================================================
puts "  Generating 24 months of transaction history..."

def create_transaction(account, amount, name, category, date)
  account.entries.create!(
    entryable: Transaction.new(category: category),
    amount: amount,
    name: name,
    currency: account.currency,
    date: date
  )
end

def create_transfer(from_account, to_account, amount, name, date)
  outflow = from_account.entries.create!(
    entryable: Transaction.new,
    amount: amount,
    name: name,
    currency: from_account.currency,
    date: date
  )
  inflow = to_account.entries.create!(
    entryable: Transaction.new,
    amount: -amount,
    name: name,
    currency: to_account.currency,
    date: date
  )
  Transfer.create!(inflow_transaction: inflow.entryable, outflow_transaction: outflow.entryable)
end

transaction_count = 0
rng = Random.new(54321) # Deterministic seed

# Get mortgage accounts from debt_optimization seeds
primary_mortgage = family.accounts.find_by(name: "Primary Residence Mortgage")
rental_mortgage = family.accounts.find_by(name: "Rental Property Mortgage")

# Generate 24 months of transactions (2 years of history)
(24.months.ago.to_date..Date.current).each do |date|
  # === INCOME (bi-weekly salary on Fridays) ===
  if date.friday? && date.day <= 14
    create_transaction(chequing, -6_850, "Employer Direct Deposit", income_cat, date) # Higher income for $329K household
    transaction_count += 1
  elsif date.friday? && date.day > 14 && date.day <= 28
    create_transaction(chequing, -6_850, "Employer Direct Deposit", income_cat, date)
    transaction_count += 1
  end

  # === RENTAL INCOME (1st of month) ===
  if date.day == 1
    create_transaction(chequing, -1_900, "Tenant Rent Payment", rental_income_cat, date) # HELOC Tool default
    transaction_count += 1
  end

  # === FIXED EXPENSES (monthly) ===
  if date.day == 1
    # Primary mortgage payment
    if primary_mortgage
      create_transaction(chequing, 4_100, "Primary Mortgage Payment", mortgage_cat, date) # ~$775K @ 4.9%
      # Principal portion reduces mortgage balance
      create_transaction(primary_mortgage, -900, "Principal Payment", nil, date)
      transaction_count += 2
    end

    # Rental mortgage payment
    if rental_mortgage
      create_transaction(chequing, 1_750, "Rental Mortgage Payment", mortgage_cat, date) # ~$350K @ 4.05%
      # Principal portion reduces mortgage balance
      create_transaction(rental_mortgage, -700, "Principal Payment", nil, date)
      transaction_count += 2
    end

    # Property management fee
    create_transaction(chequing, 95, "Property Management Fee", mortgage_cat, date)
    transaction_count += 1
  end

  if date.day == 15
    # Utilities
    create_transaction(chequing, 200 + rng.rand(80), "Hydro One", utilities_cat, date)
    create_transaction(chequing, 100 + rng.rand(50), "Enbridge Gas", utilities_cat, date)
    create_transaction(chequing, 120 + rng.rand(20), "Rogers Internet", utilities_cat, date)
    transaction_count += 3

    # Insurance
    create_transaction(chequing, 350, "TD Insurance - Home", insurance_cat, date)
    transaction_count += 1
  end

  # === VARIABLE EXPENSES (spread throughout month) ===

  # Groceries (2-3 times per week)
  if [ 1, 3, 5 ].include?(date.wday) && rng.rand < 0.7
    amount = 100 + rng.rand(150)
    stores = [ "Loblaws", "Metro", "No Frills", "Sobeys", "Costco" ]
    create_transaction(chequing, amount, stores[rng.rand(stores.length)], groceries_cat, date)
    transaction_count += 1
  end

  # Transportation (gas, 1-2 times per week)
  if [ 2, 6 ].include?(date.wday) && rng.rand < 0.6
    amount = 70 + rng.rand(50)
    stations = [ "Petro-Canada", "Esso", "Shell", "Canadian Tire Gas" ]
    create_transaction(chequing, amount, stations[rng.rand(stations.length)], transport_cat, date)
    transaction_count += 1
  end

  # Dining/Entertainment (2-3 times per week)
  if [ 4, 5, 6 ].include?(date.wday) && rng.rand < 0.5
    amount = 50 + rng.rand(100)
    places = [ "Tim Hortons", "Swiss Chalet", "Boston Pizza", "The Keg", "Cineplex" ]
    create_transaction(chequing, amount, places[rng.rand(places.length)], dining_cat, date)
    transaction_count += 1
  end

  # Credit card charges (occasional)
  if rng.rand < 0.15
    amount = 40 + rng.rand(100)
    merchants = [ "Amazon.ca", "Best Buy", "Hudson's Bay", "Sport Chek", "Apple" ]
    create_transaction(credit_card, amount, merchants[rng.rand(merchants.length)], dining_cat, date)
    transaction_count += 1
  end

  # Credit card payment (25th of each month)
  if date.day == 25
    # Pay most of credit card balance
    payment_amount = 1000 + rng.rand(500)
    create_transfer(chequing, credit_card, payment_amount, "TD Visa Payment", date)
    transaction_count += 2
  end

  # Monthly transfer to savings (5th of month)
  if date.day == 5
    create_transfer(chequing, savings, 2000 + rng.rand(1000), "Transfer to Savings", date)
    transaction_count += 2
  end
end

puts "    Created #{transaction_count} transactions"

# ============================================================================
# G. Investment Trades
# ============================================================================
puts "  Generating investment trades..."

trade_count = 0

# Get investment accounts from projection_test_data
tfsa = family.accounts.find_by(name: "TFSA")
rrsp = family.accounts.find_by(name: "RRSP")
brokerage = family.accounts.find_by(name: "Non-Registered Brokerage")
crypto_account = family.accounts.find_by(name: "Crypto Portfolio")

# HELOC Tool portfolio data:
#
# RRSP Account (Total: $8,123.67) - Start Dec 2024 (~13 months)
# | Security | Book Cost | Return | Current Value |
# | VCN | $2,136.49 | +20.52% | $2,574.94 |
# | XEC | $711.92 | +22.47% | $871.87 |
# | XEF | $1,426.36 | +13.71% | $1,621.60 |
# | XUU | $2,825.23 | +8.14% | $3,055.26 |
#
# TFSA Account (Total: $2,021.76) - Start Nov 2025 (~3 months)
# | VCN | $451.85 | +6.17% | $479.71 |
# | XEC | $301.94 | +7.03% | $323.16 |
# | XEF | $452.69 | +3.98% | $470.70 |
# | XUU | $752.38 | -0.57% | $748.19 |
#
# Crypto Account (Total: $1,023.40) - Start Jun 2025 (~8 months)
# | BTC | $1,000.00 | -11.80% | $881.75 |
# | ETH | $150.00 | -5.55% | $141.65 |
#
# Non-Registered Account (Total: $497.69) - Start Dec 2025 (~2 months)
# | XUU | $502.01 | -0.86% | $497.69 |

# Define holdings for each account with book costs and start dates
holdings_config = {
  "RRSP" => {
    start_date: Date.new(2024, 12, 1),
    holdings: {
      "VCN" => { book_cost: 2136.49 },
      "XEC" => { book_cost: 711.92 },
      "XEF" => { book_cost: 1426.36 },
      "XUU" => { book_cost: 2825.23 }
    }
  },
  "TFSA" => {
    start_date: Date.new(2025, 11, 1),
    holdings: {
      "VCN" => { book_cost: 451.85 },
      "XEC" => { book_cost: 301.94 },
      "XEF" => { book_cost: 452.69 },
      "XUU" => { book_cost: 752.38 }
    }
  },
  "Crypto Portfolio" => {
    start_date: Date.new(2025, 6, 1),
    holdings: {
      "BTC" => { book_cost: 1000.00 },
      "ETH" => { book_cost: 150.00 }
    }
  },
  "Non-Registered Brokerage" => {
    start_date: Date.new(2025, 12, 1),
    holdings: {
      "XUU" => { book_cost: 502.01 }
    }
  }
}

# Create trades for each account
[ rrsp, tfsa, crypto_account, brokerage ].compact.each do |account|
  config = holdings_config[account.name]
  next unless config

  start_date = config[:start_date]
  end_date = Date.current

  # Calculate number of months
  months = ((end_date.year - start_date.year) * 12 + (end_date.month - start_date.month)).clamp(1, 24)

  config[:holdings].each do |ticker, holding_data|
    security = securities[ticker]
    next unless security

    book_cost = holding_data[:book_cost]
    monthly_contribution = book_cost / months

    # Create monthly trades
    months.times do |i|
      trade_date = start_date + i.months
      next if trade_date > end_date

      # Get price on or near this date
      price_record = security.prices.where("date <= ?", trade_date).order(date: :desc).first
      next unless price_record

      price = price_record.price.to_f
      qty = (monthly_contribution / price).round(6)
      next if qty <= 0

      # Create trade entry
      account.entries.create!(
        entryable: Trade.new(
          security: security,
          qty: qty,
          price: price,
          currency: "CAD"
        ),
        amount: -(qty * price).round(2), # Negative for purchase
        name: "Buy #{ticker}",
        currency: "CAD",
        date: trade_date
      )
      trade_count += 1
    end
  end

  puts "    Created trades for #{account.name}"
end

puts "    Created #{trade_count} investment trades total"

# ============================================================================
# H. Sync All Accounts to Generate Balances
# ============================================================================
puts "  Syncing accounts to generate balance records..."

sync_count = 0
family.accounts.each do |account|
  sync = Sync.create!(syncable: account)
  sync.perform
  sync_count += 1
end

puts "    Synced #{sync_count} accounts"

# ============================================================================
# H2. Force Final Balances with Current Anchor Valuations
# ============================================================================
# The transaction history generates inflated balances due to cumulative income.
# Add current_anchor valuations to force the target final balances.
puts "  Adding current_anchor valuations to fix cash account balances..."

chequing.entries.create!(
  entryable: Valuation.new(kind: "current_anchor"),
  amount: 6_279.42,
  name: Valuation.build_current_anchor_name(chequing.accountable_type),
  currency: "CAD",
  date: Date.current
)

savings.entries.create!(
  entryable: Valuation.new(kind: "current_anchor"),
  amount: 4_000.00,
  name: Valuation.build_current_anchor_name(savings.accountable_type),
  currency: "CAD",
  date: Date.current
)

joint_account.entries.create!(
  entryable: Valuation.new(kind: "current_anchor"),
  amount: 10_100.00,
  name: Valuation.build_current_anchor_name(joint_account.accountable_type),
  currency: "CAD",
  date: Date.current
)

# Re-sync the cash accounts to regenerate balance records with correct values
# The current_anchor valuations will be used as the authoritative balance on their date
[ chequing, savings, joint_account ].each do |account|
  sync = Sync.create!(syncable: account)
  sync.perform
end

# Update the account balance column to match the current_anchor values
# The sync uses :forward strategy which updates account.balance from the last calculated balance,
# but we need to ensure the balance column reflects the current_anchor values
chequing.reload.update!(balance: chequing.current_anchor_balance)
savings.reload.update!(balance: savings.current_anchor_balance)
joint_account.reload.update!(balance: joint_account.current_anchor_balance)

puts "    Fixed cash account balances with current_anchor valuations"

# ============================================================================
# Summary and Verification
# ============================================================================
puts ""
puts "Projection historical data seeded successfully!"
puts ""
puts "Summary:"
puts "  - Securities: #{Security.where(ticker: securities_data.map { |s| s[:ticker] }).count}"
puts "  - Security prices: ~#{Security::Price.count} records"
puts "  - Property accounts: #{family.accounts.where(accountable_type: 'Property').count}"
puts "  - Depository accounts: #{family.accounts.where(accountable_type: 'Depository').count}"
puts "  - Credit card accounts: #{family.accounts.where(accountable_type: 'CreditCard').count}"
puts "  - Entries created: #{Entry.joins(:account).where(accounts: { family_id: family.id }).count}"
puts "  - Balance records: #{Balance.joins(:account).where(accounts: { family_id: family.id }).count}"
puts "  - Holdings: #{Holding.joins(:account).where(accounts: { family_id: family.id }).count}"
puts ""
puts "Investment account holdings:"
[ tfsa, rrsp, brokerage, crypto_account ].compact.each do |account|
  holdings = Holding.where(account: account, date: Date.current)
  total = holdings.sum(:amount).to_f
  puts "  - #{account.name}: #{holdings.count} holdings, $#{total.round(2)} total"
end
puts ""
puts "Verification commands:"
puts "  rails console"
puts '  > family = Family.find_by(name: "Canadian Test Family")'
puts '  > family.accounts.loans.each { |a| puts "#{a.name}: #{LoanPayoffCalculator.new(a).summary[:months_to_payoff]} months" }'
puts '  > family.accounts.investments.each { |a| puts "#{a.name}: #{a.holdings.count} holdings" }'
puts ""
