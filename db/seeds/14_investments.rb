# Seed: Securities, price history, and trades
#
# Creates Canadian ETFs + crypto securities with 37 months of daily prices,
# then generates buy trades for each investment/crypto account.

puts "Seeding investments..."

family = Family.find_by(currency: "CAD")
return unless family

# Skip if already seeded
if Security.exists?(ticker: "VCN")
  puts "  Investment data already exists, skipping..."
  return
end

rng = Random.new(42)

# ============================================================================
# A. Securities
# ============================================================================
puts "  Creating securities..."

securities_data = [
  { ticker: "VCN",  name: "Vanguard FTSE Canada All Cap Index ETF",      exchange: "XTSE", base_price: 40.00, drift: 0.08 },
  { ticker: "XUU",  name: "iShares Core S&P U.S. Total Market Index ETF", exchange: "XTSE", base_price: 45.00, drift: 0.10 },
  { ticker: "XEF",  name: "iShares Core MSCI EAFE IMI Index ETF",         exchange: "XTSE", base_price: 35.00, drift: 0.06 },
  { ticker: "XEC",  name: "iShares Core MSCI Emerging Markets IMI Index ETF", exchange: "XTSE", base_price: 28.00, drift: 0.05 },
  { ticker: "BTC",  name: "Bitcoin",   exchange: nil, base_price: 55_000.00, drift: 0.15 },
  { ticker: "ETH",  name: "Ethereum",  exchange: nil, base_price: 3_200.00,  drift: 0.10 }
]

securities = {}
price_start = Date.new(2023, 1, 1)

securities_data.each do |sec_data|
  security = Security.create!(
    ticker: sec_data[:ticker],
    name: sec_data[:name],
    country_code: sec_data[:exchange] ? "CA" : nil,
    exchange_operating_mic: sec_data[:exchange]
  )
  securities[sec_data[:ticker]] = security

  # Generate daily prices with random walk + drift
  price = sec_data[:base_price]
  daily_drift = sec_data[:drift] / 252.0
  daily_vol = sec_data[:ticker].in?(["BTC", "ETH"]) ? 0.03 : 0.012

  (price_start..Date.current).each do |date|
    next if date.saturday? || date.sunday?

    shock = daily_vol * (rng.rand * 2 - 1)
    price = price * (1 + daily_drift + shock)
    price = [price, 0.01].max

    Security::Price.create!(
      security: security,
      date: date,
      price: price.round(4),
      currency: "CAD"
    )
  end

  puts "    #{sec_data[:ticker]}: #{security.prices.count} prices, latest $#{price.round(2)}"
end

# ============================================================================
# B. Account lookups
# ============================================================================
accts = {}
family.accounts.each { |a| accts[a.name] = a }

manulife_rrsp    = accts["Manulife RRSP"]
ws_rrsp_wife     = accts["Wealthsimple RRSP"]      # wife's — first match by created_by
ws_tfsa_wife     = accts["Wealthsimple TFSA"]       # wife's
ws_rrsp_husband  = nil
ws_tfsa_husband  = nil
ws_crypto        = accts["Wealthsimple Crypto"]
ws_nonreg        = accts["Wealthsimple Non-Registered"]

husband = family.users.find_by(email: "admin@roms.local")
wife    = family.users.find_by(email: "member@roms.local")

# Disambiguate duplicate-named accounts by owner
family.accounts.where(name: "Wealthsimple RRSP").each do |a|
  if a.created_by_user_id == wife.id
    ws_rrsp_wife = a
  else
    ws_rrsp_husband = a
  end
end

family.accounts.where(name: "Wealthsimple TFSA").each do |a|
  if a.created_by_user_id == wife.id
    ws_tfsa_wife = a
  else
    ws_tfsa_husband = a
  end
end

# ============================================================================
# C. Helper: create trade entry
# ============================================================================
def create_trade!(account, security, qty, price, date, name)
  account.entries.create!(
    entryable: Trade.new(security: security, qty: qty, price: price, currency: account.currency),
    amount: -(qty * price).round(2),
    name: name,
    currency: account.currency,
    date: date
  )
end

# ============================================================================
# D. Trades per account
# ============================================================================
puts "  Generating trades..."

vcn = securities["VCN"]
xuu = securities["XUU"]
xef = securities["XEF"]
xec = securities["XEC"]
btc = securities["BTC"]
eth = securities["ETH"]

# Helper to get price on a date
def price_on(security, date)
  security.prices.where("date <= ?", date).order(date: :desc).first&.price || 40.0
