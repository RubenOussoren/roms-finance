# 🇨🇦 Seed data for jurisdictions
# Seeds Canada as the default jurisdiction with placeholder for future expansion

puts "Seeding jurisdictions..."

# 🇨🇦 Canada - Primary jurisdiction with full support
canada = Jurisdiction.find_or_create_by!(country_code: "CA") do |j|
  j.name = "Canada"
  j.currency_code = "CAD"
  j.interest_deductible = true
  j.has_smith_manoeuvre = true
  j.tax_config = {
    "brackets" => [
      { "min" => 0, "max" => 55867, "rate" => 0.15 },
      { "min" => 55867, "max" => 111733, "rate" => 0.205 },
      { "min" => 111733, "max" => 173205, "rate" => 0.26 },
      { "min" => 173205, "max" => 246752, "rate" => 0.29 },
      { "min" => 246752, "max" => nil, "rate" => 0.33 }
    ],
    "capital_gains_inclusion" => 0.50,
    "dividend_gross_up" => 1.38,
    "dividend_tax_credit" => 0.150198
  }
  j.metadata = {
    "tax_year" => 2025,
    "source" => "CRA",
    "notes" => "Federal tax brackets only. Provincial rates vary."
  }
end

puts "  Created jurisdiction: Canada (CA)"

# 🔧 Extensibility: Placeholder jurisdictions for future support
# 🇺🇸 United States (future)
# us = Jurisdiction.find_or_create_by!(country_code: "US") do |j|
#   j.name = "United States"
#   j.currency_code = "USD"
#   j.interest_deductible = false  # Mortgage interest deductible, HELOC varies
#   j.has_smith_manoeuvre = false
#   j.tax_config = {}
#   j.metadata = { "status" => "placeholder" }
# end

# 🇬🇧 United Kingdom (future)
# uk = Jurisdiction.find_or_create_by!(country_code: "GB") do |j|
#   j.name = "United Kingdom"
#   j.currency_code = "GBP"
#   j.interest_deductible = false
#   j.has_smith_manoeuvre = false
#   j.tax_config = {}
#   j.metadata = { "status" => "placeholder" }
# end

puts "Jurisdictions seeded successfully!"
