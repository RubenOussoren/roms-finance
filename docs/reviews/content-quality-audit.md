# Content Quality Audit Report

**Date**: 2026-02-07
**Scope**: Documentation (11 files), Cursor Rules (6 files), Claude Skills (20 skills + templates)
**Methodology**: Three specialist agents reviewed each domain independently, then findings were cross-referenced for consistency. File paths and class names were spot-checked against the actual codebase using Glob and Grep.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Domain 1: Documentation](#domain-1-documentation)
3. [Domain 2: Cursor Rules](#domain-2-cursor-rules)
4. [Domain 3: Claude Skills](#domain-3-claude-skills)
5. [Cross-Consistency Analysis](#cross-consistency-analysis)
6. [Consolidated Priority Matrix](#consolidated-priority-matrix)
7. [What's Already Excellent](#whats-already-excellent)

---

## Executive Summary

The technical content across all three layers (docs, rules, skills) is **strong in domain knowledge but undermined by codebase drift**. The project has been through 9 implementation phases with significant refactoring, but the supporting documentation was not updated in lockstep. The result is a pattern of "ghost artifacts" — references to code that was planned but never built (e.g., `Projectable` concern), or code that was built differently than documented (e.g., `simulate!` vs `run(months:)`).

**By the numbers:**
- 18 P1 issues (fix immediately — actively misleading)
- 30 P2 issues (fix soon — friction or staleness)
- 26 P3 issues (nice to have — polish)

**The single biggest systemic problem:** Two Cursor rules (`debt-optimization.mdc` and `investment-projections.mdc`) contain hundreds of lines of aspirational Ruby code that diverges significantly from the actual implementation. An AI agent following these rules would generate code incompatible with the codebase. These two rules account for ~60% of the P1 issues.

**The biggest quick win:** Fix the README and CONTRIBUTING to say "ROMS Finance" instead of "Maybe" — 30 minutes of work that removes the worst first-impression problem.

---

## Domain 1: Documentation

### Document Ratings

| Document | Rating | Primary Issue |
|----------|--------|---------------|
| CLAUDE.md | **EXCELLENT** | — |
| README.md | **NEEDS WORK** | Wrong directory, stale credentials, missing features |
| CONTRIBUTING.md | **NEEDS WORK** | Still says "Maybe" throughout, upstream links |
| docs/DEVELOPER_GUIDE.md | **EXCELLENT** | — |
| docs/FEATURE_ROADMAP.md | **EXCELLENT** | Minor staleness risk in dollar amounts |
| docs/api/chats.md | **GOOD** | Stale model names, missing auth setup |
| docs/architecture/design-vision.md | **GOOD** | Stale status table, tries to be two docs |
| docs/hosting/docker.md | **EXCELLENT** | Minor service name inconsistency |
| docs/reviews/phase-1-review.md | **EXCELLENT** | — |
| docs/testing/debt-simulators.md | **EXCELLENT** | Minor helper reference drift |
| docs/testing/golden-masters.md | **EXCELLENT** | Stale known-issues table |

### P1 Findings

**D-1. README.md: `cd maybe` should be `cd roms-finance`**
A new developer following setup instructions hits a wrong directory on step 1.
```
# Current (line 27)
cd maybe

# Fix
cd roms-finance
```

**D-2. README.md: Seed credentials reference upstream data**
CLAUDE.md says test login is `test.canadian@example.com / password123`. README says `user@maybe.local / password`. New developers will use the wrong credentials.
```
# Fix: Add both with context
Default seed account:
- Email: `user@maybe.local` / Password: `password`

Canadian test data (for financial features):
- Email: `test.canadian@example.com` / Password: `password123`
```

**D-3. CONTRIBUTING.md: Title and links still say "Maybe"**
Line 1: "Contributing to Maybe". All links point to `github.com/maybe-finance/maybe`. Contributors will look at the wrong repo.
```
# Fix
- Title: "Contributing to ROMS Finance"
- Replace all `github.com/maybe-finance/maybe` refs with ROMS Finance repo URL
- Or add: "This project is a fork. Check issues and PRs in **this** repository."
```

**D-4. golden-masters.md: "Known Pre-Correction Issues" table is stale**
Issues #1, #2, #3 shown as open. All were fixed (per memory: d5982724, 89f4e912, fairness audit). Developers investigating test failures will chase solved problems.
```
# Fix: Update status for all three
Issue #1 (Canadian compounding): CORRECTED (commits d5982724, 4938fbea, f2b05547)
Issue #2 (Tax rates): CORRECTED (commits 89f4e912–dcb95c3d)
Issue #3 (HELOC cash source): CORRECTED (fairness audit)
```

**D-5. design-vision.md: Implementation status table is stale**
Shows Phase 4 items as current. Phases 5-8 are complete. Actively misleads about project state.
```
# Fix: Replace status table with
> For current implementation status, see git log and phase review reports
> in `docs/reviews/`. For planned features, see `docs/FEATURE_ROADMAP.md`.
```

### P2 Findings

**D-6. README.md: No description of what the app does**
The "About" section is one sentence. A developer deciding to contribute needs to know the feature set.
```
# Fix: Replace About section
ROMS Finance is a self-hosted personal finance app with:
- Investment projections with Monte Carlo confidence bands (PAG 2025 compliant)
- Canadian debt optimization (Smith Manoeuvre, HELOC strategies)
- Multi-account tracking (banking, investments, crypto, loans, property)
- Tax-aware calculations with CRA audit trail support
```

**D-7. README.md: Setup guide links point to upstream Maybe wiki**
Links to `github.com/maybe-finance/maybe/wiki/*` may disappear or diverge.
```
# Fix: Add parenthetical
(upstream Maybe Finance guides — may differ for ROMS-specific features)
```

**D-8. CONTRIBUTING.md: Mentions Cursor but not Claude Code**
CLAUDE.md establishes Claude Code as the primary AI tool.
```
# Fix
"Consider using Cursor + VSCode or Claude Code, which will automatically
apply our project conventions."
```

**D-9. chats.md: Model list is stale**
Lists `gpt-4`, `gpt-4-turbo`, `gpt-3.5-turbo`. Project likely uses different models now.
```
# Fix
"Available models are configured per-instance. Check your instance's
Settings > AI page for supported models."
```

**D-10. chats.md: References "Maybe's AI chat"**
Forked project name not updated.
```
# Fix: "ROMS Finance's AI chat functionality"
```

**D-11. chats.md: No authentication setup instructions**
Says "require authentication via OAuth2 or API keys" but never explains how to obtain credentials.
```
# Fix: Add Getting Started section
To obtain API credentials, navigate to Settings > API > Create Application.
See the `/oauth` skill for detailed OAuth setup.
```

**D-12. chats.md: Rate limits are vague**
"Subject to the standard API rate limits based on your API key tier." What limits? What tiers?
```
# Fix: Either specify or link to config
Default: 100 requests/minute. Configurable via `RATE_LIMIT_*` environment variables.
```

**D-13. docker.md: Inconsistent service names in update commands**
Line 159 uses `web worker`, line 174 uses `app`. One is wrong.
```
# Fix: Verify against actual compose.yml and use consistent names
```

**D-14. docker.md: Docker image source unclear**
References `ghcr.io/maybe-finance/maybe:latest`. Should clarify if ROMS Finance publishes its own image.
```
# Fix: Add note
"ROMS Finance uses the upstream Maybe Finance Docker image."
# OR update to ROMS-specific image path
```

**D-15. design-vision.md: "Next Steps" section references Phase 4+ as next**
Phases 5-8 are complete. Actively misleading.
```
# Fix: Replace with
For forward-looking plans, see `docs/FEATURE_ROADMAP.md`.
```

**D-16. debt-simulators.md: Test helper references outdated**
References "private helpers in each test file" but `DebtSimulatorTestHelper` was extracted to `test/support/`.
```
# Fix
Create accounts using `DebtSimulatorTestHelper` methods
(available in `test/support/debt_simulator_test_helper.rb`)
```

**D-17. golden-masters.md: Output values may reflect pre-correction state**
Baseline values ($2,338.36 monthly payment) reflect pre-Canadian-compounding numbers. If golden masters were regenerated, this doc shows wrong values.
```
# Fix: Verify against actual snapshot files and add
"Values reflect golden masters as of commit [hash]. Regenerate with:
REGENERATE_GOLDEN_MASTERS=true bin/rails test test/calculators/"
```

### P3 Findings (Summary)

- D-18: golden-masters.md line number references will break on refactor — use method names only
- D-19: design-vision.md line number references — same fix
- D-20: docker.md missing database backup guidance
- D-21: FEATURE_ROADMAP.md CPP/OAS dollar amounts will stale annually — add update note
- D-22: FEATURE_ROADMAP.md "Zillow/HouseSigma" integration is aspirational — mark as future
- D-23: CONTRIBUTING.md "early days" language undersells project maturity
- D-24: DEVELOPER_GUIDE.md missing CONTRIBUTING.md row in "Where Things Go" table
- D-25: golden-masters.md self-reference says "BASELINE.md" (old name)

---

## Domain 2: Cursor Rules

### Rule Ratings

| Rule | Lines | Rating | Primary Issue |
|------|-------|--------|---------------|
| debt-optimization.mdc | ~930 | **NEEDS WORK** | ~60% aspirational code that diverges from implementation |
| financial-architecture.mdc | ~310 | **GOOD** | Ghost `Projectable` concern, phantom `TaxCalculatorConfig` |
| investment-projections.mdc | ~945 | **NEEDS WORK** | Ghost `Projectable` concern, stale constants and API signatures |
| project-design.mdc | ~178 | **EXCELLENT** | 4 broken file paths (otherwise best rule) |
| testing.mdc | ~370 | **GOOD** | Non-existent test helper, wrong simulator API in examples |
| view_conventions.mdc | ~186 | **EXCELLENT** | Minor Turbo convention gaps |

### P1 Findings

**R-1. debt-optimization.mdc: Massive aspirational code diverges from implementation**
The rule contains ~700 lines of Ruby code. Critical divergences from actual codebase:

| Rule Says | Actual Code |
|-----------|-------------|
| `def run(months:)` returning hashes | `def simulate!` (no args), inherited from `AbstractDebtSimulator` |
| `enum strategy_type: { baseline: 0, modified_smith: 1, heloc_arbitrage: 2, offset_mortgage: 3, custom: 4 }` | `enum :strategy_type, { baseline: "baseline", modified_smith: "modified_smith" }` (string enum, no heloc_arbitrage/offset_mortgage/custom) |
| `belongs_to :tax_calculator_config` | No `TaxCalculatorConfig` AR model exists |
| `Prawn::Document` for PDF generation | Prawn is not a dependency |
| `where(baseline: true)` | Uses `scenario_type` string column (boolean replaced in fairness audit) |

```
# Fix: Rewrite to document actual architecture
- AbstractDebtSimulator (base class, template method pattern)
  ├── BaselineSimulator (standard amortization)
  ├── PrepayOnlySimulator (accelerated payoff)
  └── CanadianSmithManoeuvrSimulator (Smith Manoeuvre with HELOC)
- API: `simulate!` (no arguments — months from strategy config)
- Key patterns: HELOC waterfall, prepayment limits, auto-stop rules
- Remove all aspirational class bodies, keep constraint documentation
```

**R-2 & R-3. financial-architecture.mdc + investment-projections.mdc: `Projectable` concern does not exist**
Both rules document a `Projectable` concern at `app/models/concerns/projectable.rb` with methods like `adaptive_projection`, `forecast_accuracy`, `generate_projections_with_percentiles`. Zero matches in the codebase. Account's actual concerns are: AASM, Syncable, Monetizable, Chartable, Linkable, Enrichable, Anchorable, JurisdictionAware, DataQualityCheckable.
```
# Fix: Remove all Projectable concern code from both rules
# OR create the concern if it's genuinely planned
```

**R-4. financial-architecture.mdc + debt-optimization.mdc: `TaxCalculatorConfig` model does not exist**
Both rules document a `TaxCalculatorConfig` AR model with `belongs_to :jurisdiction` and `marginal_tax_rate` method. The actual `JurisdictionAware` concern uses `jurisdiction&.tax_config || {}` (returns a hash, not an AR model).
```
# Fix: Replace TaxCalculatorConfig references with actual pattern:
# JurisdictionAware concern provides marginal_tax_rate(income:) method directly
```

**R-5. investment-projections.mdc: `ProjectionStandard` code diverges significantly**
Rule shows `PAG_2025_ASSUMPTIONS` constant with `equity_volatility: 0.157, fixed_income_volatility: 0.078`. Actual code uses `PAG_2025_DEFAULTS` with `volatility_equity: 0.18, volatility_fixed_income: 0.05`. The `blended_return` signature also differs: rule shows 2-asset model, actual takes 3-asset (equity, fixed income, cash).
```
# Fix: Update constant name to PAG_2025_DEFAULTS, update values to match
# actual code, update blended_return to 3-asset signature
```

**R-6. investment-projections.mdc: `ProjectionAssumption` scopes diverge**
Rule shows `scope :default_for_account` with `where(asset_allocation: "balanced")`. Actual code uses `scope :for_account_id` with `where(account_id: account_id)`.
```
# Fix: Replace with actual scope definitions
```

**R-7. testing.mdc: Simulator test examples use wrong API**
Test examples show `@simulator.run(months: 360)`. Actual API is `@simulator.simulate!`.
```
# Fix: Update all test examples to use simulate! with no arguments
```

**R-8. testing.mdc: `financial_test_helper.rb` does not exist**
Rule documents `test/support/financial_test_helper.rb` with `create_projection`, `assert_within_percentage` methods. Actual test helpers are: `entries_test_helper.rb`, `debt_simulator_test_helper.rb`, `balance_test_helper.rb`, `provider_test_helper.rb`, `securities_test_helper.rb`, `ledger_testing_helper.rb`, `query_counting_helper.rb`.
```
# Fix: Replace with references to actual test helpers
```

### P2 Findings

**R-9. project-design.mdc: 4 broken file paths**
- `app/models/account/balance.rb` → actual: `app/models/balance.rb`
- `app/models/account/balance_calculator.rb` → actual: `app/models/balance/forward_calculator.rb`
- `app/models/holding/base_calculator.rb` → actual: `app/models/holding/forward_calculator.rb` + `reverse_calculator.rb`
- `app/models/account/balance/base_calculator.rb` → does not exist

**R-10. financial-architecture.mdc: `provider/concepts/` directory does not exist**
References `app/models/provider/concepts/exchange_rate.rb`. Actual path: `app/models/provider/exchange_rate_concept.rb`.

**R-11. financial-architecture.mdc: Simulator hierarchy outdated**
Shows `CanadianSmithManoeuvrSimulator` without base class. Should document `AbstractDebtSimulator` template method pattern.

**R-12. financial-architecture.mdc: Seed file paths slightly wrong**
`db/seeds/jurisdictions.rb` → actual: `db/seeds/01_jurisdictions.rb` (numbered prefix).

**R-13. investment-projections.mdc: Implementation Status table stale**
Shows "Smith Manoeuvre Simulator — Phase 3 | Pending". Completed in fairness audit.

**R-14. investment-projections.mdc: Monte Carlo code missing Box-Muller guard**
`gaussian_random` shows bare `u1 = rand`. Fix applied: `[rand, Float::EPSILON].max`.

**R-15. debt-optimization.mdc: Missing actual architecture**
No mention of: `AbstractDebtSimulator`, `MortgageRenewalSupport`, `LoanTermDefaults`, `PrepayOnlySimulator`, `scenario_type` column, Net Economic Benefit metric, HELOC waterfall, prepayment limits, auto-stop rules.

**R-16. CLAUDE.md ↔ rules conflict: `app/services/` guidance**
CLAUDE.md Convention 2 says "Business logic in `app/models/`, avoid `app/services/`". But simulators correctly live in `app/services/`. The convention should note this exception.
```
# Fix in CLAUDE.md Convention 2:
Business logic in `app/models/`, avoid `app/services/`
**Exception:** Debt simulators live in `app/services/` as they are multi-step
processes with external state (see `AbstractDebtSimulator`).
```

### P3 Findings (Summary)

- R-17: debt-optimization.mdc uses emoji annotations (low value for AI consumption)
- R-18: debt-optimization.mdc at 930 lines is too long — should be <300 lines of patterns and constraints
- R-19: view_conventions.mdc missing Turbo Frame/Stream conventions
- R-20: view_conventions.mdc missing ViewComponent slot API examples
- R-21: No rule covers `FamilyProjectionCalculator` or `PercentileZScores` module
- R-22: No rule comprehensively maps Account's 11 concerns

---

## Domain 3: Claude Skills

### Skill Ratings

| Skill | Rating | Primary Issue |
|-------|--------|---------------|
| /api-endpoint | GOOD | Auth template placeholder non-functional |
| /branch | **EXCELLENT** | — |
| /calculator | GOOD | PAG values don't match codebase |
| /commit | NEEDS WORK | Co-Authored-By says "Claude Opus 4.5" |
| /component | NEEDS WORK | Naming pattern doesn't match DS::/UI:: namespace |
| /db | GOOD | Test user email inconsistency |
| /import | NEEDS WORK | Template uses fictional import pattern |
| /lint | GOOD | — |
| /oauth | GOOD | May be aspirational |
| /pag-check | NEEDS WORK | PAG reference values wrong |
| /phase-review | **EXCELLENT** | `spec/` references should be `test/` |
| /pr | **EXCELLENT** | — |
| /pre-pr | GOOD | — |
| /provider | NEEDS WORK | Wrong concept namespace path |
| /review | GOOD | Services concern conflicts with architecture |
| /setup | GOOD | Ruby/Postgres versions may be stale |
| /simulator | GOOD | Wrong tax_calculator_config usage |
| /stimulus | GOOD | — |
| /sync | GOOD | — |
| /test | **EXCELLENT** | — |

### P1 Findings

**S-1. /commit: Co-Authored-By says "Claude Opus 4.5"**
Model is Opus 4.6. Every commit made with this skill will have incorrect attribution.
```
# Fix in .claude/skills/commit/SKILL.md
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

**S-2. /pag-check: PAG reference values don't match codebase**
The skill's "PAG 2025 Standard Assumptions" section — the reference values Claude checks against — are wrong:

| Skill Says | Actual `PagCompliant` Code |
|------------|---------------------------|
| Canadian Equities: 6.3% | 6.28% (`equity_return: 0.0628`) |
| Canadian Fixed Income: 3.6% | 4.09% (`fixed_income_return: 0.0409`) |
| Cash/Money Market: 2.5% | 2.95% (`cash_return: 0.0295`) |

```
# Fix: Update to exact values from PagCompliant concern
Canadian Equities: 6.28% nominal
Canadian Fixed Income: 4.09% nominal
Cash/Money Market: 2.95% nominal
```

**S-3. /calculator: Same PAG value mismatch**
Inherits the same wrong reference values as `/pag-check`.
```
# Fix: Same values — 6.28%, 4.09%, 2.95%
```

**S-4. /import: Template uses fictional import pattern**
Template generates `column_mappings`, `transform_row`, `validate_row`, `process!`, and `import_errors` methods. The actual `Import` model uses `status: { pending, complete, importing, reverting, revert_failed, failed }` — not `completed/completed_with_errors`. The `import_errors` association does not exist.
```
# Fix: Read actual TransactionImport and AccountImport classes
# and rebuild template from how imports actually work
```

**S-5. /component: Naming pattern doesn't match codebase**
Generates flat `ExampleComponent < ApplicationComponent` at `app/components/example_component.rb`. Actual components use `DS::` and `UI::` namespaces (e.g., `DS::Alert`, `UI::Account::Chart`). Generated components would be inconsistent with all existing components.
```
# Fix: Update template to generate namespaced components
# Ask user for namespace (DS:: for design system, UI:: for feature components)
# Generate at correct path: app/components/ds/alert.rb or app/components/ui/account/chart.rb
```

### P2 Findings

**S-6. /phase-review: All `spec/` references should be `test/`**
Project uses Minitest (`test/`), not RSpec (`spec/`). 4 locations in SKILL.md and architecture-checklist.md.
```
# Fix: Replace all spec/ references with test/
```

**S-7. /provider: `Provider::Concepts::ExchangeRate` path doesn't exist**
Actual pattern: `Provider::ExchangeRateConcept` at `app/models/provider/exchange_rate_concept.rb`.
```
# Fix: Update to actual concept namespace
include Provider::ExchangeRateConcept  # not Provider::Concepts::ExchangeRate
```

**S-8. /simulator: `tax_calculator_config.marginal_tax_rate()` is wrong**
`tax_calculator_config` returns a hash from `JurisdictionAware`, not an object. The correct call is `marginal_tax_rate(income:)` directly (the concern method).
```
# Fix: Replace tax_calculator_config.marginal_tax_rate(income:)
# with: marginal_tax_rate(income:)
```

**S-9. /simulator: Should mention `AbstractDebtSimulator` base class**
Debt-related simulators should inherit from `AbstractDebtSimulator`, not be standalone.

**S-10. /db: Test user email inconsistency**
Creates `user@maybe.local` but CLAUDE.md says `test.canadian@example.com`. Should clarify.

**S-11. /setup: Ruby and PostgreSQL versions may be stale**
Says "Ruby 3.4.4" and "postgresql@14". Should verify against `.ruby-version` and current project requirements.

**S-12. /api-endpoint: Request spec template has non-functional auth**
Uses `authenticated_headers` helper with hardcoded `"test_token"`. Will produce a failing test.

**S-13. /review: "Files in `app/services/`?" conflicts with architecture**
Flags services as suspicious, but simulators correctly live in `app/services/`.
```
# Fix: Add exception
Files in `app/services/`? (Exception: debt simulators use AbstractDebtSimulator pattern)
```

### P3 Findings (Summary)

- S-14: No `/migration` skill for creating new database migrations
- S-15: No model/scaffold skill for generating new models
- S-16: `/review` vs `/phase-review` overlap — add differentiation note to `/review`
- S-17: `/lint` should note it's a subset of `/pre-pr`
- S-18: `/db setup` should reference `/setup` as preferred first-time command
- S-19: `/stimulus` could mention manifest registration in `controllers/index.js`
- S-20: Calculator template uses emoji in generated code comments
- S-21: Provider template redefines `with_provider_response` (likely in base class already)
- S-22: `/pre-pr` could add expected test count (~1363)
- S-23: Component skill should generate Lookbook previews matching DS/UI namespace

---

## Cross-Consistency Analysis

### Ghost Artifacts (Three-Layer Problem)

The most damaging cross-consistency issue is **ghost artifacts** — code patterns documented across multiple layers that don't exist in the codebase. When docs, rules, AND skills all reference the same phantom, an AI agent has no signal that something is wrong.

| Ghost Artifact | Docs | Rules | Skills | Reality |
|---------------|------|-------|--------|---------|
| `Projectable` concern | CLAUDE.md lists it | financial-architecture + investment-projections document it with full code | — | Does not exist |
| `TaxCalculatorConfig` AR model | design-vision.md references it | debt-optimization + financial-architecture document it | simulator + pag-check call methods on it | `JurisdictionAware` returns a hash, not an AR model |
| `Provider::Concepts::ExchangeRate` | — | financial-architecture references it | provider skill uses it | Actual: `Provider::ExchangeRateConcept` |
| `def run(months:)` simulator API | — | debt-optimization shows it, testing shows it | — | Actual: `def simulate!` (no args) |
| `financial_test_helper.rb` | — | testing.mdc documents it | — | Does not exist; real helpers are entries_, debt_simulator_, balance_, etc. |

**Impact**: An AI agent asked to "add a new debt simulation scenario" would follow the wrong API, reference non-existent models, and produce code that fails to run.

### Contradictions Between Layers

| What | Layer A Says | Layer B Says | Resolution |
|------|-------------|-------------|------------|
| Test credentials | README: `user@maybe.local` | CLAUDE.md: `test.canadian@example.com` | Both exist — document both with context |
| `app/services/` usage | CLAUDE.md: "avoid app/services/" | Rules + Skills: simulators live there | Add exception to Convention 2 |
| PAG 2025 equity return | Skills: 6.3% | Actual `PagCompliant`: 6.28% | Update skills to match code |
| Co-Authored-By version | Skills: "Opus 4.5" | System: Opus 4.6 | Update skill |
| Test directory | Skills (phase-review): `spec/` | Project: `test/` | Fix skill |
| Strategy enum | Rules: integer enum `{ baseline: 0 }` | Code: string enum `{ baseline: "baseline" }` | Fix rules |

### Reinforcement Gaps

These are areas where all three layers should be telling the same story but none of them do:

1. **`AbstractDebtSimulator` template method pattern**: The most important architectural decision in the debt subsystem. Not adequately documented in docs, rules, OR skills. Should be in debt-optimization.mdc with the simulator skill referencing it.

2. **`FamilyProjectionCalculator`**: Exists in `app/calculators/`, used for family-level projections. Not mentioned in any doc, rule, or skill.

3. **`PercentileZScores` module**: Extracted shared constants for z-scores. Not documented anywhere.

4. **HELOC cash flow waterfall** (rental income → HELOC interest → prepayment): A key Smith Manoeuvre pattern. Implemented but not in any rule or skill.

5. **`MortgageRenewalSupport` concern**: Used by simulators for periodic renewals. Not documented in rules.

### Positive Reinforcement (Working Well)

These patterns are consistent across all three layers:

- `Current.user` / `Current.family` authentication pattern
- Design system tokens (`text-primary`, `bg-container`)
- Calculator purity principle (pure math, no side effects)
- Minitest over RSpec (except the phase-review `spec/` slip)
- `icon` helper over `lucide_icon` directly
- ViewComponent over partials for reusable UI

---

## Consolidated Priority Matrix

### P1 — Fix Immediately (18 issues)

These actively mislead developers or AI agents and will produce wrong outputs.

| # | Issue | Domain | Effort |
|---|-------|--------|--------|
| 1 | debt-optimization.mdc: rewrite to match actual AbstractDebtSimulator architecture | Rules | Large (2-3 hrs) |
| 2 | investment-projections.mdc: remove ghost Projectable, fix ProjectionStandard values | Rules | Large (2-3 hrs) |
| 3 | financial-architecture.mdc: remove ghost Projectable and TaxCalculatorConfig | Rules | Medium (1 hr) |
| 4 | testing.mdc: fix simulator API (simulate! not run), remove financial_test_helper.rb | Rules | Small (30 min) |
| 5 | /pag-check: update PAG reference values (6.28%, 4.09%, 2.95%) | Skills | Small (15 min) |
| 6 | /calculator: update PAG reference values | Skills | Small (15 min) |
| 7 | /commit: Co-Authored-By "Claude Opus 4.6" | Skills | Trivial (2 min) |
| 8 | /component: update to DS::/UI:: namespace pattern | Skills | Medium (1 hr) |
| 9 | /import: rebuild template from actual Import model | Skills | Medium (1 hr) |
| 10 | README.md: `cd maybe` → `cd roms-finance` | Docs | Trivial (2 min) |
| 11 | README.md: clarify seed credentials | Docs | Small (10 min) |
| 12 | CONTRIBUTING.md: "Maybe" → "ROMS Finance" throughout | Docs | Small (15 min) |
| 13 | golden-masters.md: mark issues #1-3 as CORRECTED | Docs | Small (10 min) |
| 14 | design-vision.md: replace stale implementation status table | Docs | Small (15 min) |

### P2 — Fix Soon (30 issues)

| Domain | Count | Key Items |
|--------|-------|-----------|
| Docs | 12 | README features summary, chats.md auth/models/rates, docker service names, debt-simulators helper refs |
| Rules | 8 | project-design broken paths, provider concepts path, seed paths, simulator hierarchy, CLAUDE.md services exception |
| Skills | 10 | phase-review spec→test, provider namespace, simulator tax_calculator, setup versions, api-endpoint auth, review services exception |

### P3 — Nice to Have (26 issues)

| Domain | Count | Key Items |
|--------|-------|-----------|
| Docs | 8 | Line number refs → method names, backup guide, CPP/OAS annual update note, HouseSigma marker |
| Rules | 6 | Emoji removal, rule length reduction, Turbo conventions, Account concerns map |
| Skills | 10 | New migration/model skills, overlap clarification notes, emoji in templates, expected test counts |

---

## What's Already Excellent

Credit where it's due — these are genuinely high-quality:

1. **CLAUDE.md**: Best-in-class project configuration file. Clear audience, scannable structure, actionable conventions with examples. The Convention section with "Models should answer questions about themselves" and before/after code is textbook.

2. **docs/FEATURE_ROADMAP.md**: Reads as a credible product planning artifact. Prioritization matrix with explicit scoring, graduated detail (full specs for Tier 1, outlines for Tier 2-3), dependency mapping, and verification checklist. Would not be out of place in a funded startup.

3. **docs/testing/debt-simulators.md**: "How to Add a Scenario Test" is a perfect cookbook. Hierarchy diagram, known-value formulas with legal citations, step-by-step instructions.

4. **docs/hosting/docker.md**: Could be followed by a non-developer. Patient tone, numbered steps, explains what each command does.

5. **view_conventions.mdc**: Best signal-to-noise ratio of all rules (186 lines, near-100% accurate). Component vs. partial decision matrix, excellent DO/DON'T Stimulus examples.

6. **project-design.mdc**: Concise and focused on the core data model. Aside from 4 wrong file paths, the content accurately describes the actual architecture.

7. **/phase-review skill**: Standout skill quality. 5-dimension framework with clear pass/warn/fail criteria, evidence standards, time budgets. The architecture checklist and quick-reference are excellent companions.

8. **/branch, /pr, /test skills**: Clean, focused, minimal. Do one thing well.

9. **Cross-layer consistency on auth, design tokens, and testing framework**: The three layers reinforce each other on `Current.user`, `text-primary` tokens, and Minitest conventions. This is exactly how the system should work.
