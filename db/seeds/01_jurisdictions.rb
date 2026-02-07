# 🇨🇦 Seed data for jurisdictions
# Seeds Canada as the default jurisdiction with placeholder for future expansion

puts "Seeding jurisdictions..."

# 🇨🇦 Canada - Primary jurisdiction with full support
canada = Jurisdiction.find_or_initialize_by(country_code: "CA")
canada.assign_attributes(
  name: "Canada",
  currency_code: "CAD",
  interest_deductible: true,
  has_smith_manoeuvre: true,
  tax_config: {
    "federal_brackets" => [
      { "min" => 0, "max" => 55867, "rate" => 0.15 },
      { "min" => 55867, "max" => 111733, "rate" => 0.205 },
      { "min" => 111733, "max" => 173205, "rate" => 0.26 },
      { "min" => 173205, "max" => 246752, "rate" => 0.29 },
      { "min" => 246752, "max" => nil, "rate" => 0.33 }
    ],
    "provincial_brackets" => {
      "ON" => [
        { "min" => 0, "max" => 51446, "rate" => 0.0505 },
        { "min" => 51446, "max" => 102894, "rate" => 0.0915 },
        { "min" => 102894, "max" => 150000, "rate" => 0.1116 },
        { "min" => 150000, "max" => 220000, "rate" => 0.1216 },
        { "min" => 220000, "max" => nil, "rate" => 0.1316 }
      ],
      "BC" => [
        { "min" => 0, "max" => 45654, "rate" => 0.0506 },
        { "min" => 45654, "max" => 91310, "rate" => 0.077 },
        { "min" => 91310, "max" => 104835, "rate" => 0.105 },
        { "min" => 104835, "max" => 127299, "rate" => 0.1229 },
        { "min" => 127299, "max" => 172602, "rate" => 0.147 },
        { "min" => 172602, "max" => 240716, "rate" => 0.168 },
        { "min" => 240716, "max" => nil, "rate" => 0.205 }
      ],
      "AB" => [
        { "min" => 0, "max" => 148269, "rate" => 0.10 },
        { "min" => 148269, "max" => 177922, "rate" => 0.12 },
        { "min" => 177922, "max" => 237230, "rate" => 0.13 },
        { "min" => 237230, "max" => 355845, "rate" => 0.14 },
        { "min" => 355845, "max" => nil, "rate" => 0.15 }
      ],
      "QC" => [
        { "min" => 0, "max" => 51780, "rate" => 0.14 },
        { "min" => 51780, "max" => 103545, "rate" => 0.19 },
        { "min" => 103545, "max" => 126000, "rate" => 0.24 },
        { "min" => 126000, "max" => nil, "rate" => 0.2575 }
      ]
    },
    "capital_gains_inclusion" => 0.50,
    "dividend_gross_up" => 1.38,
    "dividend_tax_credit" => 0.150198
  },
  metadata: {
    "tax_year" => 2025,
    "source" => "CRA",
    "notes" => "Federal + provincial tax brackets for ON, BC, AB, QC."
  }
)
canada.save!

puts "  Created/updated jurisdiction: Canada (CA)"

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
