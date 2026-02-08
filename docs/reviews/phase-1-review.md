# Phase Review: Phase 1 — Canadian Mortgage Compounding Fix
**Date:** 2026-02-07
**Commits:** d5982724..f2b05547 (3 commits)
**Files changed:** 12 (5 app, 7 test)
**Verdict:** PASS WITH WARNINGS

## Scorecard
| Dimension | Verdict | Key Finding |
|-----------|---------|-------------|
| DRY & Code Reuse | Pass | All duplicated `/ 12` mortgage formulas consolidated into `CanadianMortgage` helper; `MilestoneCalculator:182` uses `/12` but is general-purpose debt (acceptable) |
| Code Structure | Pass | New helper is exemplary (63 lines, pure, no nesting). Pre-existing `simulate_modified_smith!` is 197 lines — not worsened by this phase |
| Architecture Coherence | Warn | `Loan#calculate_monthly_payment` and `LoanPayoffCalculator#monthly_rate` now apply Canadian semi-annual compounding to ALL fixed-rate loan subtypes (student, auto, other) — not just mortgages |
| Test Coverage | Pass | 21 new unit tests with known-value assertions; 4 golden master snapshots regenerated; projection snapshots correctly unchanged |
| Documentation | Pass | Excellent header citing Interest Act (R.S.C., 1985, c. I-15, s. 6); concise method docs; commit messages quantify impact |

## Fix-It Items

### 1. [WARN] Canadian compounding applied to non-mortgage loans
**Files:** `app/models/loan.rb:48`, `app/calculators/loan_payoff_calculator.rb:163`
**Problem:** `CanadianMortgage.monthly_payment()` and `CanadianMortgage.monthly_rate()` are now called for ALL fixed-rate loans — including student loans, auto loans, and "other" — which compound monthly, not semi-annually. The Interest Act semi-annual rule applies only to mortgages.
**What to do:** Add a subtype guard so only `subtype == "mortgage"` loans use `CanadianMortgage`; all others fall back to `annual_rate / 12`. Add tests for a non-mortgage loan to verify.
**Severity:** Medium. The app's current seed/demo data only has mortgage-type loans, so no user-facing bug today, but this will bite when student/auto loans are used.
**Status:** FIXED

### 2. [NOTE] Magic numbers 2 and 6 in formula
**File:** `app/models/canadian_mortgage.rb:25`
**Problem:** `(1 + annual_rate / 2.0)**(1.0 / 6) - 1` uses bare `2` and `6` without named constants.
**What to do:** Consider extracting `COMPOUNDING_PERIODS_PER_YEAR = 2` and `MONTHS_PER_COMPOUNDING_PERIOD = 6`. Low priority — the header comment explains the formula clearly.
**Severity:** Low.
**Status:** WONT-FIX (header comment is sufficient documentation)

### 3. [NOTE] File placement: app/models/ vs app/calculators/
**File:** `app/models/canadian_mortgage.rb`
**Problem:** Pure financial math with no entity representation. The codebase has `app/calculators/` for pure math (ProjectionCalculator, MilestoneCalculator, LoanPayoffCalculator).
**What to do:** No action needed. Precedent exists for POROs in `app/models/` (e.g., `BalanceSheet`). Defensible either way.
**Severity:** Cosmetic.
**Status:** WONT-FIX (existing precedent for POROs in app/models/)

## Observations

Phase 1 is a clean, well-executed fix. The `CanadianMortgage` helper is exemplary — pure functions, comprehensive tests with known-value assertions, excellent regulatory documentation. The golden master diffs confirm changes are isolated to mortgage outputs ($2,338 -> $2,326 monthly payment, $301K -> $298K total interest) with projection snapshots correctly unchanged.

The one structural concern is the overly broad application of Canadian compounding to all loan types. This doesn't cause user-facing bugs today (only mortgage loans exist in the data), but should be addressed before student/auto loan features ship. The pre-existing 197-line `simulate_modified_smith!` method was not worsened by this phase but remains a refactoring candidate.
