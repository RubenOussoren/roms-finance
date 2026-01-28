# Comprehensive projection test data seed
# Creates a Canadian family with investment accounts, milestones, and projections
# for testing Phase 1 & 2 investment projection features

puts "Seeding projection test data..."

# Skip if already seeded (idempotent)
if Family.exists?(name: "Canadian Test Family")
  puts "  Projection test data already exists, skipping..."
  puts "Projection test data seeded successfully!"
  return
end

# Ensure prerequisites exist
canada = Jurisdiction.find_by(country_code: "CA")
pag_2025 = ProjectionStandard.find_by(code: "PAG_2025")

unless canada && pag_2025
  puts "  Skipping projection test data - run jurisdiction and projection_standards seeds first"
  return
end

# ============================================================================
# A. Canadian Test Family
# ============================================================================
puts "  Creating Canadian test family..."

family = Family.create!(
  name: "Canadian Test Family",
  currency: "CAD",
  country: "CA",
  locale: "en",
  date_format: "%Y-%m-%d"
)

user = User.create!(
  family: family,
  first_name: "Test",
  last_name: "Canadian",
  email: "test.canadian@example.com",
  password: "password123",
  role: "admin",
  onboarded_at: 2.years.ago,  # User has been using app for 2 years
  show_ai_sidebar: false  # Disable Maybe AI sidebar
)

puts "    Created family: #{family.name} (#{family.country}/#{family.currency})"
puts "    Created user: #{user.email}"

# Create subscription (ensures seeded user works even if SELF_HOSTED is disabled)
family.create_subscription!(
  status: "trialing",
  trial_ends_at: 1.year.from_now
)
puts "    Created trialing subscription (expires: #{1.year.from_now.to_date})"

# ============================================================================
# B. Canadian Investment Accounts
# ============================================================================
puts "  Creating investment accounts..."

# HELOC Tool portfolio values:
# RRSP: $8,123.67, TFSA: $2,021.76, Non-Registered: $497.69, Crypto: $1,023.40

# TFSA Account (~$2,022)
tfsa = Account.create!(
  family: family,
  name: "TFSA",
  balance: 2_021.76,
  cash_balance: 0,  # All in holdings
  currency: "CAD",
  subtype: "retirement",
  accountable: Investment.create!
)

# RRSP Account (~$8,124)
rrsp = Account.create!(
  family: family,
  name: "RRSP",
  balance: 8_123.67,
  cash_balance: 0,  # All in holdings
  currency: "CAD",
  subtype: "retirement",
  accountable: Investment.create!
)

# Non-registered Brokerage (~$498)
brokerage = Account.create!(
  family: family,
  name: "Non-Registered Brokerage",
  balance: 497.69,
  cash_balance: 0,  # All in holdings
  currency: "CAD",
  subtype: "brokerage",
  accountable: Investment.create!
)

# Crypto Account (~$1,023)
crypto_account = Account.create!(
  family: family,
  name: "Crypto Portfolio",
  balance: 1_023.40,
  cash_balance: 0,  # All in holdings
  currency: "CAD",
  subtype: "other",
  accountable: Crypto.create!
)

investment_accounts = [ tfsa, rrsp, brokerage, crypto_account ]
puts "    Created accounts: #{investment_accounts.map(&:name).join(', ')}"

# ============================================================================
# B2. Add Opening Valuations (required for balance calculations)
# ============================================================================
puts "  Adding opening valuations..."

# Investment account opening valuations
# Account-specific start dates based on HELOC Tool:
# - RRSP: Dec 2024 (~13 months of trades)
# - TFSA: Nov 2025 (~3 months of trades)
# - Non-registered: Dec 2025 (~2 months of trades)
# - Crypto: Jun 2025 (~8 months of trades)

account_start_dates = {
  "RRSP" => Date.new(2024, 12, 1),
  "TFSA" => Date.new(2025, 11, 1),
  "Non-Registered Brokerage" => Date.new(2025, 12, 1),
  "Crypto Portfolio" => Date.new(2025, 6, 1)
}

investment_accounts.each do |account|
  start_date = account_start_dates[account.name] || 1.year.ago.to_date
  # Opening valuation with zero balance (all value comes from trades/holdings)
  account.entries.create!(
    entryable: Valuation.new(kind: "opening_anchor"),
    amount: 0,  # Started with zero, built up through trades
    name: Valuation.build_opening_anchor_name(account.accountable_type),
    currency: account.currency,
    date: start_date
  )
end

puts "    Added opening valuations for #{investment_accounts.count} accounts"

# ============================================================================
# C. Milestones for Investment Accounts
# ============================================================================
puts "  Creating milestones..."

# Only create milestones for traditional investment accounts (not crypto)
milestone_accounts = investment_accounts.reject { |a| a.accountable_type == "Crypto" }

milestone_accounts.each do |account|
  # Create standard milestones only
  Milestone.create_standard_milestones_for(account)

  # Update progress based on current balance
  account.milestones.each { |m| m.update_progress!(account.balance) }
end

total_milestones = Milestone.where(account: milestone_accounts).count
puts "    Created #{total_milestones} milestones across #{milestone_accounts.count} accounts"

# ============================================================================
# D. Projection Assumptions
# ============================================================================
puts "  Creating projection assumptions..."

# Default PAG-compliant assumption
pag_assumption = ProjectionAssumption.create!(
  family: family,
  projection_standard: pag_2025,
  name: "PAG 2025 Default",
  expected_return: pag_2025.blended_return,
  inflation_rate: pag_2025.inflation_rate,
  volatility: pag_2025.volatility_equity,
  monthly_contribution: 500,
  use_pag_defaults: true,
  is_active: true
)

