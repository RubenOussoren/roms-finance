# 🇨🇦 Seed data for Canadian Modified Smith Manoeuvre debt optimization

# Only run if we have the Canadian test family
family = Family.find_by(currency: "CAD")
return unless family.present?

puts "Creating debt optimization test data..."

# Find Canada jurisdiction
jurisdiction = Jurisdiction.find_by(country_code: "CA")

# Create primary mortgage account
primary_mortgage_loan = Loan.create!(
  interest_rate: 5.25,
  term_months: 300, # 25 years
  rate_type: "fixed"
)

primary_mortgage = Account.create!(
  family: family,
  name: "Primary Residence Mortgage",
  balance: -450000,
  currency: "CAD",
  accountable: primary_mortgage_loan,
  status: "active"
)
puts "  Created primary mortgage: #{primary_mortgage.name}"

# Create HELOC account
heloc_loan = Loan.create!(
  interest_rate: 7.20,
  rate_type: "variable",
  credit_limit: 150000
)

heloc = Account.create!(
  family: family,
  name: "Home Equity Line of Credit",
  balance: 0,
  currency: "CAD",
  accountable: heloc_loan,
  status: "active"
)
puts "  Created HELOC: #{heloc.name}"

# Create rental property mortgage
rental_mortgage_loan = Loan.create!(
  interest_rate: 5.75,
  term_months: 240, # 20 years
  rate_type: "fixed"
)

rental_mortgage = Account.create!(
  family: family,
  name: "Rental Property Mortgage",
  balance: -280000,
  currency: "CAD",
  accountable: rental_mortgage_loan,
  status: "active"
)
puts "  Created rental mortgage: #{rental_mortgage.name}"

# Create the debt optimization strategy
strategy = DebtOptimizationStrategy.create!(
  family: family,
  jurisdiction: jurisdiction,
  name: "Smith Manoeuvre - Rental Property",
  strategy_type: "modified_smith",
  status: "draft",
  primary_mortgage: primary_mortgage,
  heloc: heloc,
  rental_mortgage: rental_mortgage,
  rental_income: 2800,
  rental_expenses: 650,
  heloc_interest_rate: 7.20,
  simulation_months: 240, # 20 years
  currency: "CAD"
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

puts "Debt optimization seed data created successfully!"
puts ""
puts "To run the simulation:"
puts "  1. Start your development server: bin/dev"
puts "  2. Log in as test.canadian@example.com / password123"
puts "  3. Navigate to /debt_optimization_strategies"
puts "  4. Click 'Run Simulation' on the Smith Manoeuvre strategy"
