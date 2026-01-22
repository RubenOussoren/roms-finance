---
name: calculator
description: Create a financial calculator following pure function pattern
---

# Create Financial Calculator

Generate a financial calculator in `app/calculators/` following project conventions.

## Usage

```
/calculator ProjectionCalculator
/calculator CompoundInterestCalculator
/calculator MilestoneCalculator
```

## Calculator Pattern

Calculators are **pure functions** with:
- No side effects (no DB writes, no API calls)
- Deterministic output for given input
- Return value objects or hashes
- Performance target: < 200ms

## Generated Files

1. **Calculator:** `app/calculators/{{name}}_calculator.rb`
2. **Test:** `test/calculators/{{name}}_calculator_test.rb`

## Calculator Template

```ruby
# frozen_string_literal: true

# 🇨🇦 Canadian-first financial calculator
# 🔧 Extensibility: Supports jurisdiction configuration
class ProjectionCalculator
  include PagCompliant
  include JurisdictionAware

  Result = Struct.new(:future_value, :total_contributions, :total_growth, keyword_init: true)

  def initialize(principal:, rate:, years:, contribution: 0, jurisdiction: nil)
    @principal = principal
    @rate = rate
    @years = years
    @contribution = contribution
    @jurisdiction = jurisdiction || Jurisdiction.default
  end

  def calculate
    # Pure calculation logic
    future_value = compound_with_contributions

    Result.new(
      future_value: future_value,
      total_contributions: @contribution * @years * 12,
      total_growth: future_value - @principal - (@contribution * @years * 12)
    )
  end

  private

  def compound_with_contributions
    # FV = P(1+r)^n + PMT * ((1+r)^n - 1) / r
    monthly_rate = @rate / 12.0
    months = @years * 12

    principal_growth = @principal * ((1 + monthly_rate) ** months)
    contribution_growth = @contribution * (((1 + monthly_rate) ** months - 1) / monthly_rate)

    principal_growth + contribution_growth
  end
end
```

## Test Template

```ruby
# frozen_string_literal: true

require "test_helper"

class ProjectionCalculatorTest < ActiveSupport::TestCase
  test "compound interest calculation matches formula" do
    calc = ProjectionCalculator.new(principal: 1000, rate: 0.08, years: 10)
    result = calc.calculate

    # Known formula: FV = PV * (1 + r)^n
    expected = 1000 * (1.08 ** 10)
    assert_in_delta expected, result.future_value, 0.01
  end

  test "handles zero principal" do
    calc = ProjectionCalculator.new(principal: 0, rate: 0.08, years: 10, contribution: 100)
    result = calc.calculate

    assert result.future_value > 0
  end

  test "handles negative returns" do
    calc = ProjectionCalculator.new(principal: 1000, rate: -0.05, years: 5)
    result = calc.calculate

    assert result.future_value < 1000
  end
end
```

## Instructions

1. Parse calculator name from arguments
2. Generate calculator class in `app/calculators/`
3. Include appropriate concerns (PagCompliant, JurisdictionAware)
4. Generate corresponding test file
5. Use `assert_in_delta` for float comparisons

## Financial Architecture Rules

### 🇨🇦 Canadian-First, Jurisdiction-Aware
- NEVER hardcode tax rules or brackets
- Use `Jurisdiction#marginal_tax_rate(income:)` for tax calculations
- Default to Canada (`country_code: 'CA'`)
- Include PAG 2025 compliance hooks via `ProjectionStandard`

### Performance Requirements
- Target < 200ms for deterministic calculations
- Cache results with smart cache keys
- Use Result structs for return values

## Important Notes

- Calculators are for pure math only
- Use Simulators for multi-step processes with state
- Test with known mathematical formulas
- Include edge cases (zero, negative, boundary values)