# Custom conservative assumption
conservative_assumption = ProjectionAssumption.create!(
  family: family,
  projection_standard: pag_2025,
  name: "Conservative",
  expected_return: 0.04,
  inflation_rate: 0.025,
  volatility: 0.10,
  monthly_contribution: 300,
  use_pag_defaults: false,
  is_active: false
)

# Aggressive assumption (tests PAG warnings)
aggressive_assumption = ProjectionAssumption.create!(
  family: family,
  projection_standard: nil,
  name: "Aggressive Growth",
  expected_return: 0.15,  # 15% - exceeds PAG max of 12%
  inflation_rate: 0.02,
  volatility: 0.25,
  monthly_contribution: 1000,
  use_pag_defaults: false,
  is_active: false
)

puts "    Created #{family.projection_assumptions.count} projection assumptions"
puts "    PAG-compliant: #{pag_assumption.pag_compliant?}"

# ============================================================================
# E. Historical Projections with Actuals
# ============================================================================
puts "  Creating historical projections..."

# Only create projections for non-crypto accounts with sufficient history
projection_accounts = investment_accounts.reject { |a| a.accountable_type == "Crypto" }

projection_accounts.each do |account|
  start_date = account_start_dates[account.name]
  months_of_history = ((Date.current - start_date) / 30).to_i.clamp(1, 12)

  calculator = ProjectionCalculator.new(
    principal: account.balance * 0.5, # Estimate starting balance
    rate: pag_assumption.effective_return,
    contribution: pag_assumption.monthly_contribution,
    currency: account.currency
  )

  months_of_history.times do |i|
    month_offset = months_of_history - 1 - i
    projection_date = (Date.current - month_offset.months).end_of_month
    next if projection_date < start_date

    projected_balance = calculator.future_value_at_month(months_of_history - month_offset)

    # Simulate actual performance with some variance (-5% to +5%)
    variance = rand(-0.05..0.05)
    actual_balance = projected_balance * (1 + variance)

    Account::Projection.create!(
      account: account,
      projection_assumption: pag_assumption,
      projection_date: projection_date,
      projected_balance: projected_balance.round(2),
      actual_balance: actual_balance.round(2),
      contribution: pag_assumption.monthly_contribution,
      currency: account.currency,
      is_adaptive: true,
      percentiles: {
        p10: (projected_balance * 0.85).round(2),
        p25: (projected_balance * 0.92).round(2),
        p50: projected_balance.round(2),
        p75: (projected_balance * 1.08).round(2),
        p90: (projected_balance * 1.15).round(2)
      },
      metadata: { source: "seed", month_offset: month_offset }
    )
  end
end

historical_count = Account::Projection.past.count
puts "    Created #{historical_count} historical projections with actuals"

# ============================================================================
# F. Future Projections (60 months forward = 5 years)
# ============================================================================
puts "  Creating future projections..."

# Only create projections for non-crypto accounts
projection_accounts.each do |account|
  calculator = ProjectionCalculator.new(
    principal: account.balance,
    rate: pag_assumption.effective_return,
    contribution: pag_assumption.monthly_contribution,
    currency: account.currency
  )

  60.times do |i|
    month = i + 1
    projection_date = (Date.current + month.months).end_of_month
    projected_balance = calculator.future_value_at_month(month)

    # Generate Monte Carlo percentiles
    volatility = pag_assumption.effective_volatility
    monthly_vol = volatility / Math.sqrt(12)

    # Simplified percentile estimation based on normal distribution
    # Using z-scores: p10=-1.28, p25=-0.67, p50=0, p75=0.67, p90=1.28
    spread = projected_balance * monthly_vol * Math.sqrt(month)

    Account::Projection.create!(
      account: account,
      projection_assumption: pag_assumption,
      projection_date: projection_date,
      projected_balance: projected_balance.round(2),
      actual_balance: nil, # Future - no actuals yet
      contribution: pag_assumption.monthly_contribution,
      currency: account.currency,
      is_adaptive: false,
      percentiles: {
        p10: (projected_balance - 1.28 * spread).round(2),
        p25: (projected_balance - 0.67 * spread).round(2),
        p50: projected_balance.round(2),
        p75: (projected_balance + 0.67 * spread).round(2),
        p90: (projected_balance + 1.28 * spread).round(2)
      },
      metadata: { source: "seed", years_out: (month / 12.0).round(2) }
    )
  end

  # Update milestone projected dates
  account.update_milestone_projections!
end

future_count = Account::Projection.future.count
puts "    Created #{future_count} future projections"

# ============================================================================
# Summary
# ============================================================================
puts ""
puts "Projection test data seeded successfully!"
puts ""
puts "Summary:"
puts "  - Family: #{family.name} (#{family.country})"
puts "  - Investment accounts: #{investment_accounts.count}"
puts "    - RRSP: $#{rrsp.balance.round(2)}"
puts "    - TFSA: $#{tfsa.balance.round(2)}"
puts "    - Non-Registered: $#{brokerage.balance.round(2)}"
puts "    - Crypto: $#{crypto_account.balance.round(2)}"
puts "  - Total milestones: #{Milestone.where(account: milestone_accounts).count}"
puts "  - Projection assumptions: #{family.projection_assumptions.count}"
puts "  - Historical projections: #{historical_count}"
puts "  - Future projections: #{future_count}"
puts "  - PAG compliant: #{family.pag_compliant?}"
puts ""
puts "Test with:"
puts "  rails console"
puts "  > family = Family.find_by(country: 'CA', name: 'Canadian Test Family')"
puts "  > family.pag_compliant?"
puts "  > account = family.accounts.first"
puts "  > account.next_milestone"
puts "  > account.forecast_accuracy"
