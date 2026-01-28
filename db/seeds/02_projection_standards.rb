# 🇨🇦 Seed data for projection standards
# Seeds PAG 2025 (FP Canada Projection Assumption Guidelines)

puts "Seeding projection standards..."

canada = Jurisdiction.find_by(country_code: "CA")

unless canada
  puts "  Skipping projection standards - Canada jurisdiction not found"
  puts "  Run jurisdiction seeds first"
  return
end

# 🇨🇦 PAG 2025 - FP Canada's Projection Assumption Guidelines
pag_2025 = ProjectionStandard.find_or_create_by!(
  jurisdiction: canada,
  code: "PAG_2025"
) do |ps|
  ps.name = "FP Canada PAG 2025"
  ps.effective_year = 2025

  # PAG 2025 assumptions (nominal returns before inflation)
  ps.equity_return = 0.0628           # 6.28% - Canadian equities
  ps.fixed_income_return = 0.0409     # 4.09% - Canadian fixed income
  ps.cash_return = 0.0295             # 2.95% - Short-term/cash
  ps.inflation_rate = 0.021           # 2.10% - Expected inflation

  # Volatility assumptions for Monte Carlo
  ps.volatility_equity = 0.18         # 18% standard deviation
  ps.volatility_fixed_income = 0.05   # 5% standard deviation

  ps.metadata = {
    "source" => "FP Canada",
    "effective_date" => "2025-01-01",
    "review_cycle" => "annual",
    "notes" => "Official projection assumptions for Canadian financial planning",
    "asset_allocation_examples" => {
      "conservative" => { "equity" => 0.30, "fixed_income" => 0.50, "cash" => 0.20 },
      "balanced" => { "equity" => 0.60, "fixed_income" => 0.30, "cash" => 0.10 },
      "growth" => { "equity" => 0.80, "fixed_income" => 0.15, "cash" => 0.05 }
    },
    "real_returns" => {
      "equity" => 0.0409,        # 6.28% - 2.10% inflation = 4.18% (approx)
      "fixed_income" => 0.0195,  # 4.09% - 2.10% inflation = 1.99% (approx)
      "cash" => 0.0083           # 2.95% - 2.10% inflation = 0.85% (approx)
    }
  }
end

puts "  Created projection standard: PAG 2025"

# 🔧 Extensibility: Future standards
# CFP Board assumptions for US (future)
# if us = Jurisdiction.find_by(country_code: "US")
#   ProjectionStandard.find_or_create_by!(
#     jurisdiction: us,
#     code: "CFP_2025"
#   ) do |ps|
#     ps.name = "CFP Board 2025"
#     ps.effective_year = 2025
#     ps.equity_return = 0.07        # Placeholder
#     ps.fixed_income_return = 0.04  # Placeholder
#     ps.cash_return = 0.03          # Placeholder
#     ps.inflation_rate = 0.025      # Placeholder
#     ps.metadata = { "status" => "placeholder" }
#   end
# end

puts "Projection standards seeded successfully!"
