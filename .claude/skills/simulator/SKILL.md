---
name: simulator
description: Create a financial simulator for multi-step scenarios with state
---

# Create Financial Simulator

Generate a financial simulator in `app/services/` for complex multi-step processes.

## Usage

```
/simulator SmithManoeuvreSimulator
/simulator MonteCarloSimulator
/simulator DebtPayoffSimulator
```

## Simulator Pattern

Simulators handle **complex scenarios** with:
- Multi-step processes with state changes over time
- Month-by-month or year-by-year progression
- Comparison of multiple strategies (baseline vs optimized)
- State tracking throughout simulation

## Generated Files

1. **Simulator:** `app/services/{{name}}_simulator.rb`
2. **Test:** `test/services/{{name}}_simulator_test.rb`

## Simulator Template

```ruby
# frozen_string_literal: true

# Canadian-first financial simulator
# For debt simulators, inherit from AbstractDebtSimulator instead
class ExampleSimulator
  include PagCompliant
  include JurisdictionAware

  Result = Struct.new(:paths, :net_benefit, keyword_init: true)

  def initialize(strategy:)
    @strategy = strategy
  end

  def simulate!
    # Multi-step simulation logic
    # Use marginal_tax_rate(income:) directly from JurisdictionAware concern
  end

  private

  # Canadian mortgage compounding: semi-annual, not monthly
  # Fixed-rate mortgages compound semi-annually per Canadian federal law.
  # HELOC (variable rate) uses simple monthly compounding: rate/12
  def canadian_monthly_mortgage_rate(annual_rate)
    ((1 + annual_rate / 2.0) ** (1.0 / 6)) - 1
  end
end
```

## Debt Simulators

For debt-related simulators, inherit from `AbstractDebtSimulator` (not standalone):
- Uses template method pattern with `simulate!` as entry point (no arguments)
- Subclasses implement `scenario_type` and `calculate_prepayment`
- Includes `MortgageRenewalSupport` and `LoanTermDefaults` concerns
- See `.cursor/rules/debt-optimization.mdc` for full architecture

## Instructions

1. Parse simulator name from arguments
2. Generate simulator class in `app/services/`
3. For debt simulators: inherit from `AbstractDebtSimulator`
4. For other simulators: include appropriate concerns (PagCompliant, JurisdictionAware)
5. Create Result and State structs
6. Generate corresponding test file

## Simulator vs Calculator

| Aspect | Calculator | Simulator |
|--------|-----------|-----------|
| Location | `app/calculators/` | `app/services/` |
| Purpose | Pure math | Multi-step processes |
| Side effects | None | May track state |
| Performance | < 200ms | < 2s (background OK) |
| Output | Single result | Path/trajectory |

## Financial Architecture Rules

### Canadian Smith Manoeuvre
- CRA-compliant debt optimization
- Interest deductibility rules
- HELOC readvancement tracking
- HELOC interest cash source tracking (for CRA audit trail)
- Mortgage: semi-annual compounding `(1 + r/2)^(1/6) - 1`
- HELOC: simple monthly compounding `rate / 12`

### Never Hardcode
- BAD: `tax_benefit = interest * 0.45`
- GOOD: `tax_benefit = interest * marginal_tax_rate(income:)`

### Performance
- Target < 2s (background job acceptable)
- Store percentiles only (p10, p25, p50, p75, p90)
- Don't store all simulation paths

## Important Notes

- Simulators are for complex multi-step scenarios
- Use Calculators for pure math
- Always compare baseline vs optimized strategies
- Include jurisdiction-aware tax calculations
