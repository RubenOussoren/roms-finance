# Seed: 37 months of transaction history (Jan 2023 – Feb 2026)
#
# Generates ~3,000–4,000 entries across all accounts:
# - Bi-weekly salaries for both spouses
# - Monthly rental income
# - Household transfers to BMO Checking
# - Fixed expenses (mortgage, utilities, insurance, property tax)
# - Variable expenses (groceries, dining, gas, shopping, entertainment)
# - Credit card cycles with full monthly payoff
# - Savings and investment contributions
# - Mortgage principal reduction entries

puts "Seeding transactions..."

family = Family.find_by(currency: "CAD")
return unless family

# ============================================================================
# Account lookups
# ============================================================================
accounts = {}
family.accounts.each { |a| accounts[a.name] = a }

cibc_chk     = accounts["CIBC Checking"]
cibc_sav     = accounts["CIBC Savings"]
cibc_cc      = accounts["CIBC Credit Card"]
scotia_chk   = accounts["Scotia Checking"]
scotia_sav   = accounts["Scotia Savings"]
scotia_cc    = accounts["Scotia Credit Card"]
bmo_chk      = accounts["BMO Checking"]
bmo_cc       = accounts["BMO Credit Card"]
primary_mtg  = accounts["Primary Mortgage"]
rental_mtg   = accounts["Rental Mortgage"]

unless [cibc_chk, scotia_chk, bmo_chk, primary_mtg].all?
  puts "  Skipping transactions - required accounts not found"
  return
end

# ============================================================================
# Category lookups
# ============================================================================
cat = {}
family.categories.each { |c| cat[c.name] = c }

# ============================================================================
# Deterministic RNG
# ============================================================================
rng = Random.new(42)
srand(42)

# ============================================================================
# Helpers
# ============================================================================
def create_txn!(account, amount, name, category, date)
  account.entries.create!(
    entryable: Transaction.new(category: category),
    amount: amount,
    name: name,
    currency: account.currency,
    date: date
  )
end

def create_transfer!(from, to, amount, name, date)
  outflow = from.entries.create!(
    entryable: Transaction.new,
    amount: amount,
    name: name,
    currency: from.currency,
    date: date
  )
  inflow = to.entries.create!(
    entryable: Transaction.new,
    amount: -amount,
    name: name,
    currency: to.currency,
    date: date
  )
  Transfer.create!(inflow_transaction: inflow.entryable, outflow_transaction: outflow.entryable)
end

def jitter(rng, num, pct = 0.03)
  variation = num * pct * (rng.rand * 2 - 1)
  (num + variation).round(2)
end

start_date = Date.new(2023, 1, 1)
end_date   = Date.current

# ============================================================================
# 1. INCOME — Bi-weekly salaries
# ============================================================================
puts "  Generating salaries..."

# Wife: bi-weekly ~$3,358 to CIBC Checking (gross ~$87,300/yr)
# Husband: bi-weekly ~$3,027 to Scotia Checking (gross ~$78,700/yr)
salary_date = start_date
salary_date += 1 until salary_date.friday?

while salary_date <= end_date
  create_txn!(cibc_chk, -jitter(rng, 3_358, 0.02).round, "Employer - Direct Deposit", cat["Salary"], salary_date)
  create_txn!(scotia_chk, -jitter(rng, 3_027, 0.02).round, "Employer - Direct Deposit", cat["Salary"], salary_date)
  salary_date += 14
end

# ============================================================================
# 2. RENTAL INCOME — Monthly $1,900 to BMO Checking
# ============================================================================
puts "  Generating rental income..."

(start_date..end_date).each do |date|
  next unless date.day == 1
  create_txn!(bmo_chk, -1_900, "Tenant Rent Payment", cat["Rental Income"], date)
end

# ============================================================================
# 3. HOUSEHOLD TRANSFERS — Personal → BMO Checking
# ============================================================================
puts "  Generating household transfers..."

