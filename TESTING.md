# Debt Simulator Test Suite

## Test Architecture

The debt simulator tests validate three simulators that model Canadian mortgage optimization strategies:

```
test/services/
├── baseline_simulator_test.rb           # BaselineSimulator (no optimization)
├── prepay_only_simulator_test.rb        # PrepayOnlySimulator (rental surplus → prepay)
├── canadian_smith_manoeuvr_simulator_test.rb  # CanadianSmithManoeuvrSimulator (HELOC + tax)
├── debt_simulator_comparison_test.rb    # Cross-simulator ordering invariants
└── debt_simulator_edge_cases_test.rb    # Boundary conditions and degenerate inputs
```

### Simulator Hierarchy (Template Method Pattern)

```
AbstractDebtSimulator           # Base: monthly loop, renewal, privilege limits
├── BaselineSimulator           # calculate_prepayment → 0
├── PrepayOnlySimulator         # calculate_prepayment → min(surplus, balance, privilege)
└── CanadianSmithManoeuvrSimulator  # Own loop: HELOC draws, tax, readvanceable, auto-stop
```

`BaselineSimulator` and `PrepayOnlySimulator` inherit from `AbstractDebtSimulator` and only override `scenario_type` and `calculate_prepayment`. The Smith simulator has its own `simulate_modified_smith!` loop because HELOC/readvanceable logic is structurally different, but it reuses `MortgageRenewalSupport` and `LoanTermDefaults`.

## How to Add a Scenario Test

1. **Create accounts** using the private helpers in each test file:

```ruby
primary = create_loan_account(@family, "Name", balance, rate_percent, term_months)
heloc = create_heloc_account(@family, "Name", balance, rate_percent, credit_limit)
```

2. **Create a strategy** with `DebtOptimizationStrategy.create!`:

```ruby
strategy = DebtOptimizationStrategy.create!(
  family: @family,
  name: "Test Name",
  strategy_type: "modified_smith",  # or "baseline"
  primary_mortgage: primary,
  heloc: heloc,
  rental_mortgage: rental,
  rental_income: 2500,
  rental_expenses: 500,
  simulation_months: 24
)
```

3. **Run the simulator**:

```ruby
CanadianSmithManoeuvrSimulator.new(strategy).simulate!
# This also runs BaselineSimulator and PrepayOnlySimulator internally
```

4. **Query entries** by scenario type:

```ruby
strategy.baseline_entries        # scenario_type = "baseline"
strategy.prepay_only_entries     # scenario_type = "prepay_only"
strategy.strategy_entries        # scenario_type = "modified_smith"
```

5. **Assert known values** with appropriate deltas (see Known-Value Calculation Guide below).

## Golden Master Pattern

Golden master snapshots are used for investment projection tests (not debt simulators). They live in `test/golden_masters/` and capture expected output for regression detection.

### How to Regenerate

```bash
REGENERATE_GOLDEN_MASTERS=true bin/rails test test/calculators/
```

### When to Update

Regenerate golden masters after intentionally changing projection math (e.g., drift correction, variance formula). Never regenerate to paper over a failing test — investigate first.

## Known-Value Calculation Guide

### Canadian Semi-Annual Compounding (Interest Act, R.S.C. 1985, c. I-15, s. 6)

Canadian fixed-rate mortgages quote rates compounded semi-annually:

```
monthly_rate = (1 + annual_rate / 2)^(1/6) - 1
```

Example at 5%:
```
monthly_rate = (1 + 0.05/2)^(1/6) - 1 ≈ 0.00412389
```

Compare US monthly compounding: `0.05 / 12 = 0.00416667`

### Monthly Payment Formula

```
payment = P * r * (1+r)^n / ((1+r)^n - 1)
```

Where `r` = `monthly_rate` (semi-annual), `P` = principal, `n` = term months.

Example: $400K @ 5%, 300 months:
```
payment ≈ $2,326.37
month-0 interest = 400000 * 0.00412389 ≈ $1,649.56
month-0 principal = 2326.37 - 1649.56 ≈ $676.81
total interest (300 months) ≈ $297,911
```

### HELOC Simple Monthly Compounding

HELOCs and variable-rate products use standard monthly compounding:

```
monthly_rate = annual_rate / 12
```

Example at 7%: `0.07 / 12 ≈ 0.005833`

### Tax Rate Lookup (from jurisdictions.yml fixture)

For $100K income in Ontario:
- Federal: 20.5% (bracket $55,867–$111,733)
- Provincial ON: 9.15% (bracket $51,446–$102,894)
- Combined: 29.65%

The `effective_marginal_tax_rate` method falls back to `100_000` income when `family.annual_income` is not available, and defaults to province `"ON"`.

## Running Tests

### Debt simulator tests only

```bash
bin/rails test test/services/
```

### Specific test file

```bash
bin/rails test test/services/baseline_simulator_test.rb
```

### Specific test by line number

```bash
bin/rails test test/services/baseline_simulator_test.rb:127
```

### Full test suite (all tests)

```bash
bin/rails test
```

### With coverage

```bash
COVERAGE=true bin/rails test test/services/
```

### Linting

```bash
bin/rubocop test/services/
```
