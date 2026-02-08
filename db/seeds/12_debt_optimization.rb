# Seed: Smith Manoeuvre debt optimization strategy
#
# Links primary mortgage, HELOC, and rental mortgage into a Modified Smith
# Manoeuvre strategy with auto-stop rules. Pre-simulates to populate ledger.

puts "Seeding debt optimization..."

family = Family.find_by(currency: "CAD")
return unless family

jurisdiction = Jurisdiction.find_by(country_code: "CA")
return unless jurisdiction

primary_mortgage = family.accounts.find_by(name: "Primary Mortgage")
heloc            = family.accounts.find_by(name: "HELOC")
rental_mortgage  = family.accounts.find_by(name: "Rental Mortgage")

unless primary_mortgage && heloc && rental_mortgage
  puts "  Skipping debt optimization - required accounts not found"
  return
end

# ============================================================================
# Strategy
# ============================================================================
strategy = DebtOptimizationStrategy.create!(
  family: family,
  jurisdiction: jurisdiction,
  name: "Smith Manoeuvre - Rental Property",
  strategy_type: "modified_smith",
  status: "draft",
  primary_mortgage: primary_mortgage,
  heloc: heloc,
  rental_mortgage: rental_mortgage,
  rental_income: 1_900,
  rental_expenses: 892,
  heloc_interest_rate: 4.65,
  heloc_max_limit: 660_000,
  heloc_readvanceable: true,
  simulation_months: 360,
  province: "ON",
  currency: "CAD",
  metadata: {
    household_income: 329_000,
    property_management_fee: 95,
    other_rental_expenses: 797,
    gross_monthly_rent: 1_900
  }
)
puts "  Created strategy: #{strategy.name}"

# ============================================================================
# Auto-stop rules
# ============================================================================
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
  enabled: false
)
puts "  Created #{strategy.auto_stop_rules.count} auto-stop rules"

# ============================================================================
# Pre-simulate
# ============================================================================
puts "  Running simulation (this may take a moment)..."
begin
  strategy.run_simulation!
  puts "  Simulation complete: #{strategy.ledger_entries.count} ledger entries"
  puts "    Net benefit: $#{strategy.net_benefit&.round(2)}"
  puts "    Months accelerated: #{strategy.months_accelerated}"
rescue => e
  puts "  Simulation failed: #{e.message}"
  puts "  Strategy saved in draft status — can be simulated via the UI"
end

# ============================================================================
# Fix milestone progress for mortgage accounts
# ============================================================================
puts "  Updating milestone progress..."

[primary_mortgage, rental_mortgage].each do |mortgage|
  initial = mortgage.accountable.initial_balance
  next unless initial&.positive?

  mortgage.milestones.update_all(starting_balance: initial)
  mortgage.milestones.each { |m| m.update_progress!(mortgage.balance.abs) }
end

puts "Debt optimization seed completed!"
