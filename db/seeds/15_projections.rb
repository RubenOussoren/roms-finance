# Seed: Projection assumptions and future projections
#
# Creates PAG-compliant default, conservative, and aggressive assumptions,
# then generates 60-month future projections for investment accounts.

puts "Seeding projections..."

family = Family.find_by(currency: "CAD")
return unless family

pag_2025 = ProjectionStandard.find_by(code: "PAG_2025")

unless pag_2025
  puts "  Skipping projections - PAG 2025 standard not found"
  return
end

# ============================================================================
# A. Projection Assumptions
# ============================================================================
puts "  Creating projection assumptions..."

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

ProjectionAssumption.create!(
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

ProjectionAssumption.create!(
  family: family,
  projection_standard: nil,
  name: "Aggressive Growth",
  expected_return: 0.15,
  inflation_rate: 0.02,
  volatility: 0.25,
  monthly_contribution: 1_000,
  use_pag_defaults: false,
  is_active: false
)

puts "    Created #{family.projection_assumptions.count} assumptions"

# ============================================================================
# B. Future Projections (60 months)
# ============================================================================
puts "  Creating future projections..."

investment_accounts = family.accounts.where(accountable_type: %w[Investment])

investment_accounts.each do |account|
  calculator = ProjectionCalculator.new(
    principal: account.balance,
    rate: pag_assumption.effective_return,
    contribution: pag_assumption.monthly_contribution,
    currency: account.currency
  )

  volatility = pag_assumption.effective_volatility
  monthly_vol = volatility / Math.sqrt(12)

  60.times do |i|
    month = i + 1
    projection_date = (Date.current + month.months).end_of_month
    projected_balance = calculator.future_value_at_month(month)
    spread = projected_balance * monthly_vol * Math.sqrt(month)

    Account::Projection.create!(
      account: account,
      projection_assumption: pag_assumption,
      projection_date: projection_date,
      projected_balance: projected_balance.round(2),
      actual_balance: nil,
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

  # Update milestone projections
  account.update_milestone_projections!
end

future_count = Account::Projection.future.count
puts "    Created #{future_count} future projections across #{investment_accounts.count} accounts"
puts "Projections seed completed!"
