# Phase 0: Baseline Fixtures

This document maps every golden-master output value to the source file and method
that produces it. Golden master snapshots are stored in `test/golden_masters/snapshots/`
and were last regenerated at commit `5f0ce3cc` (2026-02-07) after projection math corrections.

## Running the Baseline

```bash
# Verify all golden masters pass (zero diffs)
bin/rails golden_masters:verify

# Or directly:
DISABLE_PARALLELIZATION=true bin/rails test test/golden_masters/

# Regenerate after intentional changes:
REGENERATE_GOLDEN_MASTERS=true DISABLE_PARALLELIZATION=true bin/rails test test/golden_masters/
```

## Known Pre-Correction Issues

These are documented bugs that the golden masters intentionally capture in their
current (incorrect) state. Future phases will fix these and regenerate snapshots.

| # | Issue | Impact | Source |
|---|-------|--------|--------|
| 1 | ~~Monthly compounding instead of Canadian semi-annual `(1+r/2)^(1/6)-1`~~ CORRECTED | ~~Overstates monthly rate by ~0.02%~~ | Fixed in commits d5982724, 4938fbea, f2b05547. See `CanadianMortgage.monthly_rate`, `BaselineSimulator#calculate_mortgage_payment`, `LoanPayoffCalculator#monthly_rate`, `Loan#calculate_monthly_payment` |
| 2 | ~~Federal-only tax brackets (missing provincial)~~ CORRECTED | ~~Understates tax benefit by 30-45%~~ | Fixed in commits 89f4e912–dcb95c3d. See `Jurisdiction#marginal_tax_rate`, `test/fixtures/jurisdictions.yml` |
| 3 | ~~HELOC interest cash source untracked~~ CORRECTED | ~~No tracked outflow for HELOC interest payments~~ | Fixed during Smith Manoeuvre fairness audit. See `CanadianSmithManoeuvrSimulator#simulate_modified_smith!` |
| 4 | ~~PAG 2025 safety margin not applied~~ CORRECTED | ~~Returns overstated by 0.5%~~ | `ProjectionStandard::PAG_2025_DEFAULTS` now includes `safety_margin: -0.005` |
| 5 | ~~p50 shows deterministic mean, not true median~~ CORRECTED | ~~Optimistic bias for volatile portfolios~~ | `ProjectionCalculator#calculate_percentiles_for_value` and `FamilyProjectionCalculator#calculate_percentiles` now use drift correction: `median = value * exp(-sigma²/2)` |

---

## Scenario A: Mortgage / Debt Simulators

**Snapshot files:** `scenario_a_baseline.json`, `scenario_a_smith_manoeuvre.json`

### Inputs

