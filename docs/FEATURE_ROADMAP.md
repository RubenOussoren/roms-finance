# ROMS Finance Feature Roadmap

**Date:** February 2026
**Status:** Draft specification for sprint planning
**Audience:** Development team, product owner

---

## Table of Contents

1. [Prioritization Matrix](#1-prioritization-matrix)
2. [Visual Roadmap](#2-visual-roadmap)
3. [Tier 1 — Build Next: Detailed MVPs](#3-tier-1--build-next)
   - [F1: Retirement / FIRE Calculator](#f1-retirement--fire-calculator)
   - [F2: Historical Net Worth Chart](#f2-historical-net-worth-chart)
   - [F3: Emergency Fund Tracker](#f3-emergency-fund-tracker)
4. [Tier 2 — Build Soon: Outlines](#4-tier-2--build-soon)
   - [F4: Multi-Debt Support](#f4-multi-debt-support)
   - [F5: Avalanche / Snowball / Custom Debt Payoff](#f5-avalanche--snowball--custom-debt-payoff)
   - [F6: Cross-Account Savings Goals](#f6-cross-account-savings-goals)
   - [F7: RRSP Reinvestment Modeling](#f7-rrsp-reinvestment-modeling)
5. [Tier 3 — Build Later: Outlines](#5-tier-3--build-later)
   - [F8: Tax Bracket Visualization](#f8-tax-bracket-visualization)
   - [F9: What-If Scenarios for Income Changes](#f9-what-if-scenarios-for-income-changes)
   - [F10: Bill Tracking / Upcoming Payments](#f10-bill-tracking--upcoming-payments)
6. [Dependency Map](#6-dependency-map)
7. [Verification Checklist](#7-verification-checklist)

---

## 1. Prioritization Matrix

Each feature scored 1-5 on three axes: **User Impact** (breadth of users who benefit), **Code Leverage** (reuse of existing models/calculators), and **Inverse Complexity** (5 = trivial, 1 = massive). Priority Score = Impact + Leverage + InverseComplexity.

| # | Feature | Impact | Leverage | Inv.Complexity | Score | Tier |
|---|---------|--------|----------|----------------|-------|------|
| F1 | Retirement / FIRE Calculator | 5 | 4 | 3 | **12** | **Build Next** |
| F2 | Historical Net Worth Chart | 5 | 5 | 5 | **15** | **Build Next** |
| F3 | Emergency Fund Tracker | 4 | 4 | 5 | **13** | **Build Next** |
| F4 | Multi-Debt Support | 4 | 3 | 3 | 10 | Build Soon |
| F5 | Avalanche / Snowball Payoff | 4 | 3 | 2 | 9 | Build Soon |
| F6 | Cross-Account Savings Goals | 4 | 3 | 3 | 10 | Build Soon |
| F7 | RRSP Reinvestment Modeling | 2 | 4 | 3 | 9 | Build Soon |
| F8 | Tax Bracket Visualization | 3 | 3 | 4 | 10 | Build Later |
| F9 | What-If Scenarios | 3 | 3 | 2 | 8 | Build Later |
| F10 | Bill Tracking | 3 | 1 | 2 | 6 | Build Later |

**Rationale for tiers:**

- **Build Next** (F1, F2, F3): These three cover the broadest user base, reuse the most existing infrastructure (ProjectionCalculator, Balance model, Account model), and can each ship an MVP within 1-2 sprints. F2 is the lowest-hanging fruit; F3 is a quick win; F1 is the flagship feature.

- **Build Soon** (F4, F5, F6, F7): F4 is a prerequisite for F5 (multi-debt must exist before payoff strategies). F6 introduces cross-account concepts that don't exist today. F7 deepens the Smith Manoeuvre value proposition for existing users.

- **Build Later** (F8, F9, F10): F8 is visualization-only with moderate value. F9 requires a scenario engine that doesn't exist. F10 needs entirely new recurring-transaction infrastructure.

---

## 2. Visual Roadmap

```
Quarter 1 (Next 6 weeks)              Quarter 2 (Weeks 7-14)              Quarter 3+
========================              ======================              ==========

F2: Historical Net Worth ──┐
   (1 sprint, Small)       │
                           │
F3: Emergency Fund ────────┤
   (1 sprint, Small)       │
                           │         F4: Multi-Debt ──────────┐
F1: Retirement/FIRE ───────┤           (2 sprints, Medium)    │
   (2-3 sprints, Large)    │                                  │         F8: Tax Brackets
                           │         F5: Avalanche/Snowball ──┤           (1 sprint)
                           │           (2 sprints, Medium)    │
                           │           BLOCKED BY F4          │         F9: What-If
                           │                                  │           (3 sprints)
                           │         F6: Savings Goals ───────┤
                           │           (2 sprints, Medium)    │         F10: Bill Tracking
                           │                                  │           (3 sprints)
                           │         F7: RRSP Reinvest ───────┘
                           │           (1 sprint, Small)
                           │
                           └── All Tier 1 complete
```

**Key dependencies:**
- F5 (Avalanche/Snowball) is **blocked by** F4 (Multi-Debt Support)
- F7 (RRSP Reinvestment) depends on existing Smith Manoeuvre — no blockers
- F9 (What-If Scenarios) benefits from F1 (Retirement) being complete but is not blocked
- All other features are independent

---

## 3. Tier 1 — Build Next

---

### F1: Retirement / FIRE Calculator

#### Overview

Answer the question every user asks: "When can I retire?" Given current savings, contribution rates, expected returns, and Canadian government benefits (CPP/OAS), project the date when investment income covers living expenses.

#### User Stories

**US-1.1: Basic retirement date projection**
> As a Canadian saver, I want to see when my current savings trajectory reaches my retirement goal so that I can plan my career and savings decisions.

*Acceptance Criteria:*
- Given accounts with balances and a monthly contribution rate, the calculator projects a retirement date
- Uses effective return from ProjectionAssumption (PAG 2025 default or custom)
- Displays projected retirement age and date
- Shows confidence bands (p10, p25, p50, p75, p90) using existing Monte Carlo engine
- Handles the case where retirement is unreachable with current trajectory (shows a warning)

**US-1.2: Income replacement modeling**
> As a retiree planner, I want to specify my desired annual retirement income so that the calculator targets a portfolio size that sustains withdrawals.

*Acceptance Criteria:*
- User enters desired annual retirement income (in today's dollars)
- Calculator determines required portfolio size using selected withdrawal methodology
- Supports two withdrawal modes:
  - Fixed 4% rule (default): target = desired_income / 0.04
  - Variable percentage (Guardrails): target adjusts based on portfolio performance
- Income is inflation-adjusted using ProjectionAssumption.effective_inflation
- Result shows: target portfolio size, current gap, years to target

**US-1.3: CPP/OAS income integration**
> As a Canadian retiree planner, I want the calculator to include CPP and OAS income so that my required portfolio size is reduced by government benefits.

*Acceptance Criteria:*
- User enters expected CPP start age (default 65, range 60-70)
- CPP benefit auto-estimated from contribution years or entered manually
- OAS calculated at current maximum ($727.67/month in 2025), reduced by 0.6% per month before 65, increased by 0.7% per month after 65 up to 70
- GIS clawback modeled: for every $1 of income over threshold, GIS reduced by $0.50
- Net required portfolio income = desired income - CPP - OAS + GIS clawback
- Government benefits shown as separate line items in projection chart

**US-1.4: RRSP vs TFSA drawdown order**
> As a tax-efficient retiree planner, I want to see how RRSP-first vs TFSA-first drawdown order affects my after-tax retirement income so that I can plan my account usage.

*Acceptance Criteria:*
- Calculator identifies RRSP and TFSA accounts by subtype
- Models two scenarios: RRSP-first (defer TFSA) vs TFSA-first (defer RRSP)
- RRSP withdrawals taxed at marginal rate using JurisdictionAware tax tables
- TFSA withdrawals tax-free
- Shows after-tax income comparison for both strategies
- Default recommendation: RRSP drawdown while in low tax bracket, switch to TFSA when income rises

**US-1.5: Configurable assumptions**
> As a user, I want to adjust retirement assumptions (return rate, inflation, withdrawal rate, retirement age) so that I can explore different scenarios.

*Acceptance Criteria:*
- Settings panel with sliders/inputs for: target retirement age, desired income, withdrawal rate, CPP start age, expected return override
- Changes re-calculate in real time (Turbo Frame update)
- "Reset to PAG 2025 defaults" button restores professional assumptions
- Assumptions persisted to `retirement_plans` table for the family

#### Financial Math Specification

**Withdrawal Rate Methodology:**

*Fixed Percentage (4% Rule — default):*
```
target_portfolio = desired_annual_income / withdrawal_rate
withdrawal_rate = 0.04 (configurable, range 0.03-0.06)
```

*Variable Percentage with Guardrails (advanced):*
```
base_rate = 0.05 (initial withdrawal rate, higher because of guardrails)
ceiling_rate = base_rate * 1.20  # Never increase withdrawal by >20%
floor_rate = base_rate * 0.80    # Never decrease withdrawal by >20%

annual_withdrawal = portfolio_value * base_rate
if annual_withdrawal > previous_withdrawal * 1.10
  annual_withdrawal = previous_withdrawal * ceiling_rate
end
if annual_withdrawal < previous_withdrawal * 0.90
  annual_withdrawal = previous_withdrawal * floor_rate
end
```

**CPP Estimation:**
```ruby
# Maximum CPP monthly benefit (2025): $1,364.60
# Average CPP monthly benefit: ~$816.52
# Adjustment factors:
#   Before 65: -0.6% per month (max -36% at age 60)
#   After 65: +0.7% per month (max +42% at age 70)

def estimated_cpp(start_age:, contribution_years:, max_pensionable: 1364.60)
  # NOTE: CPP/OAS dollar amounts are indexed annually by the Government of Canada.
  #       Update max_pensionable and max_oas defaults each January.
  # contribution_years out of 39 qualifying years
  base = max_pensionable * [contribution_years / 39.0, 1.0].min

  months_from_65 = (start_age - 65) * 12
  if months_from_65 < 0
    adjustment = 1.0 + (months_from_65 * 0.006)  # reduce
  else
    adjustment = 1.0 + (months_from_65 * 0.007)  # increase
  end

  (base * adjustment).round(2)
end
```

**OAS Estimation:**
```ruby
# Maximum OAS (2025): $727.67/month
# Requires 40 years of Canadian residency for full OAS
# Partial OAS: years_in_canada / 40 * max_oas
# OAS clawback (recovery tax): 15% of income over $90,997 (2025)
# Full clawback at ~$148,065

def estimated_oas(residency_years:, total_income:, max_oas: 727.67, clawback_threshold: 90997)
  base = max_oas * [residency_years / 40.0, 1.0].min

  if total_income > clawback_threshold
    clawback = (total_income - clawback_threshold) * 0.15 / 12
    [base - clawback, 0].max
  else
    base
  end
end
```

**Retirement Date Projection:**
```ruby
def project_retirement_date(current_portfolio:, monthly_contribution:, rate:, desired_income:,
                            withdrawal_rate:, cpp_monthly:, oas_monthly:, inflation:)
  # Net income needed from portfolio (in today's dollars)
  government_income = (cpp_monthly + oas_monthly) * 12
  portfolio_income_needed = desired_income - government_income
  target_portfolio = portfolio_income_needed / withdrawal_rate

  # Use existing ProjectionCalculator.months_to_target
  calculator = ProjectionCalculator.new(
    principal: current_portfolio,
    rate: rate,
    contribution: monthly_contribution,
    currency: "CAD"
  )

  months = calculator.months_to_target(target: target_portfolio)
  # Returns nil if unreachable
end
```

**Configurable vs Defaulted Assumptions:**

| Assumption | Default | Configurable? | Source |
|------------|---------|---------------|--------|
| Expected return | PAG 2025 blended (5.44%) | Yes | ProjectionAssumption |
| Inflation | PAG 2025 (2.1%) | Yes | ProjectionAssumption |
| Withdrawal rate | 4% | Yes | RetirementPlan |
| CPP start age | 65 | Yes | RetirementPlan |
| CPP benefit | Estimated from years | Yes (manual override) | RetirementPlan |
| OAS amount | Full maximum | Auto-calculated | Residency years |
| Retirement age target | None (calculated) | Yes (goal mode) | RetirementPlan |
| Desired income | None (required input) | Yes | RetirementPlan |
| Province | Family.province or "ON" | Yes | Family / RetirementPlan |

#### Data Model Changes

```ruby
# db/migrate/YYYYMMDD_create_retirement_plans.rb
class CreateRetirementPlans < ActiveRecord::Migration[7.2]
  def change
    create_table :retirement_plans, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :family, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false, default: "My Retirement Plan"

      # Income & expenses
      t.decimal :desired_annual_income, precision: 12, scale: 2  # In today's dollars
      t.decimal :current_annual_expenses, precision: 12, scale: 2  # Optional: derived from transactions

      # Withdrawal strategy
      t.string :withdrawal_method, null: false, default: "fixed_percentage"
      # "fixed_percentage" or "variable_guardrails"
      t.decimal :withdrawal_rate, precision: 5, scale: 4, default: 0.04

      # Government benefits (Canadian)
      t.integer :cpp_start_age, default: 65
      t.decimal :cpp_monthly_override, precision: 10, scale: 2  # nil = auto-estimate
      t.integer :cpp_contribution_years, default: 35
      t.integer :oas_residency_years, default: 40
      t.decimal :oas_monthly_override, precision: 10, scale: 2  # nil = auto-estimate

      # Targets
      t.integer :target_retirement_age  # nil = "when can I retire?"
      t.date :target_retirement_date    # Calculated or user-set

      # Tax planning
      t.string :drawdown_order, default: "rrsp_first"
      # "rrsp_first", "tfsa_first", "proportional"
      t.string :province  # For tax calculation; falls back to family.province

      # Results (cached from last calculation)
      t.decimal :projected_retirement_age, precision: 5, scale: 1
      t.date :projected_retirement_date
      t.decimal :required_portfolio, precision: 15, scale: 2
      t.decimal :current_portfolio, precision: 15, scale: 2
      t.decimal :monthly_gap, precision: 12, scale: 2  # Additional monthly savings needed
      t.jsonb :percentile_dates, default: {}
      # { "p10": "2042-03-01", "p25": "2040-06-01", "p50": "2039-01-01", ... }

      t.jsonb :metadata, default: {}
      t.datetime :last_calculated_at
      t.timestamps
    end

    add_index :retirement_plans, [:family_id], unique: false
  end
end
```

#### Integration with Existing Models

```
Family (has_many :retirement_plans)
  └── RetirementPlan
        ├── reads Account balances (Investment, Crypto, Depository with subtype "rrsp"/"tfsa")
        ├── reads ProjectionAssumption (effective_return, effective_inflation, effective_volatility)
        ├── uses ProjectionCalculator (months_to_target, project_with_percentiles)
        ├── uses JurisdictionAware (marginal_tax_rate for drawdown modeling)
        └── creates Milestone (retirement target as a cross-account milestone)
```

#### Canadian-Specific Considerations

- **RRSP contribution room**: Annual limit ($31,560 for 2024, indexed). Unused room carries forward. Affects maximum contribution rate for projections.
- **TFSA contribution room**: Annual limit ($7,000 for 2024, indexed). Tax-free growth + withdrawals.
- **RRSP withholding tax**: 10% up to $5K, 20% $5K-$15K, 30% over $15K (outside Quebec).
- **RRSP to RRIF conversion**: Mandatory at age 71. Minimum withdrawals increase with age.
- **OAS clawback**: Recovery tax of 15% on net income over ~$90,997 (2025). Affects high-income retirees.
- **GIS**: Guaranteed Income Supplement for low-income retirees. Income-tested — every $1 of other income reduces GIS by $0.50.
- **CPP enhancement**: Post-2019 contributions earn enhanced benefits. Model should note this for younger contributors.
- **Pension income splitting**: Couples can split eligible pension income. Not modeled in MVP but noted for future.

#### Thin-Slice Implementation Plan

**Slice 1 (MVP — 1 sprint):**
- RetirementPlan model + migration
- RetirementCalculator in `app/calculators/retirement_calculator.rb`
- Input: current portfolio total, monthly contribution, desired income, withdrawal rate
- Output: projected retirement date, required portfolio, gap
- Single page at `/retirement` with form + result display
- No CPP/OAS yet — just "when does my portfolio cover my income at X% withdrawal?"
- Uses ProjectionCalculator.months_to_target internally

**Slice 2 (CPP/OAS — 0.5 sprint):**
- Add CPP/OAS estimation methods to RetirementCalculator
- Reduce required portfolio by government benefits
- Add CPP/OAS input fields to UI
- Show government income as separate line in projection chart

**Slice 3 (Tax-Efficient Drawdown — 1 sprint):**
- RRSP vs TFSA drawdown order comparison
- Tax impact calculation using JurisdictionAware marginal rates
- Two-column comparison view showing after-tax income
- Account type detection (subtype matching for RRSP/TFSA)

**Slice 4 (Confidence Bands — 0.5 sprint):**
- Monte Carlo projection using existing project_with_percentiles
- Confidence band chart (p10-p90) for retirement date
- "X% chance of retiring by age Y" probability statement

#### UX Flow

```
Navigation: Sidebar → "Retirement" (new top-level item, between Projections and Debt)

Screen 1: Retirement Dashboard
┌─────────────────────────────────────────────────┐
│ When Can You Retire?                            │
│                                                 │
│ ┌─────────────┐  ┌─────────────┐               │
│ │ Current     │  │ Target      │               │
│ │ Portfolio   │  │ Portfolio   │               │
│ │ $245,000    │  │ $1,250,000  │               │
│ └─────────────┘  └─────────────┘               │
│                                                 │
│ Projected Retirement: Age 58 (March 2042)       │
│ [==============================------] 67%      │
│                                                 │
│ ┌─── Projection Chart (D3.js) ──────────────┐  │
│ │  Balance over time with confidence bands   │  │
│ │  Retirement target line                    │  │
│ │  CPP/OAS income start markers              │  │
│ └────────────────────────────────────────────┘  │
│                                                 │
│ ┌─── Settings Panel ────────────────────────┐   │
│ │ Desired annual income: [$50,000      ]    │   │
│ │ Withdrawal rate:       [4.0%  ▼]          │   │
│ │ CPP start age:         [65    ▼]          │   │
│ │ Expected return:       [PAG 2025 ✓]       │   │
│ │ [Reset to defaults]                       │   │
│ └───────────────────────────────────────────┘   │
│                                                 │
│ ┌─── Income Breakdown at Retirement ────────┐   │
│ │ Portfolio withdrawal:  $50,000/yr         │   │
│ │ CPP (age 65):          $12,000/yr         │   │
│ │ OAS (age 65):          $ 8,700/yr         │   │
│ │ ─────────────────────────────────         │   │
│ │ Total retirement income: $70,700/yr       │   │
│ └───────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

**Stimulus controller**: `retirement-calculator-controller.js` — debounced form submission via Turbo Frame for live recalculation.

#### Architectural Risks & Sizing

| Risk | Mitigation |
|------|------------|
| Account type detection for RRSP/TFSA | Account.subtype already exists; add "rrsp"/"tfsa"/"rrif" subtypes to Depository/Investment if not present |
| CPP/OAS rates change annually | Store rates in `retirement_plans.metadata` or a seed-able lookup; update annually |
| Performance of Monte Carlo on retirement page | Reuse existing ProjectionCalculator; cache results in retirement_plans table |
| Scope creep into full financial planning tool | MVP answers ONE question: "When can I retire?" Everything else is Slice 2+ |

**Relative Size: Large** (2-3 sprints for full feature, 1 sprint for Slice 1 MVP)

---

### F2: Historical Net Worth Chart

#### Overview

Show the user's net worth over time based on actual historical balance data. This is the most fundamental backward-looking feature: "How has my wealth changed?"

#### User Stories

**US-2.1: Net worth trend line**
> As a user, I want to see my total net worth plotted over time so that I can understand my financial trajectory.

*Acceptance Criteria:*
- Chart shows daily/weekly/monthly net worth from first account entry to today
- Net worth = sum of all asset balances - sum of all liability balances
- Time range selector: 1M, 3M, 6M, YTD, 1Y, All
- Hover tooltip shows date and net worth value
- Uses existing Balance model data (no new calculations needed)

**US-2.2: Asset vs liability breakdown**
> As a user, I want to see assets and liabilities as separate areas on the chart so that I can understand what drives net worth changes.

*Acceptance Criteria:*
- Stacked area chart: assets (green area above), liabilities (red area below), net worth (line)
- Toggle between: net worth only, assets + liabilities, by account type
- Account type breakdown: cash, investments, property, loans, credit cards

**US-2.3: Net worth milestones**
> As a user, I want to see markers on my net worth chart when I crossed milestone thresholds so that I can celebrate progress.

*Acceptance Criteria:*
- Overlay markers at dates when net worth first crossed $10K, $50K, $100K, etc.
- Click marker to see "You reached $100K on March 15, 2024"
- Only show milestones that have been achieved

#### Data Model Changes

**No new tables needed.** The Balance model already stores daily balances per account with dates. The query aggregates across accounts:

```ruby
# Family#historical_net_worth(period:)
# Aggregates Balance records grouped by date
# Returns: [{ date: Date, net_worth: Decimal, assets: Decimal, liabilities: Decimal }]
```

One new cached method on Family or BalanceSheet:

```ruby
# app/models/balance_sheet.rb (existing)
def net_worth_series(period: "all", interval: :monthly)
  # Query: SELECT date,
  #   SUM(CASE WHEN classification = 'asset' THEN end_balance ELSE 0 END) as assets,
  #   SUM(CASE WHEN classification = 'liability' THEN end_balance ELSE 0 END) as liabilities
  # FROM balances JOIN accounts ON ...
  # WHERE accounts.family_id = ? AND accounts.status = 'active'
  # GROUP BY date ORDER BY date
end
```

#### Integration with Existing Models

```
Family → BalanceSheet (existing)
  └── net_worth_series (new method)
        ├── reads Balance records (existing, populated by sync)
        ├── joins Account for classification (asset/liability, existing generated column)
        └── outputs to D3.js chart via Turbo Frame
```

#### Canadian-Specific Considerations

- Currency: All balances converted to family currency (CAD) using exchange rates at each date
- RRSP/TFSA balances included at market value (pre-tax for RRSP — note in UI: "RRSP values shown pre-tax")
- Property values: Updated via Valuation entries (manual, or future/aspirational integration with Zillow/HouseSigma)

#### Thin-Slice Implementation Plan

**Slice 1 (MVP — 3-4 days):**
- Add `net_worth_series` method to BalanceSheet
- SQL query aggregating balances by date with asset/liability split
- New route: `GET /net_worth` or add as tab on existing dashboard
- D3.js line chart showing net worth over time
- Time range selector (Stimulus controller)

**Slice 2 (Breakdown — 2-3 days):**
- Stacked area chart with assets/liabilities
- Toggle for account type breakdown
- Hover tooltip with detailed breakdown

**Slice 3 (Milestones — 1-2 days):**
- Query for first date net worth crossed each standard threshold
- Overlay markers on chart
- Celebration UI for recently achieved milestones

#### UX Flow

```
Navigation: Dashboard page → "Net Worth" tab (alongside existing overview)

┌─────────────────────────────────────────────────┐
│ Net Worth Over Time                             │
│ [1M] [3M] [6M] [YTD] [1Y] [All]               │
│                                                 │
│ ┌─── Chart ─────────────────────────────────┐   │
│ │         ╱‾‾‾‾╲                            │   │
│ │    ╱‾‾‾╱      ╲___╱‾‾‾‾‾→ $245,000       │   │
│ │ __╱    Assets ■ ■ ■ ■                     │   │
│ │        ──────────────── ← Net Worth Line  │   │
│ │        Liabilities ▬ ▬ ▬                  │   │
│ │ ★ $100K achieved (Mar 2024)               │   │
│ └───────────────────────────────────────────┘   │
│                                                 │
│ Current: $245,000  ↑ $12,400 (5.3%) this month  │
│ Assets: $380,000 | Liabilities: $135,000        │
└─────────────────────────────────────────────────┘
```

#### Architectural Risks & Sizing

| Risk | Mitigation |
|------|------------|
| Large date ranges produce many data points | Downsample: daily for <3M, weekly for 3M-1Y, monthly for >1Y |
| Mixed currencies in balances | Use existing exchange rate data; convert to family currency in SQL or Ruby |
| Missing balance data for some dates | Balances are forward-filled by the sync process; gaps are rare |
| N+1 on account classification | Use the generated `classification` column on accounts table — single JOIN |

**Relative Size: Small** (1 sprint)

---

### F3: Emergency Fund Tracker

#### Overview

Track progress toward an emergency fund target, automatically calculated from the user's monthly expenses. Most financial advisors recommend 3-6 months of expenses as an emergency cushion.

#### User Stories

**US-3.1: Auto-calculated emergency fund target**
> As a user, I want the app to calculate my recommended emergency fund based on my actual monthly expenses so that I have a personalized savings target.

*Acceptance Criteria:*
- Target = average monthly expenses * months_of_coverage (default 3, configurable 1-12)
- Monthly expenses derived from Transaction data (outflows, excluding transfers and one-time large purchases)
- Uses trailing 6-month average for stability
- Shows: target amount, current amount, gap, progress percentage

**US-3.2: Designate emergency fund account(s)**
> As a user, I want to designate one or more accounts as my emergency fund so that the tracker knows my current emergency savings.

*Acceptance Criteria:*
- User tags accounts as "emergency fund" via a toggle on account settings
- Multiple accounts can be tagged (e.g., HISA + part of chequing)
- Emergency fund balance = sum of tagged account balances
- If no accounts tagged, prompt user to designate one

**US-3.3: Emergency fund progress dashboard**
> As a user, I want to see a visual progress indicator for my emergency fund so that I know how close I am to being fully funded.

*Acceptance Criteria:*
- Progress bar showing current / target
- Color coded: red (<33%), yellow (33-66%), green (67-99%), gold (100%+)
- Shows "You're covered for X months" based on current balance / monthly expenses
- Card displayed on main dashboard and on account detail for tagged accounts

#### Data Model Changes

```ruby
# db/migrate/YYYYMMDD_create_emergency_fund_settings.rb
class CreateEmergencyFundSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :emergency_fund_settings, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :family, type: :uuid, null: false, foreign_key: true
      t.integer :months_of_coverage, null: false, default: 3
      t.decimal :monthly_expenses_override, precision: 12, scale: 2  # nil = auto-calculate
      t.decimal :target_amount, precision: 12, scale: 2  # Cached calculation
      t.decimal :current_amount, precision: 12, scale: 2  # Cached from tagged accounts
      t.string :currency, null: false, default: "CAD"
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :emergency_fund_settings, :family_id, unique: true

    # Tag accounts as emergency fund
    add_column :accounts, :is_emergency_fund, :boolean, default: false
  end
end
```

#### Integration with Existing Models

```
Family (has_one :emergency_fund_setting)
  ├── Account (scope :emergency_fund → where(is_emergency_fund: true))
  │     └── balance (summed for current emergency fund)
  └── Transactions (trailing 6-month average outflows for target)
        └── IncomeStatement (existing) → monthly expenses
```

#### Canadian-Specific Considerations

- **HISA (High-Interest Savings Account)**: Common Canadian emergency fund vehicle. Account subtype should support "hisa" designation.
- **TFSA as emergency fund**: Some Canadians use TFSA for emergency savings (tax-free withdrawal). Note: TFSA contribution room is restored the following calendar year after withdrawal.
- **CDIC insurance**: Emergency funds should ideally be in CDIC-insured accounts (up to $100K per category). Could add a data quality warning if emergency fund exceeds $100K in a single institution.

#### Thin-Slice Implementation Plan

**Slice 1 (MVP — 3-4 days):**
- Migration: add `is_emergency_fund` to accounts, create `emergency_fund_settings`
- EmergencyFundCalculator: compute monthly expenses from trailing 6 months of transactions
- Account settings toggle for "This is my emergency fund"
- Dashboard card: progress bar, months covered, target vs current

**Slice 2 (Polish — 2-3 days):**
- Settings page: configure months_of_coverage (slider: 1-12)
- Manual override for monthly expenses
- Exclude categories (e.g., "one-time" or "mortgage" from expense calculation)
- Data quality warning if no transaction data available

#### UX Flow

```
Navigation: Dashboard → Emergency Fund card (always visible if configured)
            Account Settings → "Emergency Fund" toggle

Dashboard Card:
┌─────────────────────────────────────────┐
│ Emergency Fund                          │
│                                         │
│ [$12,500 of $18,000]                    │
│ [████████████████░░░░░░░] 69%           │
│                                         │
│ Covers 4.2 months of expenses           │
│ Target: 6 months ($3,000/mo avg)        │
│                                         │
│ [Configure ›]                           │
└─────────────────────────────────────────┘
```

#### Architectural Risks & Sizing

| Risk | Mitigation |
|------|------------|
| Users with no transaction history | Show setup prompt; allow manual expense override |
| Expense calculation accuracy | Exclude transfers (existing Category logic), use 6-month trailing average |
| Multiple currencies in emergency accounts | Convert to family currency; warn if emergency fund is in foreign currency |

**Relative Size: Small** (1 sprint)

---

## 4. Tier 2 — Build Soon

---

### F4: Multi-Debt Support

**MVP Description:**
Extend the debt tracking system beyond the current primary-mortgage + rental-mortgage + HELOC trio to support arbitrary collections of debts (student loans, car loans, credit cards, personal lines of credit). The current `DebtOptimizationStrategy` model hard-codes three `belongs_to` relationships for specific loan accounts. The MVP would introduce a `debt_portfolio` join model that associates a strategy with N debt accounts, each with a role (e.g., "target debt", "credit line", "secondary debt"). This unlocks avalanche/snowball in F5.

**Key Data Model Change:**
```ruby
# New: DebtPortfolioMembership (join table)
create_table :debt_portfolio_memberships, id: :uuid do |t|
  t.references :debt_optimization_strategy, type: :uuid, null: false, foreign_key: true
  t.references :account, type: :uuid, null: false, foreign_key: true
  t.string :role, null: false  # "primary", "secondary", "credit_line", "target"
  t.integer :priority  # For ordering in payoff strategies
  t.jsonb :metadata, default: {}
  t.timestamps
end
```

**Primary Calculation/Integration Challenge:**
The existing `AbstractDebtSimulator` and its subclasses assume exactly three accounts (primary mortgage, HELOC, rental mortgage). Generalizing the simulator to iterate over N debts requires extracting the per-debt interest calculation into a loop and making the "flow of funds" waterfall configurable. The Smith Manoeuvre simulator specifically needs the three-account structure, so the generalization should be additive — a new `MultiDebtPayoffSimulator` alongside the existing Smith simulators.

**Canadian Considerations:** Canadian student loans have special rules (federal portion has floating prime + 0%, provincial varies). Credit card minimum payments are regulated differently by province.

**Relative Size: Medium** (2 sprints)

---

### F5: Avalanche / Snowball / Custom Debt Payoff

**MVP Description:**
Given a multi-debt portfolio (from F4), calculate and compare three payoff strategies: avalanche (highest interest rate first), snowball (lowest balance first), and custom (user-defined priority). Show total interest paid, time to debt-free, and a month-by-month comparison chart. This reuses the simulator pattern from the Smith Manoeuvre but with a simpler flow: all extra payments go to the priority debt; minimum payments on all others.

**Key Data Model Change:**
Add `payoff_method` enum to `DebtOptimizationStrategy`: `"avalanche"`, `"snowball"`, `"custom"`, alongside existing `"baseline"` and `"modified_smith"`. The ledger entry model already supports generic debt tracking.

**Primary Calculation Challenge:**
```
Each month:
  1. Pay minimum on all debts
  2. Apply extra payment to priority debt (determined by strategy)
  3. When priority debt is paid off, roll its payment into next priority (the "snowball/avalanche")
  4. Track total interest, payoff dates per debt
```
The avalanche is mathematically optimal but the snowball provides psychological wins. The comparison view showing both simultaneously is the key UX differentiator.

**Canadian Considerations:** Canadian credit card minimum payments are typically 2-3% of balance or $10, whichever is greater. Student loan interest (federal portion) may be tax-deductible. Mortgage prepayment penalties (IRD or 3-month interest) should be warned about.

**Relative Size: Medium** (2 sprints) — **Blocked by F4**

---

### F6: Cross-Account Savings Goals

**MVP Description:**
Let users create savings goals (vacation: $5,000, car: $15,000, house down payment: $100,000) that draw progress from one or more designated accounts. Unlike the existing Milestone model (which is per-account), savings goals span accounts: "My vacation fund is split between my TFSA and chequing." The MVP shows goal name, target, current total, projected date, and a progress bar.

**Key Data Model Change:**
```ruby
create_table :savings_goals, id: :uuid do |t|
  t.references :family, type: :uuid, null: false, foreign_key: true
  t.string :name, null: false
  t.decimal :target_amount, precision: 12, scale: 2, null: false
  t.string :currency, null: false, default: "CAD"
  t.date :target_date  # Optional deadline
  t.decimal :monthly_contribution, precision: 10, scale: 2, default: 0
  t.string :status, default: "active"  # active, achieved, paused
  t.string :icon  # emoji or icon name
  t.jsonb :metadata, default: {}
  t.timestamps
end

# Join: which accounts fund this goal, and what portion
create_table :savings_goal_allocations, id: :uuid do |t|
  t.references :savings_goal, type: :uuid, null: false, foreign_key: true
  t.references :account, type: :uuid, null: false, foreign_key: true
  t.decimal :allocated_amount, precision: 12, scale: 2  # Fixed amount from this account
  t.decimal :allocated_percentage, precision: 5, scale: 2  # Or percentage of account balance
  t.timestamps
end
```

**Primary Calculation Challenge:**
Summing allocated amounts across accounts is straightforward. The complexity is in projecting when a goal will be reached: if the user contributes $500/month, which accounts does it go to? The MVP should simply use the total monthly contribution without per-account routing, deferring the allocation-over-time question.

**Canadian Considerations:** TFSA is the natural Canadian savings vehicle (tax-free growth). RESP for education goals has government matching (CESG: 20% match up to $500/year). FHSA (First Home Savings Account) for house down payments has $8,000/year limit.

**Relative Size: Medium** (2 sprints)

---

### F7: RRSP Reinvestment Modeling

**MVP Description:**
When the Smith Manoeuvre generates a tax refund (from deductible HELOC interest), the refund can be reinvested into RRSP, which itself generates another (smaller) tax refund, creating a compounding loop. The MVP adds a toggle to the existing Smith Manoeuvre simulator: "Reinvest tax refund into RRSP." When enabled, each year's tax refund is added as an RRSP contribution, and the resulting second-order refund is calculated and displayed.

**Key Data Model Change:**
Add columns to `DebtOptimizationStrategy`:
```ruby
add_column :debt_optimization_strategies, :reinvest_tax_refund, :boolean, default: false
add_column :debt_optimization_strategies, :reinvest_target_account_id, :uuid
# FK to an Investment account (subtype: rrsp)
```

Add columns to `DebtOptimizationLedgerEntry`:
```ruby
add_column :debt_optimization_ledger_entries, :rrsp_contribution, :decimal, precision: 12, scale: 2, default: 0
add_column :debt_optimization_ledger_entries, :rrsp_refund, :decimal, precision: 12, scale: 2, default: 0
add_column :debt_optimization_ledger_entries, :cumulative_rrsp_value, :decimal, precision: 15, scale: 2, default: 0
```

**Primary Calculation Challenge:**
The compounding loop: tax_refund → RRSP contribution → marginal_rate * contribution = second_refund → reinvest again. This is a geometric series that converges: `total = refund / (1 - marginal_rate)`. The implementation adds this to the annual step of `CanadianSmithManoeuvrSimulator`, checking RRSP contribution room.

**Canadian Considerations:** RRSP contribution room is limited (18% of prior-year earned income, max $31,560 for 2024). Excess contributions face 1%/month penalty. Must track available room. RRSP contributions reduce net income, which may affect OAS/GIS in retirement.

**Relative Size: Small** (1 sprint)

---

## 5. Tier 3 — Build Later

---

### F8: Tax Bracket Visualization

**MVP Description:**
Show the user's estimated position within Canadian federal + provincial tax brackets based on their income data. A horizontal bar chart showing: current bracket, income needed to reach next bracket, effective vs marginal rate. Leverages the existing `JurisdictionAware` concern which already has tax rate tables. The MVP would add a page under Settings or a section on the Projections page showing a visual bracket breakdown.

**Key Data Model Change:** None — uses existing income data from Transactions (income category) and tax rates from Jurisdiction/JurisdictionAware. May need a `TaxProfiler` calculator that estimates annual income from YTD transactions.

**Primary Challenge:** Accurately estimating annual income from transaction data. Users may have irregular income, bonuses, or multiple income sources. The MVP should allow manual income input with auto-populated suggestion from transactions.

**Canadian Considerations:** Federal + provincial brackets are separate (not additive). Basic personal amount, spousal amount, and common credits should be noted. Quebec has its own income tax system (Revenu Quebec, not CRA).

---

### F9: What-If Scenarios for Income Changes

**MVP Description:**
A scenario engine that lets users ask "What if my income increases by $10K?" or "What if I lose my job for 6 months?" and see the impact on projections, retirement date, and debt payoff timeline. The MVP would create a `Scenario` model that stores overrides (income change, expense change, contribution change) and re-runs the relevant calculators with those overrides, showing a side-by-side comparison with the baseline.

**Key Data Model Change:**
```ruby
create_table :scenarios, id: :uuid do |t|
  t.references :family, type: :uuid, null: false, foreign_key: true
  t.string :name, null: false
  t.string :scenario_type  # "income_change", "expense_change", "combined"
  t.jsonb :overrides, default: {}
  # Example: { "monthly_income_delta": 833, "duration_months": null, "start_date": "2026-06-01" }
  t.jsonb :results, default: {}  # Cached results
  t.timestamps
end
```

**Primary Challenge:** The scenario engine must orchestrate multiple calculators (ProjectionCalculator, RetirementCalculator, debt simulators) with modified inputs. This is architecturally complex — it's essentially a "what-if wrapper" around all existing calculators. The thin slice should target a single calculator (projections) first.

**Canadian Considerations:** EI (Employment Insurance) benefits during job loss: 55% of insurable earnings, max $668/week (2024), for up to 45 weeks. Severance pay taxation rules differ from regular income.

---

### F10: Bill Tracking / Upcoming Payments

**MVP Description:**
Detect recurring transactions (rent, utilities, subscriptions, loan payments) from transaction history and display an upcoming payments calendar. The MVP would use pattern detection on transactions (same merchant, similar amount, regular interval) to identify recurring bills, then project them forward.

**Key Data Model Change:**
```ruby
create_table :recurring_transactions, id: :uuid do |t|
  t.references :family, type: :uuid, null: false, foreign_key: true
  t.references :account, type: :uuid, null: false, foreign_key: true
  t.references :merchant, type: :uuid, foreign_key: { to_table: :merchants }
  t.string :name, null: false
  t.decimal :expected_amount, precision: 12, scale: 2
  t.string :frequency  # "monthly", "biweekly", "quarterly", "annual"
  t.integer :day_of_month  # For monthly
  t.date :next_expected_date
  t.string :status, default: "active"
  t.boolean :auto_detected, default: true
  t.jsonb :metadata, default: {}
  t.timestamps
end
```

**Primary Challenge:** Recurring transaction detection is a pattern matching problem. Matching by merchant name + approximate amount + regular interval requires fuzzy matching logic. False positives (one-time purchases at the same store) must be filterable. This is the most infrastructure-heavy feature in the roadmap.

**Canadian Considerations:** Pre-authorized debits (PADs) are governed by Payments Canada rules. Utility billing cycles vary by province. Property tax installments are typically quarterly or monthly depending on municipality.

---

## 6. Dependency Map

```
F1 Retirement ──────────────────────────────── (independent)
F2 Net Worth Chart ─────────────────────────── (independent)
F3 Emergency Fund ──────────────────────────── (independent)
F4 Multi-Debt ──────────────────────────────── (independent)
F5 Avalanche/Snowball ──── BLOCKED BY F4 ──── (requires multi-debt)
F6 Savings Goals ───────────────────────────── (independent)
F7 RRSP Reinvestment ───────────────────────── (independent, extends Smith Manoeuvre)
F8 Tax Brackets ────────────────────────────── (independent)
F9 What-If Scenarios ───── BENEFITS FROM F1 ── (soft dependency on retirement calc)
F10 Bill Tracking ──────────────────────────── (independent)
```

**Hard dependencies:** F5 → F4 only.
**Soft dependencies:** F9 benefits from F1 (can reuse RetirementCalculator for scenario modeling).

---

## 7. Verification Checklist

| Requirement | Status |
|-------------|--------|
| All 10 feature gaps addressed | All 10 listed with tier assignment, description, and sizing |
| Top features have user stories | F1: 5 stories, F2: 3 stories, F3: 3 stories |
| Top features have acceptance criteria | Every user story has explicit AC |
| Top features have data model drafts | F1: retirement_plans table, F2: no new tables, F3: emergency_fund_settings + account flag |
| Top features have thin-slice plans | F1: 4 slices, F2: 3 slices, F3: 2 slices |
| Canadian-specific considerations documented for every feature | All 10 features have Canadian notes |
| Roadmap has clear sequencing | Visual timeline + dependency map |
| Dependencies noted | F5 blocked by F4; F9 soft-depends on F1 |
| Financial math specified for retirement calculator | Withdrawal methods, CPP/OAS formulas, drawdown order logic |
| UX flows sketched for MVPs | F1, F2, F3 all have wireframe sketches |
| Architectural risks identified | Each Tier 1 feature has risk table with mitigations |
| Relative sizing provided | All features sized (Small/Medium/Large) |

---

*Document prepared by the ROMS Finance Expert Review Team. Ready for sprint planning.*
