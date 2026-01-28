# 🇨🇦 Seed data for Canadian Modified Smith Manoeuvre debt optimization

# Only run if we have the Canadian test family
family = Family.find_by(currency: "CAD")
return unless family.present?

puts "Creating debt optimization test data..."

# Find Canada jurisdiction
jurisdiction = Jurisdiction.find_by(country_code: "CA")

# Create primary mortgage account
# HELOC Tool defaults: $775,000 current balance @ 4.9% fixed, 30 years
# Original loan was $815,000 - shows 2 years of paydown
primary_mortgage_loan = Loan.create!(
  interest_rate: 4.90,
  term_months: 360, # 30 years
  rate_type: "fixed",
  initial_balance: 815_000  # Original loan amount (2 years ago)
)

primary_mortgage = Account.create!(
  family: family,
  name: "Primary Residence Mortgage",
  balance: -775_000,
  currency: "CAD",
  accountable: primary_mortgage_loan,
  status: "active"
)
puts "  Created primary mortgage: #{primary_mortgage.name}"

# Create HELOC account
# HELOC Tool defaults: $45,000 limit @ 5.15% variable, max readvanceable cap $820,000
heloc_loan = Loan.create!(
  interest_rate: 5.15,
  rate_type: "variable",
  credit_limit: 45_000
)

heloc = Account.create!(
  family: family,
  name: "Home Equity Line of Credit",
  balance: 0,
  currency: "CAD",
  accountable: heloc_loan,
  status: "active"
)
# Store max readvanceable limit in account notes (no DB field for this)
heloc.update!(locked_attributes: { max_readvanceable_limit: 820_000 })
puts "  Created HELOC: #{heloc.name} (max readvanceable: $820,000)"

# Create rental property mortgage
# HELOC Tool defaults: $350,000 current balance @ 4.05% fixed, 30 years
# Original loan was $380,000 - shows 2 years of paydown
rental_mortgage_loan = Loan.create!(
  interest_rate: 4.05,
  term_months: 360, # 30 years
  rate_type: "fixed",
  initial_balance: 380_000  # Original loan amount (2 years ago)
)

rental_mortgage = Account.create!(
  family: family,
  name: "Rental Property Mortgage",
  balance: -350_000,
  currency: "CAD",
  accountable: rental_mortgage_loan,
  status: "active"
)
puts "  Created rental mortgage: #{rental_mortgage.name}"

# ============================================================================
# Add Opening Valuations (CRITICAL for LoanPayoffCalculator)
# ============================================================================
puts "  Adding opening valuations for mortgage accounts..."

# Primary Mortgage - opening valuation 2 years ago at original loan amount
primary_mortgage.entries.create!(
  entryable: Valuation.new(kind: "opening_anchor"),
  amount: 815_000.00, # Original mortgage amount 2 years ago
  name: Valuation.build_opening_anchor_name(primary_mortgage.accountable_type),
  currency: "CAD",
  date: 2.years.ago.to_date
)

# Primary Mortgage - current anchor showing paydown to $775,000
primary_mortgage.entries.create!(
  entryable: Valuation.new(kind: "current_anchor"),
  amount: 775_000.00, # Current balance after 2 years of payments
  name: Valuation.build_current_anchor_name(primary_mortgage.accountable_type),
  currency: "CAD",
  date: Date.current
)

# Rental Mortgage - opening valuation 2 years ago at original loan amount
rental_mortgage.entries.create!(
  entryable: Valuation.new(kind: "opening_anchor"),
  amount: 380_000.00, # Original mortgage amount 2 years ago
  name: Valuation.build_opening_anchor_name(rental_mortgage.accountable_type),
  currency: "CAD",
  date: 2.years.ago.to_date
)

# Rental Mortgage - current anchor showing paydown to $350,000
rental_mortgage.entries.create!(
  entryable: Valuation.new(kind: "current_anchor"),
  amount: 350_000.00, # Current balance after 2 years of payments
  name: Valuation.build_current_anchor_name(rental_mortgage.accountable_type),
  currency: "CAD",
  date: Date.current
)

# HELOC - credit line activation (set up when house was bought 2 years ago)
heloc.entries.create!(
  entryable: Valuation.new(kind: "opening_anchor"),
  amount: 0.00, # HELOC started with zero balance
  name: Valuation.build_opening_anchor_name(heloc.accountable_type),
  currency: "CAD",
  date: 2.years.ago.to_date
)

puts "    Added opening valuations for mortgage accounts"

# Create the debt optimization strategy
# HELOC Tool defaults:
# - Gross monthly rent: $1,900
# - Property management fees: $95/mo
# - Other rental expenses: $797/mo
# - Net rental income: $1,805/mo (we store gross - total expenses = $1,900 - $892 = $1,008 net cash flow)
# - Marginal tax rate: 45%
# - Household income: $329,000
strategy = DebtOptimizationStrategy.create!(
  family: family,
  jurisdiction: jurisdiction,
  name: "Smith Manoeuvre - Rental Property",
  strategy_type: "modified_smith",
  status: "draft",
  primary_mortgage: primary_mortgage,
  heloc: heloc,
  rental_mortgage: rental_mortgage,
  rental_income: 1900,                      # Gross monthly rent
  rental_expenses: 892,                     # Property mgmt ($95) + other ($797) = $892
  heloc_interest_rate: 5.15,                # Match HELOC rate
  simulation_months: 360,                   # 30 years to match mortgage terms
  currency: "CAD",
  metadata: {
    marginal_tax_rate: 0.45,                # 45% marginal tax rate
    household_income: 329_000,              # Annual household income
    property_management_fee: 95,            # Monthly property management fee
    other_rental_expenses: 797,             # Monthly other rental expenses
    gross_monthly_rent: 1900,
    net_rental_income: 1008                 # $1,900 - $892 = $1,008 net cash flow
  }
)
puts "  Created strategy: #{strategy.name}"

# Add auto-stop rules
strategy.auto_stop_rules.create!(
  rule_type: "heloc_limit_percentage",
  threshold_value: 95,
  threshold_unit: "percentage",
  enabled: true
)

strategy.auto_stop_rules.create!(
  rule_type: "primary_paid_off",
  enabled: true
)

strategy.auto_stop_rules.create!(
  rule_type: "heloc_interest_exceeds_benefit",
  enabled: false # Disabled by default, user can enable
)
puts "  Created auto-stop rules"

# ============================================================================
# Fix Milestone Progress (milestones are auto-created with current balance as starting_balance)
# ============================================================================
puts "  Updating milestone progress for mortgage accounts..."

# Primary Residence Mortgage: original $815K, current $775K
# Update starting_balance to reflect original loan amount
primary_mortgage.milestones.update_all(starting_balance: 815_000)
primary_mortgage.milestones.each { |m| m.update_progress!(primary_mortgage.balance.abs) }

# Rental Property Mortgage: original $380K, current $350K
rental_mortgage.milestones.update_all(starting_balance: 380_000)
rental_mortgage.milestones.each { |m| m.update_progress!(rental_mortgage.balance.abs) }

puts "    Updated milestone progress for mortgage accounts"

puts "Debt optimization seed data created successfully!"
puts ""
puts "To run the simulation:"
puts "  1. Start your development server: bin/dev"
puts "  2. Log in as test.canadian@example.com / password123"
puts "  3. Navigate to /debt_optimization_strategies"
puts "  4. Click 'Run Simulation' on the Smith Manoeuvre strategy"
