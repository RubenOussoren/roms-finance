---
name: pag-check
description: Check PAG 2025 compliance for financial projections
---

# PAG 2025 Compliance Check

Verify that financial projections comply with FP Canada's Projection Assumption Guidelines (PAG) 2025.

## Usage

```
/pag-check                           # Check all projection code
/pag-check app/calculators/          # Check specific directory
/pag-check projection_calculator.rb  # Check specific file
```

## PAG 2025 Standard Assumptions

### Investment Returns
- Canadian Equities: 6.3% nominal
- U.S. Equities: 6.1% nominal
- International Equities: 6.4% nominal
- Canadian Fixed Income: 3.6% nominal
- Cash/Money Market: 2.5% nominal

### Inflation Rate
- 2.1% annual inflation

### Borrowing Rates
- Mortgage rates: Variable based on current rates + spread
- HELOC rates: Prime + spread

## Compliance Checklist

### 1. No Hardcoded Values
Check for violations:
```ruby
# ❌ BAD - Hardcoded
return_rate = 0.07
tax_rate = 0.45

# ✅ GOOD - Configurable
return_rate = projection_standard.equity_return
tax_rate = jurisdiction.marginal_tax_rate(income: income)
```

### 2. Safety Margin Applied (-0.5%)
Verify that `PAG_2025_ASSUMPTIONS[:safety_margin]` (-0.005) is applied in `blended_return`:
```ruby
# ❌ BAD - No safety margin
blended = (equity * weight) + (fixed * (1 - weight))

# ✅ GOOD - Safety margin applied
margin = PAG_2025_ASSUMPTIONS[:safety_margin]
blended = (equity * weight) + (fixed * (1 - weight)) + margin
```

### 3. Provincial Tax Rates
Verify that `marginal_tax_rate` uses **combined** federal + provincial rates, not federal-only:
```ruby
# ❌ BAD - Federal only
tax_rate = federal_brackets.marginal_rate(income)

# ✅ GOOD - Combined federal + provincial
tax_rate = jurisdiction.marginal_tax_rate(income: income)
# Jurisdiction model combines federal_brackets + provincial_state_brackets
```
Check that `provincial_state_brackets` JSONB is populated in seed data for Canadian provinces.

### 4. Jurisdiction Configuration
Verify code uses:
- `Jurisdiction` model for country settings (includes `tax_config` JSONB for tax brackets)
- `ProjectionStandard` for PAG 2025 assumptions

### 5. PagCompliant Concern
Check that financial models include:
```ruby
include PagCompliant

# Methods available:
# - use_pag_assumptions!
# - pag_compliant?
# - compliance_badge
```

### 6. JurisdictionAware Concern
Check that calculators include:
```ruby
include JurisdictionAware

# Methods available:
# - jurisdiction (defaults to Canada)
# - projection_standard
# - marginal_tax_rate(income:)
# - interest_deductible?
# - supports_smith_manoeuvre?
```

### 7. Canadian Mortgage Compounding
Verify mortgage calculations use semi-annual compounding (not rate/12):
```ruby
# ❌ BAD - US-style monthly compounding for Canadian mortgages
monthly_rate = annual_rate / 12

# ✅ GOOD - Canadian semi-annual compounding
monthly_rate = ((1 + annual_rate / 2.0) ** (1.0 / 6)) - 1
```
Note: `rate/12` IS correct for investment growth and HELOC (variable rate) calculations.

## Instructions

1. Scan specified files/directories for financial calculations
2. Flag any hardcoded:
   - Tax rates or brackets
   - Investment return assumptions
   - Inflation rates
   - Interest rates
3. Verify proper concern inclusion
4. Verify safety margin (-0.5%) is applied to `blended_return`
5. Verify provincial tax brackets are populated (not just federal)
6. Verify Canadian mortgage calculations use semi-annual compounding
7. Check for compliance badge usage in outputs
8. Report compliance status

## Compliance Report Format

```
PAG 2025 Compliance Check
=========================

Files Checked: 5
Compliant: 3
Violations: 2

Violations Found:
-----------------
1. app/calculators/old_calculator.rb:45
   Hardcoded tax rate: 0.45
   Fix: Use tax_calculator_config.marginal_tax_rate(income:)

2. app/services/projection_service.rb:23
   Missing PagCompliant concern
   Fix: Add 'include PagCompliant' to class

Compliance Status: ❌ NOT COMPLIANT
```

## Important Notes

- PAG 2025 is specific to Canadian financial planning
- Other jurisdictions may have different standards
- Compliance badge should be shown to users: "Prepared using FP Canada PAG 2025"
- Always default to Canadian assumptions when jurisdiction not specified