| Parameter | Value | Notes |
|-----------|-------|-------|
| Primary mortgage | $400,000 | 5.00% annual, 300-month term |
| Rental mortgage | $200,000 | 5.50% annual, 240-month term |
| Rental income | $2,000/month | |
| Rental expenses | $500/month | |
| HELOC rate | 7.00% | $100,000 credit limit, non-readvanceable |
| Simulation | 300 months | |
| Jurisdiction | Canada | Federal-only brackets (issue #2) |

### Output Traceability: BaselineSimulator

| Output | Value | Source File | Method |
|--------|-------|-------------|--------|
| `monthly_payment_primary` | $2,338.36 | `app/services/baseline_simulator.rb` | `calculate_mortgage_payment` |
| `total_primary_interest` | $301,508.05 | `app/services/baseline_simulator.rb` | `simulate!` loop accumulation |
| `total_rental_interest` | $130,185.91 | `app/services/baseline_simulator.rb` | `simulate!` loop accumulation |
| `primary_payoff_month` | null (300 months) | `app/services/baseline_simulator.rb` | `simulate!` balance update |
| `effective_tax_rate` | 0.205 (20.5%) | `app/models/debt_optimization_strategy.rb` | `effective_marginal_tax_rate` → `Jurisdiction#marginal_tax_rate` |
| `final_cumulative_tax_benefit` | $26,688.11 | `app/services/baseline_simulator.rb` | `simulate!` tax calculation |
| Monthly balances (sample) | See snapshot | `app/services/baseline_simulator.rb` | `simulate!` per-month entries |

### Output Traceability: CanadianSmithManoeuvrSimulator

| Output | Value | Source File | Method |
|--------|-------|-------------|--------|
| `interest_saved` | $114,319.90 | `app/services/canadian_smith_manoeuvr_simulator.rb` | Difference of baseline vs strategy totals |
| `strategy_payoff_month` | 116 | `app/services/canadian_smith_manoeuvr_simulator.rb` | `simulate_modified_smith!` balance update |
| `months_accelerated` | null | Baseline never fully pays off in 300 months |
| `final_cumulative_tax_benefit` | $43,369.99 | `app/services/canadian_smith_manoeuvr_simulator.rb` | `simulate_modified_smith!` tax calculation |
| `final_heloc_balance` | $100,000.00 | `app/services/canadian_smith_manoeuvr_simulator.rb` | `simulate_modified_smith!` HELOC balance update |
| HELOC trajectory | See snapshot | `app/services/canadian_smith_manoeuvr_simulator.rb` | `simulate_modified_smith!` |
| Prepayment amounts | See snapshot | `app/services/canadian_smith_manoeuvr_simulator.rb` | `simulate_modified_smith!` prepayment logic |

---

## Scenario B: Investment Projection Calculators

**Snapshot files:** `scenario_b_projection_10yr.json`, `scenario_b_projection_25yr.json`,
`scenario_b_milestones.json`, `scenario_b_loan_payoff.json`

### Inputs

| Parameter | Value | Notes |
|-----------|-------|-------|
| Starting balance | $100,000 | |
| Expected return | 7% annual | |
| Volatility | 18% annual | |
| Monthly contribution | $500 | |
| Horizons | 10 years, 25 years | |

### Output Traceability: ProjectionCalculator

| Output | Value (10yr) | Value (25yr) | Source File | Method |
|--------|-------------|-------------|-------------|--------|
| `p50` at year 5 | $163,743.77 | $163,743.77 | `app/calculators/projection_calculator.rb` | `project_with_analytical_bands` → `calculate_percentiles_for_value` with drift correction |
| `p50` at year 10 | $244,509.11 | $244,509.11 | Same | Same |
| `p50` at year 25 | N/A | $652,021.63 | Same | Same |
| `p10` at year 10 | $138,748.62 | $138,748.62 | `app/calculators/projection_calculator.rb` | `calculate_percentiles_for_value` with `exp(-1.28 * sigma)` |
| `p90` at year 10 | $595,762.05 | $595,762.05 | Same | `exp(1.28 * sigma)` |
| `years_to_200k` | 6.25 | 6.25 | `app/calculators/projection_calculator.rb` | `years_to_target` → `months_to_target` binary search |
| `years_to_500k` | 16.50 | 16.50 | Same | Same |
| `years_to_1m` | 25.33 | 25.33 | Same | Same |
| `required_for_1m_25y` | $527.68 | $527.68 | `app/calculators/projection_calculator.rb` | `required_contribution` |
| `real_value_10yr` | $233,092.67 | $233,092.67 | `app/calculators/projection_calculator.rb` | `real_future_value_at_month` |
| `real_value_25yr` | N/A | $578,556.72 | Same | Same |

### Output Traceability: MilestoneCalculator

| Output | Value | Source File | Method |
|--------|-------|-------------|--------|
| Time to $200K | 75 months (6.3 years) | `app/calculators/milestone_calculator.rb` | `time_to_grow_to` → `ProjectionCalculator#months_to_target` |
| Time to $500K | 198 months (16.5 years) | Same | Same |
| Time to $1M | 304 months (25.3 years) | Same | Same |
| Sensitivity: 0% contrib → $500K | 277 months (23.1 years) | `app/calculators/milestone_calculator.rb` | `contribution_sensitivity` |
| Sensitivity: 200% contrib → $500K | 156 months (13.0 years) | Same | Same |

### Output Traceability: LoanPayoffCalculator

| Output | Value | Source File | Method |
|--------|-------|-------------|--------|
| `monthly_payment` | $2,338.00 | `app/calculators/loan_payoff_calculator.rb` | `monthly_payment` → `Loan#monthly_payment` → `calculate_monthly_payment` |
| `months_to_payoff` | 301 | `app/calculators/loan_payoff_calculator.rb` | `calculate_amortization_schedule` |
| `total_interest_remaining` | $301,615.49 | `app/calculators/loan_payoff_calculator.rb` | `total_interest_remaining` |
| `schedule_length` | 301 | `app/calculators/loan_payoff_calculator.rb` | `calculate_amortization_schedule` length |
| Balance at month 1 | $399,328.67 | `app/calculators/loan_payoff_calculator.rb` | `calculate_amortization_schedule` amortization loop |
| Balance at month 60 | $354,345.25 | Same | Same |
| Balance at month 120 | $295,753.83 | Same | Same |
| Balance at month 300 | $214.48 | Same | Same |

**Note:** LoanPayoffCalculator uses `Loan#monthly_payment` which rounds to integer cents
(`Money.new(payment.round, currency)`), giving $2,338.00 vs the simulators' more precise
$2,338.36 from their own `calculate_mortgage_payment` method. This 36-cent discrepancy is
inherent in the dual computation path.

---

## Scenario C: Smith Manoeuvre Tax Benefits

**Snapshot file:** `scenario_c_tax_benefits.json`

### Inputs

| Parameter | Value | Notes |
|-----------|-------|-------|
| Household income | $100,000 | |
| Jurisdiction | Canada | Federal-only (issue #2) |
| Same mortgage setup as Scenario A | | |

### Output Traceability

| Output | Value | Source File | Method |
|--------|-------|-------------|--------|
| `effective_marginal_tax_rate` | 0.205 (20.5%) | `app/models/debt_optimization_strategy.rb` | `effective_marginal_tax_rate` → `Jurisdiction#marginal_tax_rate` |
| `total_tax_benefit` | $43,369.99 | `app/services/canadian_smith_manoeuvr_simulator.rb` | Sum of per-month `tax_benefit` |
| `total_deductible_interest` | $211,560.91 | `app/services/canadian_smith_manoeuvr_simulator.rb` | Sum of `deductible_interest`: rental + HELOC |
| `total_non_deductible_interest` | $105,813.15 | `app/services/canadian_smith_manoeuvr_simulator.rb` | Sum of `non_deductible_interest`: primary only |
| Year 1 cumulative tax benefit | $2,265.55 | Same | `cumulative_tax_benefit` at month 11 |
| Year 5 cumulative tax benefit | $11,497.47 | Same | `cumulative_tax_benefit` at month 59 |
| Year 10 cumulative tax benefit | $23,100.78 | Same | `cumulative_tax_benefit` at month 119 |
| Year 20 cumulative tax benefit | $43,369.99 | Same | `cumulative_tax_benefit` at month 239 |
| HELOC balance at year 1 | $6,000.00 | Same | `heloc_balance` at month 11 |
| HELOC balance at year 10 | $60,000.00 | Same | `heloc_balance` at month 119 |
| HELOC balance at year 20 | $100,000.00 | Same | `heloc_balance` at month 239 (capped at limit) |

### Tax Calculation Chain

```
$100,000 income → Jurisdiction.marginal_tax_rate
  → bracket lookup: $55,867-$111,733 → 20.5% federal rate
  → Missing: Ontario provincial ~9.15% surtax (issue #2)

deductible_interest = rental_mortgage_interest + heloc_interest
  → Source: CanadianSmithManoeuvrSimulator#simulate_modified_smith!

tax_benefit = deductible_interest × 0.205
  → Source: CanadianSmithManoeuvrSimulator#simulate_modified_smith!

cumulative_tax_benefit += tax_benefit (per month)
  → Source: CanadianSmithManoeuvrSimulator#simulate_modified_smith!
```

---

## File Index

| File | Role |
|------|------|
| `test/golden_masters/golden_master_test.rb` | Test file with 7 golden master comparison tests |
| `test/golden_masters/snapshots/scenario_a_baseline.json` | BaselineSimulator outputs for $400K mortgage |
| `test/golden_masters/snapshots/scenario_a_smith_manoeuvre.json` | Smith Manoeuvre outputs with HELOC optimization |
| `test/golden_masters/snapshots/scenario_b_projection_10yr.json` | 10-year investment projection percentiles |
| `test/golden_masters/snapshots/scenario_b_projection_25yr.json` | 25-year investment projection percentiles |
| `test/golden_masters/snapshots/scenario_b_milestones.json` | Milestone time-to-target calculations |
| `test/golden_masters/snapshots/scenario_b_loan_payoff.json` | LoanPayoffCalculator amortization schedule |
| `test/golden_masters/snapshots/scenario_c_tax_benefits.json` | Tax benefit computation details |
| `lib/tasks/golden_masters.rake` | Rake tasks: `golden_masters:verify` and `golden_masters:regenerate` |
| `docs/testing/golden-masters.md` | This document |

## Source Files Exercised

| Source File | Coverage | Scenario |
|-------------|----------|----------|
| `app/services/baseline_simulator.rb` | Full | A |
| `app/services/canadian_smith_manoeuvr_simulator.rb` | Full | A, C |
| `app/models/debt_optimization_strategy.rb` | `effective_marginal_tax_rate`, strategy configuration | A, C |
| `app/models/debt_optimization_ledger_entry.rb` | Full | A, C |
| `app/models/jurisdiction.rb` | `marginal_tax_rate` | A, C |
| `app/calculators/projection_calculator.rb` | Core projection methods | B |
| `app/calculators/milestone_calculator.rb` | `time_to_grow_to`, `contribution_sensitivity` | B |
| `app/calculators/loan_payoff_calculator.rb` | Full | B |
| `app/models/loan.rb` | `calculate_monthly_payment` | B |
| `app/models/projection_standard.rb` | `PAG_2025_DEFAULTS` | B (via assumptions) |
