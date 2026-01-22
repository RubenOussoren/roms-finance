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
  onboarded_at: Time.current
)

puts "    Created family: #{family.name} (#{family.country}/#{family.currency})"
puts "    Created user: #{user.email}"

# ============================================================================
# B. Canadian Investment Accounts
# ============================================================================
puts "  Creating investment accounts..."

# TFSA Account (~$50K)
tfsa = Account.create!(
  family: family,
  name: "TFSA",
  balance: 52_345.67,
  cash_balance: 52_345.67,
  currency: "CAD",
  subtype: "retirement",
  accountable: Investment.create!
)

# RRSP Account (~$100K)
rrsp = Account.create!(
  family: family,
  name: "RRSP",
  balance: 103_456.78,
  cash_balance: 103_456.78,
  currency: "CAD",
  subtype: "retirement",
  accountable: Investment.create!
)

# Non-registered Brokerage (~$30K)
brokerage = Account.create!(
  family: family,
  name: "Non-Registered Brokerage",
  balance: 31_234.56,
  cash_balance: 31_234.56,
  currency: "CAD",
  subtype: "brokerage",
  accountable: Investment.create!
)

# HELOC for Smith Manoeuvre testing
heloc = Account.create!(
  family: family,
  name: "HELOC",
  balance: -75_000.00,  # Liability (negative)
  cash_balance: -75_000.00,
  currency: "CAD",
  subtype: "other",
  accountable: Loan.create!(
    rate_type: "variable",
    interest_rate: 7.20,
    initial_balance: 150_000
  )
)

investment_accounts = [ tfsa, rrsp, brokerage ]
puts "    Created accounts: #{investment_accounts.map(&:name).join(', ')}, #{heloc.name}"

# ============================================================================
# C. Milestones for Investment Accounts
# ============================================================================
puts "  Creating milestones..."

investment_accounts.each do |account|
  # Create standard milestones
  Milestone.create_standard_milestones_for(account)

  # Update progress based on current balance
  account.milestones.each { |m| m.update_progress!(account.balance) }

  # Add custom milestone
  Milestone.create!(
    account: account,
    name: "Retirement Goal",
    target_amount: 500_000,
    currency: account.currency,
    target_date: 20.years.from_now.to_date,
    is_custom: true,
    status: account.balance >= 500_000 ? "achieved" : "in_progress",
    progress_percentage: [ (account.balance / 500_000 * 100), 100 ].min.round(2)
  )
end

total_milestones = Milestone.where(account: investment_accounts).count
puts "    Created #{total_milestones} milestones across #{investment_accounts.count} accounts"

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
# E. Historical Projections with Actuals (12 months back)
# ============================================================================
puts "  Creating historical projections..."

investment_accounts.each do |account|
  calculator = ProjectionCalculator.new(
    principal: account.balance * 0.85, # Estimate starting balance 12 months ago
    rate: pag_assumption.effective_return,
    contribution: pag_assumption.monthly_contribution,
    currency: account.currency
  )

  12.times do |i|
    month_offset = 11 - i # 11, 10, 9, ... 0
    projection_date = (Date.current - month_offset.months).end_of_month
    projected_balance = calculator.future_value_at_month(12 - month_offset)

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

investment_accounts.each do |account|
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
    monthly_rate = pag_assumption.effective_return / 12

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
puts "  - Total milestones: #{Milestone.where(account: investment_accounts).count}"
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
