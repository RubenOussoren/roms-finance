# Seed: Sync accounts, apply current anchors, and reconcile balances
#
# This runs last to ensure all accounts have proper balance records
# and milestone progress is up to date.

puts "Finalizing seed data..."

family = Family.find_by(currency: "CAD")
return unless family

# ============================================================================
# A. Apply current_anchor valuations to force target ending balances
# ============================================================================
puts "  Applying current anchor valuations..."

target_balances = {
  "Primary Residence"           =>  1_050_000,
  "Primary Mortgage"            =>    830_000,
  "HELOC"                       =>     13_087.83,
  "Investment Property"         =>    450_000,
  "Rental Mortgage"             =>    350_000,
  "CIBC Checking"               =>      8_000,
  "CIBC Savings"                =>     12_000,
  "Scotia Checking"             =>      7_000,
  "Scotia Savings"              =>      3_000,
  "BMO Checking"                =>     10_000
}

target_balances.each do |account_name, target|
  account = family.accounts.find_by(name: account_name)
  next unless account

  # Skip if already has a current anchor
  next if account.entries.joins("INNER JOIN valuations ON valuations.id = entries.entryable_id")
                 .where(entryable_type: "Valuation")
                 .where(valuations: { kind: "current_anchor" })
                 .exists?

  account.entries.create!(
    entryable: Valuation.new(kind: "current_anchor"),
    amount: target,
    name: Valuation.build_current_anchor_name(account.accountable_type),
    currency: "CAD",
    date: Date.current
  )
end

# ============================================================================
# B. Sync all accounts to generate balance records
# ============================================================================
puts "  Syncing #{family.accounts.count} accounts..."

family.accounts.find_each do |account|
  sync = Sync.create!(syncable: account)
  sync.perform
end

puts "  Sync complete"

# ============================================================================
# C. Update milestone progress
# ============================================================================
puts "  Updating milestones..."

family.accounts.where(accountable_type: %w[Loan]).find_each do |account|
  account.milestones.each { |m| m.update_progress!(account.balance.abs) }
end

family.accounts.where(accountable_type: %w[Investment]).find_each do |account|
  account.milestones.each { |m| m.update_progress!(account.balance) }
end

# ============================================================================
# Summary
# ============================================================================
total_entries = family.entries.count
total_accounts = family.accounts.count
total_balances = Balance.joins(:account).where(accounts: { family_id: family.id }).count

puts ""
puts "Seed data finalized!"
puts "  Accounts: #{total_accounts}"
puts "  Entries: #{total_entries}"
puts "  Balance records: #{total_balances}"
puts ""
puts "Login credentials:"
puts "  Admin: admin@roms.local / password"
puts "  Member: member@roms.local / password"
