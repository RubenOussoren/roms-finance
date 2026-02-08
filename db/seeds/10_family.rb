# Seed: Canadian demo family with two users, categories, and subscription
#
# Creates a realistic Canadian household for demonstrating joint accounts,
# per-user privacy controls, Smith Manoeuvre, and investment projections.

puts "Seeding demo family..."

# Idempotency guard
if Family.exists?(currency: "CAD")
  puts "  Demo family already exists, skipping..."
  return
end

rng = Random.new(42)

# ============================================================================
# A. Family
# ============================================================================
family = Family.create!(
  name: "The Morrison Family",
  currency: "CAD",
  country: "CA",
  locale: "en",
  timezone: "America/Toronto",
  date_format: "%Y-%m-%d"
)

puts "  Created family: #{family.name} (#{family.country}/#{family.currency})"

# ============================================================================
# B. Users
# ============================================================================
husband = family.users.create!(
  email: "admin@roms.local",
  first_name: "James",
  last_name: "Morrison",
  role: "admin",
  password: "password",
  onboarded_at: 2.years.ago
)

wife = family.users.create!(
  email: "member@roms.local",
  first_name: "Sarah",
  last_name: "Morrison",
  role: "member",
  password: "password",
  onboarded_at: 2.years.ago
)

puts "  Created users: #{husband.email} (admin), #{wife.email} (member)"

# ============================================================================
# C. Subscription
# ============================================================================
family.create_subscription!(
  status: "trialing",
  trial_ends_at: 1.year.from_now
)
puts "  Created trialing subscription"

# ============================================================================
# D. Categories
# ============================================================================

# Income
family.categories.create!(name: "Salary", color: "#10b981", classification: "income")
family.categories.create!(name: "Rental Income", color: "#059669", classification: "income")
family.categories.create!(name: "Investment Income", color: "#047857", classification: "income")

# Expense — top-level with subcategories
housing = family.categories.create!(name: "Housing", color: "#dc2626", classification: "expense")
family.categories.create!(name: "Mortgage", parent: housing, color: "#b91c1c", classification: "expense")
family.categories.create!(name: "Utilities", parent: housing, color: "#991b1b", classification: "expense")
family.categories.create!(name: "Property Tax", parent: housing, color: "#7f1d1d", classification: "expense")

food = family.categories.create!(name: "Food & Dining", color: "#ea580c", classification: "expense")
family.categories.create!(name: "Groceries", parent: food, color: "#c2410c", classification: "expense")
family.categories.create!(name: "Dining Out", parent: food, color: "#9a3412", classification: "expense")

family.categories.create!(name: "Transportation", color: "#2563eb", classification: "expense")
family.categories.create!(name: "Insurance", color: "#6366f1", classification: "expense")
family.categories.create!(name: "Shopping", color: "#059669", classification: "expense")
family.categories.create!(name: "Entertainment", color: "#7c3aed", classification: "expense")
family.categories.create!(name: "Healthcare", color: "#db2777", classification: "expense")
family.categories.create!(name: "Personal Care", color: "#be185d", classification: "expense")
family.categories.create!(name: "Rental Expenses", color: "#475569", classification: "expense")
family.categories.create!(name: "Loan Interest", color: "#64748b", classification: "expense")
family.categories.create!(name: "Miscellaneous", color: "#6b7280", classification: "expense")

puts "  Created #{family.categories.count} categories"
puts "Family seed completed!"