(start_date..end_date).each do |date|
  next unless date.day == 2

  create_transfer!(cibc_chk, bmo_chk, jitter(rng, 3_500, 0.03).round, "Household Contribution", date)
  create_transfer!(scotia_chk, bmo_chk, jitter(rng, 3_000, 0.03).round, "Household Contribution", date)
end

# ============================================================================
# 4. FIXED EXPENSES from BMO Checking
# ============================================================================
puts "  Generating fixed expenses..."

(start_date..end_date).each do |date|
  # Mortgage payments on the 1st
  if date.day == 1
    create_txn!(bmo_chk, 4_376, "Primary Mortgage Payment", cat["Mortgage"], date)
    create_txn!(bmo_chk, 2_021, "Rental Mortgage Payment", cat["Mortgage"], date)
    create_txn!(bmo_chk, 95, "Property Management Fee", cat["Rental Expenses"], date)
    create_txn!(bmo_chk, jitter(rng, 797, 0.05).round, "Rental Property Expenses", cat["Rental Expenses"], date)

    # Mortgage principal reduction entries
    create_txn!(primary_mtg, -jitter(rng, 1_200, 0.03).round, "Principal Payment", nil, date)
    create_txn!(rental_mtg, -jitter(rng, 600, 0.03).round, "Principal Payment", nil, date)
  end

  # Utilities on ~15th
  if date.day == 15
    create_txn!(bmo_chk, jitter(rng, 185, 0.10).round, "Hydro One", cat["Utilities"], date)
    create_txn!(bmo_chk, jitter(rng, 110, 0.10).round, "Enbridge Gas", cat["Utilities"], date)
    create_txn!(bmo_chk, 85, "Rogers Internet", cat["Utilities"], date)
  end

  # Insurance on ~15th
  if date.day == 16
    create_txn!(bmo_chk, 220, "Home Insurance", cat["Insurance"], date)
    create_txn!(bmo_chk, 185, "Auto Insurance", cat["Insurance"], date)
  end

  # Property tax quarterly (~$800)
  if date.day == 1 && [3, 6, 9, 12].include?(date.month)
    create_txn!(bmo_chk, jitter(rng, 800, 0.05).round, "City of Toronto Property Tax", cat["Property Tax"], date + 14)
  end
end

# ============================================================================
# 5. VARIABLE EXPENSES — Groceries, dining, gas, shopping, entertainment
# ============================================================================
puts "  Generating variable expenses..."

# Collect all days in the range for random selection
all_days = (start_date..end_date).to_a

grocery_stores = ["Loblaws", "Metro", "No Frills", "Sobeys", "Costco"]
restaurants    = ["Tim Hortons", "Swiss Chalet", "Boston Pizza", "The Keg", "Harvey's", "Popeyes", "Sushi Shop"]
gas_stations   = ["Petro-Canada", "Esso", "Shell", "Canadian Tire Gas"]
shops          = ["Amazon.ca", "Canadian Tire", "Hudson's Bay", "Walmart.ca", "Home Depot", "Winners"]
entertainment  = ["Netflix", "Spotify", "Cineplex", "Disney+", "Apple Music"]

# Groceries: 2-3x/week across personal checking + credit cards
(all_days.length / 3).times do
  date = all_days.sample(random: rng)
  amount = rng.rand(45..180)
  store = grocery_stores.sample(random: rng)
  account = [cibc_chk, cibc_cc, scotia_chk, scotia_cc, bmo_cc].sample(random: rng)
  create_txn!(account, amount, store, cat["Groceries"], date)
end

# Dining: 2-3x/week
(all_days.length / 4).times do
  date = all_days.sample(random: rng)
  amount = rng.rand(12..65)
  restaurant = restaurants.sample(random: rng)
  account = [cibc_cc, scotia_cc, bmo_cc, cibc_chk, scotia_chk].sample(random: rng)
  create_txn!(account, amount, restaurant, cat["Dining Out"], date)
end

# Gas: 1-2x/week
(all_days.length / 5).times do
  date = all_days.sample(random: rng)
  amount = rng.rand(55..110)
  station = gas_stations.sample(random: rng)
  account = [cibc_cc, scotia_cc, bmo_cc].sample(random: rng)
  create_txn!(account, amount, station, cat["Transportation"], date)
