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

# 🇨🇦 Canadian Smith Manoeuvre simulator
# 🔧 Extensibility: Supports jurisdiction configuration
class CanadianSmithManoeuvrSimulator
  include PagCompliant
  include JurisdictionAware

  SimulationResult = Struct.new(
    :baseline_path,
    :optimized_path,
    :total_tax_savings,
    :net_benefit,
    keyword_init: true
  )

  MonthState = Struct.new(
    :month,
    :mortgage_balance,
    :heloc_balance,
    :investment_value,
    :tax_deduction,
    keyword_init: true
  )

  def initialize(mortgage:, heloc_limit:, investment_return:, tax_rate:, years:, jurisdiction: nil)
    @mortgage = mortgage
    @heloc_limit = heloc_limit
    @investment_return = investment_return
    @tax_rate = tax_rate
    @years = years
    @jurisdiction = jurisdiction || Jurisdiction.default
  end

  def simulate
    baseline = simulate_baseline
    optimized = simulate_smith_manoeuvre

    SimulationResult.new(
      baseline_path: baseline,
      optimized_path: optimized,
      total_tax_savings: calculate_tax_savings(optimized),
      net_benefit: calculate_net_benefit(baseline, optimized)
    )
  end

  private

  def simulate_baseline
    path = []
    balance = @mortgage

    (@years * 12).times do |month|
      balance = apply_mortgage_payment(balance)
      path << MonthState.new(
        month: month,
        mortgage_balance: balance,
        heloc_balance: 0,
        investment_value: 0,
        tax_deduction: 0
      )
    end

    path
  end

  def simulate_smith_manoeuvre
    # Implementation for Smith Manoeuvre strategy
    # Convert non-deductible mortgage debt to deductible investment debt
    # Track HELOC interest cash source for CRA audit trail:
    #   entry[:heloc_interest_cash_source] = :joint_account
    #   entry[:heloc_interest_paid_from_cash] = heloc_interest
    []
  end

  # 🇨🇦 Canadian mortgage compounding: semi-annual, not monthly
  # Fixed-rate mortgages compound semi-annually per Canadian federal law.
  # HELOC (variable rate) uses simple monthly compounding: rate/12
  def canadian_monthly_mortgage_rate(annual_rate)
    ((1 + annual_rate / 2.0) ** (1.0 / 6)) - 1
  end

  def apply_mortgage_payment(balance)
    # 🇨🇦 Use semi-annual compounding for Canadian fixed-rate mortgages
    monthly_rate = canadian_monthly_mortgage_rate(@mortgage[:rate])
    interest = balance * monthly_rate
    principal = @mortgage[:payment] - interest
    balance - principal
  end

  def calculate_tax_savings(path)
    path.sum(&:tax_deduction) * marginal_tax_rate
  end

  def calculate_net_benefit(baseline, optimized)
    # Compare final states
    0
  end

  def marginal_tax_rate
    tax_calculator_config.marginal_tax_rate(income: @mortgage * 5)
  end
end
```

## Instructions

1. Parse simulator name from arguments
2. Generate simulator class in `app/services/`
3. Include appropriate concerns
4. Create Result and State structs
5. Generate corresponding test file
6. Include baseline vs optimized comparison structure

## Simulator vs Calculator

| Aspect | Calculator | Simulator |
|--------|-----------|-----------|
| Location | `app/calculators/` | `app/services/` |
| Purpose | Pure math | Multi-step processes |
| Side effects | None | May track state |
| Performance | < 200ms | < 2s (background OK) |
| Output | Single result | Path/trajectory |

## Financial Architecture Rules

### 🇨🇦 Canadian Smith Manoeuvre
- CRA-compliant debt optimization
- Interest deductibility rules
- HELOC readvancement tracking
- HELOC interest cash source tracking (for CRA audit trail)
- Mortgage: semi-annual compounding `(1 + r/2)^(1/6) - 1`
- HELOC: simple monthly compounding `rate / 12`

### Never Hardcode
- ❌ `tax_benefit = interest * 0.45`
- ✅ `tax_benefit = interest * marginal_tax_rate`

### Performance
- Target < 2s (background job acceptable)
- Store percentiles only (p10, p25, p50, p75, p90)
- Don't store all simulation paths

## Important Notes

- Simulators are for complex multi-step scenarios
- Use Calculators for pure math
- Always compare baseline vs optimized strategies
- Include jurisdiction-aware tax calculations
