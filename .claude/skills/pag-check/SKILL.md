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

### 2. Jurisdiction Configuration
Verify code uses:
- `Jurisdiction` model for country settings (includes `tax_config` JSONB for tax brackets)
- `ProjectionStandard` for PAG 2025 assumptions

### 3. PagCompliant Concern
Check that financial models include:
```ruby
include PagCompliant

# Methods available:
# - use_pag_assumptions!
# - pag_compliant?
# - compliance_badge
```

### 4. JurisdictionAware Concern
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

## Instructions

1. Scan specified files/directories for financial calculations
2. Flag any hardcoded:
   - Tax rates or brackets
   - Investment return assumptions
   - Inflation rates
   - Interest rates
3. Verify proper concern inclusion
4. Check for compliance badge usage in outputs
5. Report compliance status

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