end

# Shopping: occasional
(all_days.length / 10).times do
  date = all_days.sample(random: rng)
  amount = rng.rand(25..200)
  shop = shops.sample(random: rng)
  account = [cibc_cc, scotia_cc, bmo_cc].sample(random: rng)
  create_txn!(account, amount, shop, cat["Shopping"], date)
end

# Entertainment subscriptions: monthly per service
entertainment.each do |service|
  amt = case service
        when "Netflix" then 17
        when "Spotify" then 11
        when "Cineplex" then 0 # one-off below
        when "Disney+" then 12
        when "Apple Music" then 11
        end
  next if amt == 0

  (start_date..end_date).each do |date|
    next unless date.day == 5
    create_txn!(cibc_cc, amt, service, cat["Entertainment"], date)
  end
end

# Cineplex visits: ~monthly
(start_date..end_date).each do |date|
  next unless date.day == rng.rand(18..24) && rng.rand < 0.7
  create_txn!([cibc_cc, scotia_cc].sample(random: rng), rng.rand(30..55), "Cineplex", cat["Entertainment"], date)
end

# Healthcare: occasional
40.times do
  date = all_days.sample(random: rng)
  amount = rng.rand(25..150)
  create_txn!([cibc_chk, scotia_chk].sample(random: rng), amount,
              ["Shoppers Drug Mart", "Rexall", "Dr. Visit Copay"].sample(random: rng),
              cat["Healthcare"], date)
end

# Personal care: occasional
25.times do
  date = all_days.sample(random: rng)
  amount = rng.rand(30..90)
  create_txn!([cibc_chk, cibc_cc].sample(random: rng), amount,
              ["Hair Salon", "Barber", "Spa"].sample(random: rng),
              cat["Personal Care"], date)
end

# ============================================================================
# 6. CREDIT CARD PAYOFFS — Full balance on 25th from associated checking
# ============================================================================
puts "  Generating credit card payoffs..."

cc_pairs = [
  [cibc_cc, cibc_chk],
  [scotia_cc, scotia_chk],
  [bmo_cc, bmo_chk]
]

(start_date..end_date).each do |date|
  next unless date.day == 25

  cc_pairs.each do |cc, chk|
    # Sum charges for the month on this card
    month_start = date.beginning_of_month
    month_charges = cc.entries
                      .where(date: month_start..date, entryable_type: "Transaction")
                      .where("amount > 0")
                      .sum(:amount)

    next unless month_charges > 0

    create_transfer!(chk, cc, month_charges.round, "Credit Card Payment", date)
  end
end

# ============================================================================
# 7. SAVINGS & INVESTMENT CONTRIBUTIONS
# ============================================================================
puts "  Generating savings and investment contributions..."

(start_date..end_date).each do |date|
  next unless date.day == 10

  # Wife: CIBC Checking → CIBC Savings ($400/mo)
  create_transfer!(cibc_chk, cibc_sav, 400, "Savings Transfer", date)

  # Husband: Scotia Checking → Scotia Savings ($200/mo)
  create_transfer!(scotia_chk, scotia_sav, 200, "Savings Transfer", date)

  # Wife: CIBC Checking → Manulife RRSP ($500/mo) - as a transaction (investment contribution)
  create_txn!(cibc_chk, 500, "RRSP Contribution", cat["Miscellaneous"], date)

  # Wife: CIBC Checking → Wealthsimple TFSA ($300/mo)
  create_txn!(cibc_chk, 300, "TFSA Contribution", cat["Miscellaneous"], date)
end

# Husband's investment contributions start Jan 2025
(Date.new(2025, 1, 1)..end_date).each do |date|
  next unless date.day == 12

  create_txn!(scotia_chk, 400, "RRSP Contribution", cat["Miscellaneous"], date)
  create_txn!(scotia_chk, 250, "TFSA Contribution", cat["Miscellaneous"], date)
end

# ============================================================================
# Summary
# ============================================================================
total = family.entries.count
puts "  Generated #{total} entries"
puts "Transactions seed completed!"