end

# --- Manulife RRSP (~$45,000): Monthly VCN + XEF, 37 months ---
if manulife_rrsp
  cursor = Date.new(2023, 1, 15)
  while cursor <= Date.current
    p_vcn = price_on(vcn, cursor)
    p_xef = price_on(xef, cursor)
    create_trade!(manulife_rrsp, vcn, (350.0 / p_vcn).round(4), p_vcn, cursor, "Buy VCN")
    create_trade!(manulife_rrsp, xef, (150.0 / p_xef).round(4), p_xef, cursor, "Buy XEF")
    cursor = cursor.next_month
  end
  puts "    Manulife RRSP: #{manulife_rrsp.entries.where(entryable_type: 'Trade').count} trades"
end

# --- Wealthsimple RRSP wife (~$120): Small initial purchase Dec 2025 ---
if ws_rrsp_wife
  date = Date.new(2025, 12, 15)
  p_vcn = price_on(vcn, date)
  create_trade!(ws_rrsp_wife, vcn, (120.0 / p_vcn).round(4), p_vcn, date, "Buy VCN")
  puts "    WS RRSP (wife): 1 trade"
end

# --- Wealthsimple TFSA wife (~$21,300): Monthly VCN + XUU, 37 months ---
if ws_tfsa_wife
  cursor = Date.new(2023, 1, 20)
  while cursor <= Date.current
    p_vcn = price_on(vcn, cursor)
    p_xuu = price_on(xuu, cursor)
    create_trade!(ws_tfsa_wife, vcn, (150.0 / p_vcn).round(4), p_vcn, cursor, "Buy VCN")
    create_trade!(ws_tfsa_wife, xuu, (150.0 / p_xuu).round(4), p_xuu, cursor, "Buy XUU")
    cursor = cursor.next_month
  end
  puts "    WS TFSA (wife): #{ws_tfsa_wife.entries.where(entryable_type: 'Trade').count} trades"
end

# --- Wealthsimple RRSP husband (~$8,600): Monthly XUU + XEF, ~13 months (Jan 2025+) ---
if ws_rrsp_husband
  cursor = Date.new(2025, 1, 18)
  while cursor <= Date.current
    p_xuu = price_on(xuu, cursor)
    p_xef = price_on(xef, cursor)
    create_trade!(ws_rrsp_husband, xuu, (250.0 / p_xuu).round(4), p_xuu, cursor, "Buy XUU")
    create_trade!(ws_rrsp_husband, xef, (150.0 / p_xef).round(4), p_xef, cursor, "Buy XEF")
    cursor = cursor.next_month
  end
  puts "    WS RRSP (husband): #{ws_rrsp_husband.entries.where(entryable_type: 'Trade').count} trades"
end

# --- Wealthsimple TFSA husband (~$3,200): Monthly VCN, ~12 months (Feb 2025+) ---
if ws_tfsa_husband
  cursor = Date.new(2025, 2, 18)
  while cursor <= Date.current
    p_vcn = price_on(vcn, cursor)
    create_trade!(ws_tfsa_husband, vcn, (250.0 / p_vcn).round(4), p_vcn, cursor, "Buy VCN")
    cursor = cursor.next_month
  end
  puts "    WS TFSA (husband): #{ws_tfsa_husband.entries.where(entryable_type: 'Trade').count} trades"
end

# --- Wealthsimple Crypto (~$1,000): BTC + ETH purchases ---
if ws_crypto
  # $700 BTC + $300 ETH spread over a few purchases
  [
    [Date.new(2025, 6, 15), btc, 500],
    [Date.new(2025, 8, 10), btc, 200],
    [Date.new(2025, 7, 1),  eth, 200],
    [Date.new(2025, 9, 15), eth, 100]
  ].each do |date, security, amount|
    price = price_on(security, date)
    qty = (amount.to_f / price).round(6)
    create_trade!(ws_crypto, security, qty, price, date, "Buy #{security.ticker}")
  end
  puts "    WS Crypto: 4 trades"
end

# --- Wealthsimple Non-Registered joint (~$600): Small XUU position ---
if ws_nonreg
  date = Date.new(2025, 10, 15)
  p_xuu = price_on(xuu, date)
  create_trade!(ws_nonreg, xuu, (600.0 / p_xuu).round(4), p_xuu, date, "Buy XUU")
  puts "    WS Non-Reg: 1 trade"
end

total_trades = family.entries.where(entryable_type: "Trade").count
puts "  Total trades: #{total_trades}"
puts "Investments seed completed!"
