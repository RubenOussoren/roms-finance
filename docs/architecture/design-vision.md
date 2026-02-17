# ROMS Finance Design Vision & Integration Guide

**Purpose**: This document captures the original **design vision** for integrating investment dashboard and HELOC tool concepts into the Rails application. It served as a planning artifact during early phases.

> **WARNING — Aspirational document**: Code examples in this file reflect the *original design vision*, not the current implementation. Several patterns were implemented differently (e.g., `Projectable` concern was replaced by `Account::ProjectionFacade`, `TaxCalculatorConfig` model was replaced by `JurisdictionAware` concern, `run(months:)` API was replaced by `simulate!`). For current architecture, see the Cursor rules in `.cursor/rules/` and the actual source code.

---

## Executive Summary

We are building a **comprehensive personal finance platform** that goes beyond simple account tracking to provide:

1. **Adaptive, Professional-Grade Investment Projections** - Not naive calculators that assume perfection, but tools that learn from actual history
2. **Tax-Optimized Debt Strategies** - Sophisticated simulations for Canadian tax strategies (Smith Manoeuvre, HELOC optimization)
3. **Regulatory Compliance** - PAG 2025 standards for financial planning, CRA audit trail compliance
4. **Data-Driven Decision Making** - Probabilistic forecasts with confidence intervals, not false precision
5. **Clean Rails Architecture** - Leveraging Ruby/Rails strengths while maintaining professional financial engineering standards

**Core Philosophy**: *"Simple for users, sophisticated under the hood"*

---

## Implementation Status

For current implementation status, see git log and phase review reports in `docs/reviews/`. For planned features, see `docs/FEATURE_ROADMAP.md`.

**Note**: The `investment-dashboard/` directory contains a **Python prototype** used for requirements discovery and proof-of-concept only. All production implementation is pure Rails/Ruby - no Python microservice integration.

---

## Part 0: Multi-Jurisdiction Architecture Philosophy

### 0.1 Canadian-First, Globally-Extensible Design

**Primary Audience**: Canadian users (80%+ of content and examples)

**Design Principle**: Build for Canada today, architect for global expansion tomorrow.

This document primarily focuses on **Canadian implementations** (PAG 2025, CRA tax rules, Smith Manoeuvre) while establishing architectural patterns that allow future US/UK/EU implementations **without rewriting core concepts**.

### 0.2 Visual Markers

Throughout this document, you'll see these markers:

- 🇨🇦 **Canadian-specific** - Implementation details specific to Canada (PAG 2025, CRA, tax rules, account examples)
- 🌍 **Universal** - Concepts that apply globally (portfolio projections, Monte Carlo, debt optimization principles)
- 🔧 **Extensibility hook** - Architectural patterns designed for future jurisdictions (Provider pattern, config models)
- 🇺🇸 **Future: US** - Commented examples showing how US support would be added
- 🇬🇧 **Future: UK** - Commented examples showing how UK support would be added

### 0.3 Three-Tier Architecture Approach

#### Tier 1: Universal Concepts 🌍
Financial planning concepts that work everywhere:
- Portfolio projection mathematics (compound growth, Monte Carlo simulation)
- Risk modeling and confidence intervals
- Milestone tracking and goal-setting
- Debt optimization strategies (general principles)
- Rebalancing strategies

#### Tier 2: Jurisdiction-Specific Implementations 🇨🇦 🇺🇸 🇬🇧
Country-specific rules and standards:
- **Canada** 🇨🇦: PAG 2025, CRA tax rules, Smith Manoeuvre, Canadian account flows
- **US** 🇺🇸 (Future): CFP Board standards, IRS tax rules, HELOC interest deductibility
- **UK** 🇬🇧 (Future): FCA standards, HMRC tax rules, offset mortgages

#### Tier 3: Configuration Over Code 🔧
Jurisdiction differences handled through **configuration**, not code changes:
- Tax brackets stored in database (not hardcoded)
- Projection standards as data records (PAG 2025, CFP Board, etc.)
- Deductibility rules in JSON (flexible per jurisdiction)
- Strategy simulators as pluggable classes (Canadian Smith Manoeuvre, US HELOC arbitrage, etc.)

### 0.4 Provider Pattern Alignment

This architecture **leverages the existing Provider pattern** already in Maybe Finance:

```ruby
# Existing pattern in Maybe Finance (app/models/provider/)
Provider::Registry.get_provider(:synth)  # Market data provider
Provider::Registry.get_provider(:plaid)  # Bank connectivity provider

# Extended for jurisdictions 🔧
Jurisdiction.find_by(country_code: 'CA')  # Canada jurisdiction
  → .projection_standard                   # PAG 2025
  → .tax_calculator_config                 # CRA rules
  → .available_strategies                  # Modified Smith Manoeuvre

Jurisdiction.find_by(country_code: 'US')  # Future: US jurisdiction
  → .projection_standard                   # CFP Board standards
  → .tax_calculator_config                 # IRS rules
  → .available_strategies                  # HELOC arbitrage
```

**Benefits:**
- Consistent with existing codebase patterns
- Add new countries via seed data (no code changes)
- User families can have jurisdiction association
- Default to Canadian rules (primary market)

### 0.5 Implementation Strategy

**Phase 1-4 (Current)**: Build with **Canadian defaults**
- All examples are Canadian (Monika/Ruben accounts, CRA compliance, PAG 2025)
- Database schema includes `jurisdiction_id` (optional, defaults to Canada)
- Tax rules stored as JSON (ready for other jurisdictions)
- Strategy enums include country-specific values

**Phase 5+ (Future)**: Add **additional jurisdictions** via configuration
- Create US jurisdiction seed data
- Add US tax calculator config (IRS brackets, different deductibility rules)
- Implement US-specific simulator (if logic differs significantly)
- Add US projection standard (CFP Board)
- **No refactoring required** - just new data + strategies

### 0.6 What This Means for You

**If you're a Canadian user:**
- This system is built for you
- All examples reflect Canadian accounts, tax rules, and compliance
- PAG 2025 and CRA are first-class citizens

**If you're a developer:**
- Focus on Canadian implementation quality
- Use jurisdiction abstraction patterns shown in 🔧 sections
- Don't hardcode Canadian assumptions in model logic
- Store country-specific rules in database (not code)

**If you're planning US/UK/EU support:**
- Core architecture is ready
- See Part 8 (Jurisdiction Configuration Guide) for blueprint
- Add new jurisdiction via seed data + simulator class
- No core model changes needed

---

## Part 1: Investment Dashboard - Vision & Principles

### 1.1 The Core Problem We're Solving 🌍

**Traditional portfolio calculators are naive.** They ask "How much will you contribute?" and assume:
- You'll contribute exactly that amount every month forever
- Markets will return exactly X% every year
- You started contributing at your current rate from day one

**Reality is messy:**
- Contributions vary (raises, bonuses, life changes)
- Markets are volatile and correlated
- Past behavior predicts future behavior better than optimistic assumptions

**Our Solution: Adaptive Projections**
- Use **actual historical portfolio values** as the starting point
- Project **forward** from current state using **current contribution settings**
- Account for **actual market performance**, not just expected returns
- Provide **probabilistic forecasts** with confidence bands, not single-line projections

### 1.2 Key Features to Integrate

#### Feature 1: Adaptive Historical Tracking 🌍
**What it does**: Compares actual portfolio growth against projections based on contribution plan.

**How it works**:
1. User uploads portfolio snapshots (CSV import or manual entry)
2. System calculates "Expected (History)" line - what the portfolio *should have been* at each snapshot based on contributions and market returns
3. Compares "Actual" vs "Expected" to show if user is ahead/behind
4. Calculates forecast accuracy metrics (MAPE, RMSE, Tracking Signal)

**Rails Implementation**:
```ruby
# app/models/account/projection.rb
class Account::Projection < ApplicationRecord
  belongs_to :account

  # Stores a single projection scenario
  # date, projected_value, actual_value, contribution_expected, contribution_actual

  def forecast_error
    return nil unless actual_value.present?
    ((projected_value - actual_value) / actual_value * 100).abs
  end
end

# app/models/concerns/projectable.rb
module Projectable
  def adaptive_projection(years:, contribution:)
    # Start from current balance (actual), not theoretical
    # Project forward using compound growth
    ProjectionCalculator.new(self).adaptive(years: years, contribution: contribution)
  end

  def forecast_accuracy
    # Calculate MAPE, RMSE, Tracking Signal from stored projections
    ForecastAccuracyCalculator.new(self.projections).calculate
  end
end
```

**Data Flow**:
```
Portfolio Snapshot Upload
  → CSV Parser extracts holdings by date
  → Store in account_snapshots table
  → Calculate inferred contributions (delta in book value)
  → Validate contributions (detect anomalies)
  → Recalculate projections from each snapshot date
  → Generate "Expected (History)" series
  → Display Actual vs Expected chart
```

**UI Pattern**: Extend existing time series chart with:
- Multiple series: Actual (solid), Expected-History (dashed), Expected-Future (solid with shading)
- Toggle for deviation shading (area between Actual and Expected)
- Contribution variance warnings (prominent callout boxes)

---

#### Feature 2: Monte Carlo Risk Modeling 🌍
**What it does**: Shows range of possible outcomes with probabilistic confidence bands.

**Why it matters**:
- Single-line projections give false sense of certainty
- Users need to understand uncertainty to plan appropriately
- Professional financial planning standard (not optional for serious tools)

**Implementation**: ✅ **Complete** - Pure Ruby with Box-Muller transform
- See `app/calculators/projection_calculator.rb` for `project_with_percentiles` method
- Runs 1000 simulations, returns p10/p25/p50/p75/p90 percentiles
- Acceptable performance for self-hosted deployment (< 2s)

**Chart Visualization**:
- Fan chart with percentile bands (p10, p25, p50, p75, p90)
- Median line (p50) as "most likely" outcome
- Shaded areas for confidence intervals

---

#### Feature 3: Professional Standards Compliance 🇨🇦 + 🔧

**What it is**: Integration with professional financial planning standards

**Canadian Implementation: PAG 2025** 🇨🇦

FP Canada Projection Assumption Guidelines 2025 - the professional standard for Canadian financial planning.

**Why it matters**:
- Based on 50 years of actuarial data
- Safety margin: -0.5% applied to `blended_return` via `safety_margin` field in `PAG_2025_ASSUMPTIONS`
- Allows financial planners to cite projections as professionally prepared
- Industry standard for defensible long-term projections

**Key Components**:

1. **Geographic Equity Classification** 🇨🇦:
   - Canadian Equities: 6.6% nominal return (4.5% real), 15.7% volatility
   - US Equities: 6.6% nominal (4.5% real), 16.1% volatility
   - International Developed: 6.9% nominal (4.8% real), 19.3% volatility
   - Emerging Markets: 8.0% nominal (5.9% real), 23.9% volatility

2. **Inflation Modeling**: 2.1% inflation (CPP/QPP actuarial assumption)

3. **Real vs. Nominal Returns**: Toggle between inflation-adjusted and nominal

4. **Fixed Income**: 3.4% nominal (1.3% real), 7.8% volatility

**Rails Implementation** (supports multiple jurisdictions) 🔧:

```ruby
# app/models/projection_standard.rb 🔧
class ProjectionStandard < ApplicationRecord
  belongs_to :jurisdiction

  enum standard_type: {
    pag_2025: 0,        # 🇨🇦 FP Canada
    cfp_board_2025: 1,  # 🇺🇸 Future
    iso_guidance: 2,    # 🌍 Future
    custom: 3
  }

  jsonb :asset_assumptions  # Allows different asset classes per standard
  string :compliance_badge_text
  boolean :active
end

# app/models/jurisdiction.rb 🔧
class Jurisdiction < ApplicationRecord
  has_many :projection_standards
  string :country_code  # "CA", "US", "GB"
  belongs_to :default_projection_standard,
             class_name: 'ProjectionStandard',
             optional: true
end

# app/models/concerns/jurisdiction_aware.rb 🔧
module JurisdictionAware
  def jurisdiction
    family.jurisdiction || Jurisdiction.default
  end

  def projection_standard
    jurisdiction.default_projection_standard
  end
end

# app/models/projection_assumption.rb
class ProjectionAssumption < ApplicationRecord
  # Stores assumptions for an asset or asset class
  belongs_to :security, optional: true  # For individual tickers
  belongs_to :family  # Family-specific overrides
  belongs_to :projection_standard, optional: true  # 🔧 Links to jurisdiction standard

  enum asset_class: {
    canadian_equity: 0,
    us_equity: 1,
    intl_developed_equity: 2,
    emerging_market_equity: 3,
    fixed_income: 4,
    short_term: 5,
    alternative: 6,
    custom: 7
  }

  # Expected return and volatility
  decimal :nominal_return  # e.g., 0.066 for 6.6%
  decimal :real_return     # Calculated: nominal - inflation
  decimal :volatility      # Standard deviation
  decimal :inflation_rate  # Default: 0.021 (2.1%)

  boolean :standard_compliant  # Using standard values? (PAG, CFP, etc.)

  # Automatically classify assets
  def self.classify_security(security)
    # Logic to determine asset class from ticker/exchange
    # e.g., VCN.TO → canadian_equity (🇨🇦)
    #       VOO → us_equity (🇺🇸)
    #       VTI → us_equity (🇺🇸)
    #       VXUS → intl_developed_equity (🌍)
  end

  # 🇨🇦 PAG 2025 default values (Canadian implementation)
  PAG_2025_DEFAULTS = {
    canadian_equity: { nominal: 0.066, volatility: 0.157, real: 0.045 },
    us_equity: { nominal: 0.066, volatility: 0.161, real: 0.045 },
    intl_developed_equity: { nominal: 0.069, volatility: 0.193, real: 0.048 },
    emerging_market_equity: { nominal: 0.080, volatility: 0.239, real: 0.059 },
    fixed_income: { nominal: 0.034, volatility: 0.078, real: 0.013 },
    short_term: { nominal: 0.024, volatility: 0.046, real: 0.003 }
  }.freeze
end

# app/models/concerns/pag_compliant.rb 🇨🇦
module PagCompliant
  extend ActiveSupport::Concern

  def use_pag_assumptions!
    # Apply PAG 2025 defaults to portfolio assets
    # Override user assumptions with professional standards
  end

  def pag_compliant?
    # Check if all assets use PAG assumptions
  end
end
```

**Canadian PAG 2025 Seed Data** 🇨🇦:
```ruby
# db/seeds/canadian_projection_standards.rb 🇨🇦
canada = Jurisdiction.find_by(country_code: 'CA')

ProjectionStandard.create!(
  jurisdiction: canada,
  standard_type: :pag_2025,
  compliance_badge_text: "Prepared using FP Canada PAG 2025",
  active: true,
  asset_assumptions: ProjectionAssumption::PAG_2025_DEFAULTS
)
```

**UI Components**:
- Settings toggle: "Use PAG 2025 Professional Standards" 🇨🇦
- Asset classification display showing which PAG category each holding falls into
- Compliance badge on projection reports: "Prepared using FP Canada PAG 2025" 🇨🇦
- Override warning: "Custom assumptions in use - not PAG compliant"

**Future Enhancement: US CFP Board Standards** 🇺🇸 🔧
```ruby
# Future: When US support is added
# db/seeds/us_projection_standards.rb 🇺🇸
us = Jurisdiction.find_by(country_code: 'US')

ProjectionStandard.create!(
  jurisdiction: us,
  standard_type: :cfp_board_2025,
  compliance_badge_text: "Prepared using CFP Board Standards",
  active: true,
  asset_assumptions: {
    # US-specific assumptions (likely similar but may differ)
    us_equity: { nominal: 0.070, volatility: 0.180, real: 0.048 },
    # ... other asset classes
  }
)
```

---

#### Feature 4: Milestone Tracking & Goals 🌍
**What it does**: Answers "When will I reach $100K, $500K, $1M?" with probabilistic dates.

**Implementation**: ✅ **Complete**
- Model: `app/models/milestone.rb` - target amount, status, progress tracking, projected dates
- Calculator: `app/calculators/milestone_calculator.rb` - time-to-target, contribution sensitivity
- UI: `app/components/UI/account/milestone_tracker.rb` - container with milestone cards
- UI: `app/components/UI/account/milestone_card.rb` - progress bar, status badges, days remaining
- Controller: `app/controllers/milestones_controller.rb` - CRUD for custom milestones

**Standard Milestones**: $10K, $25K, $50K, $100K, $250K, $500K, $1M (pre-seeded)

**UI Features**:
- Progress bar (0-100%) with status badge (pending/in_progress/achieved)
- Next milestone highlighted, achieved milestones collapsed
- Days remaining and on-track indicator
- Custom milestone creation modal

---

#### Feature 5: Rebalancing Strategy Comparison 🌍
**What it does**: Simulates different portfolio management strategies side-by-side.

**Strategies**:
1. **None (Buy & Hold)** - Never rebalance, let winners run
2. **Annual Rebalancing** - Once per year, reset to target allocation
3. **Threshold Rebalancing** - Rebalance when any asset drifts >5% (or custom threshold)
4. **Hybrid** - Annual + threshold (rebalance if year passes OR threshold hit)

**Impact**: Can show 0.1-0.5% annual return difference over 30 years = $50K-$200K on $500K portfolio

**Rails Implementation**:
```ruby
# app/models/rebalancing_strategy.rb
class RebalancingStrategy < ApplicationRecord
  belongs_to :account

  enum strategy_type: {
    none: 0,
    annual: 1,
    threshold: 2,
    hybrid: 3
  }

  decimal :threshold_percent  # For threshold-based (e.g., 0.05 for 5%)
  integer :frequency_months   # For periodic (e.g., 12 for annual)

  # Target allocation (JSON)
  # { "AAPL": 0.20, "MSFT": 0.30, "GOOGL": 0.50 }
  json :target_allocation

  def simulate(years:)
    RebalancingSimulator.new(self).run(years: years)
  end
end

class RebalancingSimulator
  def run(years:)
    # Simulate portfolio growth with/without rebalancing
    # Track: transaction costs, tax impact, final value
    # Return comparison object
  end
end
```

**Chart**: Dual-line comparison showing portfolio value over time with/without rebalancing

---

### 1.3 Data Integration Architecture

**Philosophy**: *"Universal ticker support, intelligent routing, graceful degradation"*

#### Multi-Provider System

**Current Account Connectivity Providers:**
- **Plaid** (`Provider::Plaid`): Banking accounts — chequing, savings, credit cards, loans. US + EU regions. OAuth flow via Plaid Link with account selection/review step before import. `PlaidItem` → `PlaidAccount` → `Account`.
- **SnapTrade** (`Provider::SnapTrade`): Investment brokerage accounts — TFSA, RRSP, non-registered. Canadian brokerages (Wealthsimple, Questrade, etc.). OAuth flow with account selection/review step before import. `SnapTradeConnection` → `SnapTradeAccount` → `Account`.
- Provider routing: `AccountableResource#set_link_options` routes Investment/Crypto to SnapTrade; banking types to Plaid.

**Market Data Providers:**
- Synth (primary provider for self-hosted)
- Manual entry (always available)

**Original Design Vision (aspirational)**:
- Yahoo Finance (stocks, ETFs)
- CoinGecko (cryptocurrencies)
- Alpha Vantage (fallback)

**Integration Strategy**:
```ruby
# Extend existing Provider pattern
module Provider::MarketDataConcept
  # Fetch historical volatility
  def fetch_volatility(ticker:, years: 10)
    raise NotImplementedError
  end

  # Fetch correlation with another ticker
  def fetch_correlation(ticker1:, ticker2:, years: 10)
    raise NotImplementedError
  end

  # Fetch current price
  def fetch_price(ticker:)
    raise NotImplementedError
  end
end

# Add Yahoo Finance provider
class Provider::YahooFinance < Provider
  include Provider::MarketDataConcept

  def fetch_volatility(ticker:, years: 10)
    # Use yfinance Python library or equivalent
    # Calculate standard deviation of returns
  end
end

# Intelligent routing
class MarketDataOrchestrator
  PROVIDER_PRIORITY = {
    stocks: [:yahoo_finance, :alpha_vantage, :synth],
    crypto: [:coingecko, :yahoo_finance],
    forex: [:synth]
  }.freeze

  def fetch_with_fallback(ticker:, data_type:)
    asset_type = detect_asset_type(ticker)
    providers = PROVIDER_PRIORITY[asset_type]

    providers.each do |provider_name|
      provider = Provider::Registry.get_provider(provider_name)
      result = provider&.fetch_price(ticker: ticker)
      return result if result.success?
    rescue Provider::ProviderError => e
      Rails.logger.warn("Provider #{provider_name} failed: #{e.message}")
      next
    end

    # All providers failed
    raise Provider::AllProvidersFailed
  end
end
```

**Caching Strategy**:
- 24-hour cache for prices (daily close sufficient for projections)
- 7-day cache for volatility calculations
- 30-day cache for correlation matrices
- Invalidate on user request (manual refresh button)

---

### 1.4 Performance Considerations

**Challenge**: Monte Carlo with 1,000 simulations × 360 months = 360,000 calculations per projection

**Solutions**:

1. **Background Jobs**:
```ruby
# app/jobs/calculate_projection_job.rb
class CalculateProjectionJob < ApplicationJob
  queue_as :projections

  def perform(account_id, scenario_id)
    account = Account.find(account_id)
    scenario = ProjectionScenario.find(scenario_id)

    # Heavy calculation
    result = MonteCarloSimulator.new(account, scenario).run

    # Store results
    scenario.update(
      results: result.to_json,
      calculated_at: Time.current,
      status: :completed
    )

    # Broadcast via Turbo Stream
    Turbo::StreamsChannel.broadcast_update_to(
      "account_#{account_id}_projections",
      target: "projection_results",
      partial: "accounts/projections/results",
      locals: { results: result }
    )
  end
end
```

2. **Smart Caching**:
```ruby
# Cache key includes all inputs that affect calculation
def projection_cache_key
  [
    "projection",
    account.id,
    account.updated_at.to_i,
    account.holdings.maximum(:updated_at)&.to_i,
    projection_params.hash
  ].join("-")
end

def cached_projection
  Rails.cache.fetch(projection_cache_key, expires_in: 1.hour) do
    calculate_projection
  end
end
```

3. **Progressive Enhancement**:
- Show deterministic projection immediately (fast)
- Load Monte Carlo bands asynchronously (slow)
- Display loading skeleton with "Calculating confidence bands..."
- Update chart when calculation completes

4. **Database Optimization**:
```ruby
# Don't store 1,000 simulation paths - store percentiles
class ProjectionResult
  json :p10_values  # Array of monthly values at 10th percentile
  json :p25_values
  json :p50_values  # Median
  json :p75_values
  json :p90_values

  # Not: json :all_simulation_results (too large)
end
```

---

## Part 2: Tax-Optimized Debt Strategies - Vision & Principles

### 2.1 The Core Problem 🌍

**Homeowners face complex tax optimization decisions:**
- Should rental income accelerate primary mortgage payoff?
- When to draw on HELOC/readvanceable mortgage for rental expenses?
- Optimal timing to stop debt optimization strategies?
- Interest rate impact on tax arbitrage?

**Traditional approaches fail:**
- Accountant: "It depends" (not actionable)
- Online calculators: Too simplistic (don't model real cash flows)
- Spreadsheets: Error-prone, not shareable

**Our Solution**: Interactive simulator modeling real cash flows with jurisdiction-specific tax compliance.

**Canadian Focus** 🇨🇦: This implementation primarily supports **Modified Smith Manoeuvre** strategies with **CRA audit trail compliance**. Future enhancements may include US HELOC strategies (different deductibility rules) and UK offset mortgages (different mechanisms).

---

### 2.2 Key Concepts to Integrate

#### Concept 1: Debt Optimization Strategy Simulation 🇨🇦 + 🔧

**Architecture**: Pluggable strategy pattern for jurisdiction-specific tax rules

**Canadian Implementation: Modified Smith Manoeuvre** 🇨🇦

**What it is**: Canadian tax strategy to convert non-deductible mortgage interest into deductible investment loan interest.

**How it works** (Canadian CRA tax rules):
1. Rental income → Pay down primary mortgage (non-deductible per CRA)
2. HELOC → Fund rental expenses (deductible interest per CRA)
3. As primary decreases, HELOC limit increases (readvanceable mortgage)
4. Net effect: Shift debt from non-deductible to deductible (CRA-compliant)

**Canadian Account Flow Example** 🇨🇦:

This example shows ONE Canadian implementation (not hardcoded behavior).

```
Rental Income Flow (Monika's Setup):
  Tenant → Monika CIBC Account (net $1,805 = $1,900 - $95 mgmt)
    → Monika adds personal $95
    → BMO Joint Account ($1,900 total)
    → Primary mortgage prepayment

HELOC Flow:
  HELOC → Rental mortgage payment
  HELOC → Rental operating expenses
  (All HELOC draws = rental expenses → deductible per CRA)
```

**Rails Implementation** 🔧:

```ruby
# app/models/debt_optimization_strategy.rb 🔧
class DebtOptimizationStrategy < ApplicationRecord
  belongs_to :family
  belongs_to :jurisdiction

  # Primary mortgage
  has_one :primary_mortgage, class_name: 'Loan', as: :strategable

  # HELOC
  has_one :heloc, class_name: 'Loan', as: :strategable

  # Rental property loan (optional)
  has_one :rental_mortgage, class_name: 'Loan', as: :strategable

  enum strategy_type: {
    baseline: 0,          # Universal: no optimization
    modified_smith: 1,    # 🇨🇦 Smith Manoeuvre
    heloc_arbitrage: 2,   # 🇺🇸 Future: US HELOC strategies
    offset_mortgage: 3,   # 🇬🇧 Future: UK offset mortgages
    custom: 4
  }

  jsonb :strategy_settings  # Flexible config per strategy
  belongs_to :tax_calculator_config

  # Settings
  decimal :rental_income_monthly
  decimal :rental_expenses_monthly
  decimal :property_management_fee
  boolean :heloc_pays_rental_expenses
  boolean :use_rental_for_primary_prepayment

  # Tax settings
  decimal :marginal_tax_rate
  string :tax_owner  # 'monika', 'ruben', 'combined'

  # Auto-stop rules
  decimal :auto_stop_heloc_percentage   # Stop when HELOC reaches X% of limit
  decimal :auto_stop_heloc_balance      # Stop when HELOC balance >= $X
  boolean :auto_stop_on_primary_paid    # Stop when primary paid off

  def simulator
    case strategy_type
    when 'modified_smith'
      CanadianSmithManoeuvrSimulator.new(self)
    when 'heloc_arbitrage'
      UsHelocArbitrageSimulator.new(self)  # 🇺🇸 Future
    else
      BaselineSimulator.new(self)
    end
  end

  def simulate(months:)
    simulator.run(months: months)
  end
end

# app/models/tax_calculator_config.rb 🔧
class TaxCalculatorConfig < ApplicationRecord
  belongs_to :jurisdiction

  string :authority_name  # "CRA", "IRS", "HMRC"

  # Tax brackets by jurisdiction
  jsonb :federal_brackets
  jsonb :provincial_state_brackets

  # Deductibility rules (jurisdiction-specific)
  jsonb :deductibility_rules
  # {
  #   "rental_mortgage_interest": true,
  #   "heloc_for_rental_expenses": true,
  #   "primary_mortgage_interest": false  # 🇨🇦 Not deductible in Canada
  # }

  boolean :requires_purpose_tracking  # true for CRA
  string :compliance_report_template
end

# app/services/canadian_smith_manoeuvre_simulator.rb 🇨🇦
class CanadianSmithManoeuvrSimulator
  def initialize(strategy)
    @strategy = strategy
    @tax_config = strategy.jurisdiction.tax_calculator_config
  end

  def run(months:)
    results = {
      baseline: simulate_baseline(months),
      modified: simulate_modified(months)
    }

    # Compare: total interest paid, total tax refunds, net cost
    {
      baseline_total_interest: results[:baseline][:total_interest],
      modified_total_interest: results[:modified][:total_interest],
      baseline_tax_benefit: results[:baseline][:tax_benefit],
      modified_tax_benefit: results[:modified][:tax_benefit],
      net_savings: calculate_net_savings(results),
      month_by_month: results[:modified][:ledger]
    }
  end

  private

  def simulate_baseline(months)
    # Traditional flow:
    # Rental income → rental mortgage + expenses
    # Primary mortgage → regular payments
    # HELOC not used
  end

  # 🇨🇦 Canadian mortgage compounding: semi-annual, not monthly
  # Effective monthly rate = (1 + annual_rate/2)^(1/6) - 1
  # HELOC uses simple monthly compounding (variable rate product): rate/12
  def canadian_monthly_mortgage_rate(annual_rate)
    ((1 + annual_rate / 2.0) ** (1.0 / 6)) - 1
  end

  def simulate_modified(months)
    ledger = []

    months.times do |month|
      entry = {}

      # Rental income goes to primary prepayment (🇨🇦 CRA: non-deductible)
      entry[:rental_income] = @strategy.rental_income_monthly
      entry[:primary_prepayment] = @strategy.rental_income_monthly

      # HELOC pays rental expenses (🇨🇦 CRA: deductible)
      heloc_draw = @strategy.rental_expenses_monthly + rental_mortgage_payment
      entry[:heloc_draw] = heloc_draw
      entry[:heloc_balance] += heloc_draw

      # HELOC interest (tax deductible per CRA rules)
      # HELOC uses simple monthly compounding (variable rate product)
      heloc_interest = entry[:heloc_balance] * (@strategy.heloc.interest_rate / 12)
      entry[:heloc_interest] = heloc_interest
      entry[:tax_refund] = heloc_interest * @strategy.marginal_tax_rate

      # 🇨🇦 HELOC interest cash source tracking
      # Best practice: pay from cash (not capitalize) for cleaner CRA audit trail
      entry[:heloc_interest_cash_source] = :joint_account
      entry[:heloc_interest_paid_from_cash] = heloc_interest

      # Primary mortgage reduction
      entry[:primary_balance] -= entry[:primary_prepayment]

      # Validate CRA compliance
      validate_cra_compliance(entry)

      # Check auto-stop conditions
      if should_stop?(entry)
        entry[:strategy_stopped] = true
        # Revert to baseline flow
      end

      ledger << entry
    end

    ledger
  end

  def validate_cra_compliance(entry)
    # Check: HELOC used exclusively for rental (CRA requirement)
    # Check: Proper documentation trail exists
  end

  def should_stop?(entry)
    # Check all auto-stop conditions
    return true if @strategy.auto_stop_on_primary_paid && entry[:primary_balance] <= 0
    return true if entry[:heloc_balance] >= @strategy.auto_stop_heloc_balance
    # ... more conditions
    false
  end
end
```

**Future Enhancements** 🔧:

```ruby
# 🇺🇸 US HELOC Arbitrage (Future)
# - Different deductibility rules: mortgage interest generally deductible
# - HELOC interest capped at $100K for tax deduction
# - Different tracking requirements (Form 1098)

# 🇬🇧 UK Offset Mortgages (Future)
# - Different mechanism: offset savings against mortgage
# - HMRC compliance (different than CRA)
# - Different reporting requirements
```

---

#### Concept 2: Month-by-Month Ledger with Tax Implications 🇨🇦

**What it does**: Shows exactly where money flows each month with tax-compliant audit trail.

**Ledger Entry Example** (Canadian Implementation):
```
Month 1 (Aug 2025):
┌─────────────────────────────────────┐
│ Income & Flows                       │
├─────────────────────────────────────┤
│ Gross rental income:      $1,900    │
│ Property mgmt fee:         -$95     │
│ Net to Monika CIBC:       $1,805    │ ← 🇨🇦 Canadian account example
│ Monika adds personal:       $95     │
│ Transfer to BMO Joint:    $1,900    │ ← 🇨🇦 Canadian account example
│ BMO → Primary prepay:     $1,900    │
├─────────────────────────────────────┤
│ HELOC Usage                          │
├─────────────────────────────────────┤
│ Rental mortgage payment:  $1,175    │
│ Rental operating costs:     $797    │
│ Total HELOC draw:         $1,972    │
│ HELOC interest:             $165    │
│ HELOC balance (end):      $2,137    │
├─────────────────────────────────────┤
│ Tax Impact (CRA Rules)               │ ← 🇨🇦 Canadian tax authority
├─────────────────────────────────────┤
│ Deductible interest:        $165    │
│ Marginal tax rate:          45.0%   │
│ Tax refund (annual):         $74    │
├─────────────────────────────────────┤
│ Primary Mortgage                     │
├─────────────────────────────────────┤
│ Regular payment:          $4,376    │
│ Rental prepayment:        $1,900    │
│ Total principal reduction: $2,124   │
│ Balance (end):          $772,876    │
└─────────────────────────────────────┘
```

**Rails Implementation**:
```ruby
# app/models/debt_optimization_ledger_entry.rb
class DebtOptimizationLedgerEntry < ApplicationRecord
  belongs_to :debt_optimization_strategy

  # Month identification
  integer :month_number      # 1, 2, 3, ...
  date :calendar_month       # 2025-08-01, 2025-09-01, ...

  # Income flows
  decimal :gross_rental_income
  decimal :property_mgmt_fee
  decimal :net_rental_income
  decimal :personal_funds_added  # To make up mgmt fee

  # Mortgage payments
  decimal :primary_mortgage_payment
  decimal :primary_prepayment
  decimal :rental_mortgage_payment

  # HELOC activity
  decimal :heloc_draw
  decimal :heloc_interest_paid
  decimal :heloc_balance_end

  # Balances
  decimal :primary_balance_start
  decimal :primary_balance_end
  decimal :rental_balance_start
  decimal :rental_balance_end

  # Tax
  decimal :deductible_interest
  decimal :tax_refund_monthly
  decimal :cumulative_tax_benefit

  # Events
  boolean :strategy_stopped      # Did we stop Modified this month?
  string :stop_reason            # "HELOC limit reached", "Primary paid off", etc.
  boolean :primary_paid_off
  boolean :rental_paid_off
end

# View helper for ledger display
module LoanStrategyHelper
  def format_ledger_entry(entry)
    # Render card with all flows clearly labeled
    # Color coding: green for income, red for expenses, blue for tax benefit
  end

  def annual_summary(entries, year)
    # Sum up all entries for a calendar year
    # Show total interest paid, total tax refund, net benefit
  end
end
```

**UI Component**: Expandable month-by-month accordion with annual summaries

---

#### Concept 3: Scenario Comparison Charts 🌍
**What it does**: Side-by-side visualization of Baseline vs Optimized strategies.

**Charts to Implement**:

1. **Debt Balance Over Time**:
   - 3 lines per scenario: Primary, Rental, HELOC
   - Stacked area chart showing total debt
   - Delta line: Modified total - Baseline total (shows benefit)

2. **Cumulative Tax Benefit**:
   - Running total of tax refunds from deductible interest
   - Shows actual dollars saved

3. **Net Cost Comparison**:
   - Total interest paid - Tax refunds
   - Shows true cost of each strategy

4. **Cash Flow Impact**:
   - Month-by-month: cash in vs cash out
   - Shows liquidity impact (is strategy sustainable?)

**Rails Chart Pattern**:
```ruby
# app/models/loan_strategy/chart_series_builder.rb
class LoanStrategy::ChartSeriesBuilder
  def debt_comparison_series
    {
      labels: calendar_months,
      datasets: [
        {
          label: "Baseline - Primary",
          data: baseline_primary_balances,
          borderColor: "#ef4444",
          fill: true
        },
        {
          label: "Modified - Primary",
          data: modified_primary_balances,
          borderColor: "#10b981",
          fill: true
        },
        {
          label: "Modified - HELOC",
          data: modified_heloc_balances,
          borderColor: "#6366f1",
          borderDash: [5, 5]
        },
        {
          label: "Δ Total Debt (Mod - Base)",
          data: delta_total_debt,
          yAxisID: "y2",
          borderColor: "#f59e0b"
        }
      ]
    }
  end
end
```

**D3 Extension**: Add dual-axis support to existing time_series_chart_controller.js for delta lines

---

#### Concept 4: Auto-Stop Rules with Explanations 🌍
**What it does**: Automatically determines when to exit optimized strategy and return to baseline flow.

**Why it matters**:
- Strategy becomes risky if HELOC grows too large
- Tax benefit diminishes if tax refund < HELOC interest
- Need to monitor and adjust automatically

**Rules Implemented**:

1. **HELOC Limit** - Stop when HELOC reaches X% of limit (default: 90%)
2. **HELOC Balance** - Stop when balance exceeds $X (e.g., $40,000)
3. **HELOC Interest** - Stop when monthly interest >= $X
4. **Primary Paid Off** - Stop when primary mortgage is fully paid (mission accomplished)
5. **Tax Coverage** - Stop when tax refund < X × HELOC interest for N consecutive months

**Rails Implementation**:
```ruby
# app/models/loan_strategy/auto_stop_rule.rb
class LoanStrategy::AutoStopRule < ApplicationRecord
  belongs_to :loan_strategy

  enum rule_type: {
    heloc_limit_percentage: 0,
    heloc_balance_threshold: 1,
    heloc_interest_threshold: 2,
    primary_paid_off: 3,
    tax_coverage_ratio: 4,
    manual_date: 5
  }

  boolean :enabled
  decimal :threshold_value
  integer :consecutive_months  # For tax coverage ratio

  def check(ledger_entry)
    return false unless enabled

    case rule_type
    when "heloc_limit_percentage"
      (ledger_entry.heloc_balance_end / @loan_strategy.heloc.credit_limit) >= threshold_value
    when "heloc_balance_threshold"
      ledger_entry.heloc_balance_end >= threshold_value
    when "primary_paid_off"
      ledger_entry.primary_balance_end <= 0
    when "tax_coverage_ratio"
      check_tax_coverage(ledger_entry)
    end
  end

  private

  def check_tax_coverage(entry)
    # Check if tax refund < (threshold_value × HELOC interest)
    # for consecutive_months in a row
  end
end
```

**UI**:
- Checklist of auto-stop rules with enable/disable toggles
- Threshold input fields
- Visual indicator when a rule is triggered in simulation
- Explanation tooltip: "Why this rule matters for your situation"

---

### 2.3 CRA Audit Trail Compliance 🇨🇦

**Critical Requirement for Canadian Users**: Money flows must be traceable for CRA audit.

**Best Practice Flow** (per CRA requirements) 🇨🇦:
```
Rental Income Flow:
  Tenant → Monika CIBC Account (net $1,805 = $1,900 - $95 mgmt fee)
    → Monika adds personal $95
    → BMO Joint Account ($1,900 total)
    → Primary mortgage prepayment

HELOC Flow:
  HELOC → Rental mortgage payment
  HELOC → Rental operating expenses
  (All HELOC draws are for rental expenses → deductible per CRA)

HELOC Interest Payment:
  BMO Joint Account → HELOC interest (paid monthly, not capitalized)
  (Keeps clean separation: HELOC balance = rental expenses only)
```

**Rails Implementation**:
```ruby
# app/models/debt_optimization_strategy/audit_trail.rb 🇨🇦
class DebtOptimizationStrategy::AuditTrail
  # Generate tax authority report (CRA for Canada)
  def generate_annual_report(year)
    {
      taxpayer: @strategy.tax_owner,
      year: year,
      tax_authority: @strategy.jurisdiction.tax_calculator_config.authority_name,  # "CRA" for Canada

      rental_income: {
        gross_rental_income: ledger_entries.sum(:gross_rental_income),
        property_management_fees: ledger_entries.sum(:property_mgmt_fee),
        net_rental_income: ledger_entries.sum(:net_rental_income)
      },

      rental_expenses: {
        mortgage_interest: calculate_rental_mortgage_interest,
        operating_expenses: ledger_entries.sum(:rental_operating_expenses),
        heloc_interest_deductible: ledger_entries.sum(:deductible_interest),
        total_deductible: calculate_total_deductible
      },

      heloc_usage: {
        beginning_balance: ledger_entries.first.heloc_balance_start,
        ending_balance: ledger_entries.last.heloc_balance_end,
        total_draws: ledger_entries.sum(:heloc_draw),
        purpose: "Rental property expenses (100% business use)",  # CRA requirement
        proof_of_business_use: generate_purpose_breakdown
      },

      tax_impact: {
        total_deductible_interest: ledger_entries.sum(:deductible_interest),
        marginal_tax_rate: @strategy.marginal_tax_rate,
        estimated_tax_benefit: calculate_tax_benefit,
        tax_bracket: determine_tax_bracket
      }
    }
  end
end

# View: PDF report generator 🇨🇦
class DebtOptimizationReportPdf < Prawn::Document
  # Generate PDF with all flows, suitable for CRA review
  # Include: month-by-month ledger, annual summaries, account flow diagram
end
```

**UI Features** 🇨🇦:
- "Download Tax Report" button → PDF with all deductible interest by year (CRA format)
- Flow diagram showing money movement between accounts
- Color-coded: Blue (income), Green (deductible per CRA), Red (non-deductible per CRA)

**Future Enhancement: Multi-Jurisdiction Compliance** 🔧

```ruby
# US IRS compliance (future) 🇺🇸
# - Form 1098 reporting for mortgage interest
# - HELOC interest deductibility capped at $100K
# - Different tracking requirements

# UK HMRC compliance (future) 🇬🇧
# - Offset mortgage reporting
# - Different rental income treatment
# - Different reporting requirements
```

---

### 2.4 Integration with Existing Maybe Finance Models

**Map Debt Optimization Concepts → Maybe Models**:

```ruby
# Existing Maybe models to leverage
Account (type: Loan)
  → Primary Mortgage (non-deductible in Canada, deductible in US)
  → Rental Mortgage (deductible)
  → HELOC (mixed deductibility - track usage)

Account (type: Property)
  → Rental Property
  → Has associated rental income transactions

Transaction
  → Rental income deposits
  → Mortgage payments
  → HELOC draws
  → Tag with "tax_deductible" flag

# New models needed 🔧
DebtOptimizationStrategy (orchestrates multiple accounts, jurisdiction-aware)
DebtOptimizationLedgerEntry (month-by-month simulation)
DebtOptimizationStrategy::AutoStopRule
DebtOptimizationStrategy::AuditTrail
```

**Example Flow** (Canadian):
```ruby
# User creates a debt optimization strategy 🇨🇦
strategy = DebtOptimizationStrategy.create!(
  family: current_family,
  jurisdiction: Jurisdiction.find_by(country_code: 'CA'),
  strategy_type: :modified_smith,  # Canadian strategy
  primary_mortgage: primary_mortgage_account,
  heloc: heloc_account,
  rental_mortgage: rental_mortgage_account,
  rental_income_monthly: 1900,
  rental_expenses_monthly: 797,
  ...
)

# Run simulation (uses Canadian simulator)
results = strategy.simulate(months: 360)  # 30 years

# Save results
results[:month_by_month].each do |month_data|
  DebtOptimizationLedgerEntry.create!(
    debt_optimization_strategy: strategy,
    month_number: month_data[:month],
    ...
  )
end

# Display comparison charts
@chart_data = DebtOptimizationStrategy::ChartSeriesBuilder.new(strategy).build_all_charts

# User approves strategy → create recurring transactions
strategy.implement! do
  # Creates scheduled transactions:
  # 1. Monthly rental income → primary mortgage
  # 2. Monthly HELOC draw → rental expenses
  # 3. Monthly HELOC interest payment
end
```

---

## Part 3: Shared Design Principles

### 3.1 Architecture Patterns

#### Pattern 1: Calculator Classes for Complex Math 🌍
**When to use**: Any calculation with >10 lines of logic

**Structure**:
```ruby
# app/calculators/[domain]_calculator.rb
class ProjectionCalculator
  def initialize(account, assumptions:)
    @account = account
    @assumptions = assumptions
  end

  def calculate
    # Pure calculation logic
    # No side effects (database writes, API calls)
    # Return value object or hash
  end

  private

  def compound_growth(principal:, rate:, periods:)
    # Helper methods
  end
end
```

**Benefits**:
- Testable (no dependencies)
- Reusable (can call from jobs, controllers, rake tasks)
- Clear responsibility (just math, no orchestration)

---

#### Pattern 2: Service Objects for Orchestration 🌍
**When to use**: Multi-step processes with side effects

**Structure**:
```ruby
# app/services/[domain]/[action]_service.rb
class Portfolio::RebalanceService
  def initialize(account, strategy:)
    @account = account
    @strategy = strategy
  end

  def call
    # 1. Calculate target allocation
    target = calculate_target_allocation

    # 2. Determine trades needed
    trades = determine_rebalancing_trades(target)

    # 3. Estimate costs
    costs = estimate_transaction_costs(trades)

    # 4. Create trade entries
    create_trade_entries(trades) if @strategy.execute?

    # 5. Update holdings
    @account.sync!

    # Return result
    Result.new(trades: trades, costs: costs, ...)
  end
end
```

**Benefits**:
- Single entry point (call method)
- Handles errors and edge cases
- Can be wrapped in transactions
- Easy to test with mocks

---

#### Pattern 3: Concern Modules for Shared Behavior 🌍
**When to use**: Multiple models need same behavior

**Example**:
```ruby
# app/models/concerns/projectable.rb
module Projectable
  extend ActiveSupport::Concern

  included do
    has_many :projections, as: :projectable, dependent: :destroy
    has_many :milestones, as: :projectable
  end

  def current_projection(years: 30)
    ProjectionCalculator.new(self).calculate(years: years)
  end

  def forecast_accuracy
    ForecastAccuracyCalculator.new(self.projections).calculate
  end
end

# Use in multiple models
class Account
  include Projectable
end

class Family
  include Projectable  # Whole-family projections
end
```

---

#### Pattern 4: ViewComponents for Reusable UI 🌍
**When to use**: UI element used in >2 places OR has complex logic

**Investment Dashboard Example**:
```ruby
# app/components/projection_chart_component.rb
class ProjectionChartComponent < ViewComponent::Base
  def initialize(account:, projection:, show_monte_carlo: false)
    @account = account
    @projection = projection
    @show_monte_carlo = show_monte_carlo
  end

  def chart_data
    {
      labels: @projection.date_labels,
      datasets: build_datasets
    }
  end

  private

  def build_datasets
    datasets = [
      historical_dataset,
      projected_dataset
    ]

    datasets += monte_carlo_datasets if @show_monte_carlo
    datasets
  end
end

# app/components/projection_chart_component.html.erb
<div data-controller="projection-chart">
  <canvas data-projection-chart-target="canvas"
          data-projection-chart-data-value="<%= chart_data.to_json %>">
  </canvas>
</div>
```

**HELOC Tool Example**:
```ruby
# app/components/loan_strategy_comparison_component.rb
class LoanStrategyComparisonComponent < ViewComponent::Base
  def initialize(baseline:, modified:)
    @baseline = baseline
    @modified = modified
  end

  def total_interest_saved
    @baseline.total_interest - @modified.total_interest
  end

  def tax_benefit
    @modified.cumulative_tax_refund
  end

  def net_savings
    total_interest_saved + tax_benefit
  end
end
```

---

### 3.2 Data Quality & Validation 🌍

**Philosophy**: *"Trust, but verify. Warn loudly, fail gracefully."*

#### Validation Levels

**Level 1: Database Constraints**
```ruby
# migration
create_table :projections do |t|
  t.decimal :expected_return, null: false
  t.decimal :volatility, null: false
  t.check_constraint "expected_return >= 0 AND expected_return <= 1", name: "return_bounds"
  t.check_constraint "volatility >= 0 AND volatility <= 2", name: "volatility_bounds"
end
```

**Level 2: Model Validations**
```ruby
class Projection < ApplicationRecord
  validates :expected_return, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 1,
    message: "must be between 0% and 100%"
  }

  validates :volatility, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 2,
    message: "must be between 0% and 200%"
  }

  validate :realistic_assumptions

  private

  def realistic_assumptions
    # Warn if assumptions are unusual (but don't fail)
    if expected_return > 0.20
      errors.add(:expected_return, "is unusually high (>20%/year). Are you sure?")
    end

    if volatility > 0.50
      errors.add(:volatility, "is very high (>50%). Consider using lower volatility assets.")
    end
  end
end
```

**Level 3: Data Quality Warnings** (Investment Dashboard Pattern)
```ruby
# app/models/concerns/data_quality_checkable.rb
module DataQualityCheckable
  def data_quality_issues
    issues = []

    # Check 1: Negative contributions (withdrawals)
    if inferred_contributions.any? { |c| c < 0 }
      issues << {
        severity: :warning,
        type: :negative_contributions,
        message: "Detected withdrawals in contribution history",
        recommendation: "Ensure CSV data is correct. Withdrawals affect projection accuracy."
      }
    end

    # Check 2: Extremely high values
    if inferred_contributions.any? { |c| c > monthly_income * 2 }
      issues << {
        severity: :error,
        type: :unrealistic_contribution,
        message: "Contribution exceeds 2× monthly income",
        recommendation: "This may be a data entry error. Please review."
      }
    end

    # Check 3: Long gaps without contributions
    gaps = detect_contribution_gaps
    if gaps.any? { |gap| gap > 6 }
      issues << {
        severity: :info,
        type: :contribution_gap,
        message: "Detected #{gaps.max}-month gap in contributions",
        recommendation: "This is normal if you paused investing. Projections account for this."
      }
    end

    issues
  end
end
```

**UI Display**:
```erb
<% if @account.data_quality_issues.any? %>
  <div class="alert-container">
    <% @account.data_quality_issues.each do |issue| %>
      <%= render(AlertComponent.new(
        severity: issue[:severity],
        title: issue[:message],
        description: issue[:recommendation]
      )) %>
    <% end %>
  </div>
<% end %>
```

---

### 3.3 Testing Strategy 🌍

**Philosophy**: *"Test the critical paths that give confidence, not coverage for coverage's sake"*

#### What to Test

**✅ DO Test**:
1. **Financial Calculations**:
   ```ruby
   test "compound interest calculation matches formula" do
     calc = ProjectionCalculator.new(principal: 1000, rate: 0.08, years: 10)
     expected = 1000 * (1.08 ** 10)
     assert_in_delta expected, calc.future_value, 0.01
   end
   ```

2. **Edge Cases**:
   ```ruby
   test "handles zero balance gracefully" do
     account = accounts(:empty_account)
     projection = account.current_projection
     assert_equal 0, projection.starting_value
     assert projection.valid?
   end
   ```

3. **Business Logic**:
   ```ruby
   test "modified strategy stops when HELOC reaches limit" do
     strategy = loan_strategies(:near_limit)
     strategy.auto_stop_heloc_percentage = 0.90

     result = strategy.simulate(months: 12)
     assert result[:stopped?]
     assert_equal "HELOC limit reached", result[:stop_reason]
   end
   ```

4. **Data Transformations**:
   ```ruby
   test "CSV import creates correct holdings" do
     csv_file = fixture_file_upload('wealthsimple.csv', 'text/csv')

     assert_difference 'Holding.count', 3 do
       Holdings::ImportService.new(account, csv_file).call
     end

     assert_equal 10.5, account.holdings.find_by(ticker: 'AAPL').qty
   end
   ```

**❌ DON'T Test**:
1. Framework behavior (ActiveRecord validations work)
2. Third-party libraries (NumPy is tested by NumPy team)
3. Trivial getters/setters
4. Private methods (test through public interface)

#### Test Structure

**Use Fixtures** (per Maybe Finance conventions):
```ruby
# test/fixtures/accounts.yml
investment_account:
  accountable: vanguard (Investment)
  balance: 50000
  currency: USD
  status: active

# test/fixtures/projections.yml
ten_year_projection:
  account: investment_account
  years: 10
  expected_return: 0.08
  volatility: 0.15
  simulations: 100
```

**Test Pattern**:
```ruby
class ProjectionTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:investment_account)
    @projection = projections(:ten_year_projection)
  end

  test "calculates final value correctly" do
    result = @projection.calculate
    assert result.final_value > @account.balance  # Should grow
    assert result.final_value < @account.balance * 3  # But not unrealistically
  end

  test "generates monthly series" do
    result = @projection.calculate
    assert_equal 120, result.monthly_values.length  # 10 years × 12 months
  end
end
```

---

### 3.4 Performance Budget 🌍

**Target Response Times**:
- Page load (no Monte Carlo): **< 500ms**
- Deterministic projection calculation: **< 200ms**
- Monte Carlo simulation (300 runs): **< 2 seconds** (background job acceptable)
- Chart rendering: **< 100ms**
- CSV import: **< 1 second** for 100 rows

**Optimization Checklist**:
- [ ] Cache expensive calculations with smart cache keys
- [ ] Use background jobs for >1 second operations
- [ ] Lazy load Monte Carlo (don't run on initial page load)
- [ ] Database indexes on foreign keys and query columns
- [ ] N+1 query prevention (use `includes`)
- [ ] Batch database operations
- [ ] Progressive enhancement (show basic first, enhance with JS)

---

#### Pattern 5: Jurisdiction Configuration Pattern 🔧

**When to use**: Features with country-specific rules (tax, compliance, reporting)

**Structure**:
```ruby
# Leverage existing Provider pattern (already in Maybe Finance)
# Jurisdiction acts like a "provider" for tax/compliance rules
class Jurisdiction < ApplicationRecord
  has_many :projection_standards
  has_one :tax_calculator_config

  def available_strategies
    # Return strategies applicable to this jurisdiction
    case country_code
    when 'CA'
      [:modified_smith, :baseline]
    when 'US'
      [:heloc_arbitrage, :baseline]  # Future
    when 'GB'
      [:offset_mortgage, :baseline]  # Future
    end
  end
end
```

**Benefits**:
- Configuration over code
- Add countries without code changes
- Aligns with existing Provider pattern
- Jurisdiction defaults to Canada (primary market)

**Example**:
```ruby
# Canadian user (default)
strategy = DebtOptimizationStrategy.new(family: current_family)
strategy.jurisdiction  # => Canada (default)
strategy.available_strategies  # => [:modified_smith, :baseline]

# Future: US user
us_family.jurisdiction = Jurisdiction.find_by(country_code: 'US')
strategy = DebtOptimizationStrategy.new(family: us_family)
strategy.available_strategies  # => [:heloc_arbitrage, :baseline]
```

---

## Part 4: Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)
**Goal**: Database schema and core models

**Tasks**:
1. Create migration for new tables:
   - `jurisdictions` 🔧 (country registry)
   - `tax_calculator_configs` 🔧 (jurisdiction-specific tax rules)
   - `projection_standards` 🔧 (PAG 2025, CFP Board, etc.)
   - `projections` (stores projection scenarios)
   - `projection_results` (stores calculated results)
   - `milestones` (financial goals)
   - `projection_assumptions` (asset class assumptions)
   - `debt_optimization_strategies` (debt simulator scenarios, jurisdiction-aware)
   - `debt_optimization_ledger_entries` (month-by-month results)

2. Create core models:
   - `Jurisdiction`, `TaxCalculatorConfig`, `ProjectionStandard` 🔧
   - `Projection`, `ProjectionResult`, `Milestone`
   - `ProjectionAssumption` linked to `ProjectionStandard`
   - `DebtOptimizationStrategy`, `DebtOptimizationLedgerEntry`

3. Add concerns:
   - `JurisdictionAware` 🔧 (for jurisdiction-specific behavior)
   - `Projectable` (for Account and Family models)
   - `PagCompliant` 🇨🇦 (for PAG assumption management)
   - `DataQualityCheckable` (for validation warnings)

4. Write model tests with fixtures

**Validation**: Run `bin/rails test` - all model tests pass

---

### Phase 2: Calculations (Weeks 3-4)
**Goal**: Core calculation engines working

**Tasks**:
1. Build calculators:
   - `ProjectionCalculator` (deterministic projections)
   - `ForecastAccuracyCalculator` (MAPE, RMSE, etc.)
   - `MilestoneCalculator` (goal timeline projections)
   - `CanadianSmithManoeuvrSimulator` 🇨🇦 (Canadian debt optimization)
   - `BaselineSimulator` 🌍 (universal baseline strategy)

2. Decide on Monte Carlo approach:
   - Option A: Ruby with numo-narray (slower, simpler deployment)
   - Option B: Python microservice (faster, more complex)
   - Option C: Pre-computed scenarios (fastest, less flexible)

3. Implement provider extensions:
   - Add `MarketDataConcept` to Provider pattern
   - Integrate Yahoo Finance or extend Synth provider
   - Add volatility and correlation fetching

4. Write calculator tests

**Validation**: Run sample projections, verify math against Excel

---

### Phase 3: UI Components (Weeks 5-6)
**Goal**: User-facing features in working state

**Tasks**:
1. Build ViewComponents:
   - `ProjectionChartComponent` (time series with Monte Carlo bands) - ⏳ Pending
   - `UI::Account::MilestoneTrackerComponent` (goal progress display) - ✅ **Complete**
   - `UI::Account::MilestoneCardComponent` (individual milestone with progress bar) - ✅ **Complete**
   - `DebtOptimizationComparisonComponent` (baseline vs optimized) - ⏳ Pending
   - `DataQualityAlertComponent` (warnings) - ⏳ Pending

2. Extend Stimulus controllers:
   - Enhance `time_series_chart_controller.js` for projection charts
   - Add `projection_settings_controller.js` (interactive settings)
   - Add `debt_optimizer_controller.js` (debt optimization interface)

3. Create routes and controllers:
   - `AccountProjectionsController` (CRUD for projections) - ⏳ Pending
   - `MilestonesController` (goal management) - ✅ **Complete** (nested under accounts)
   - `DebtOptimizationStrategiesController` (debt optimization simulator) - ⏳ Pending

4. Build views using Hotwire pattern

**Validation**: Manual UI testing, screenshot review

---

### Phase 4: Integration & Polish (Weeks 7-8)
**Goal**: Production-ready features

**Tasks**:
1. Background job setup:
   - `CalculateProjectionJob` (async Monte Carlo)
   - `SyncAssumptionsJob` (fetch latest PAG data if available)
   - Turbo Stream broadcasts for live updates

2. CSV import enhancement:
   - Add projection recalculation after import
   - Show data quality warnings
   - Auto-enrich new tickers

3. Settings UI:
   - PAG compliance toggle
   - Assumption overrides
   - Rebalancing strategy configuration
   - HELOC simulator settings

4. Documentation:
   - User guide (how to use projections)
   - Methodology page (explain PAG, Monte Carlo)
   - API docs (if exposing via API)

5. Performance optimization:
   - Add caching with cache keys
   - Database indexes
   - Query optimization
   - Load testing

**Validation**:
- Run full test suite: `bin/rails test`
- Manual QA: test all user flows
- Performance: measure response times
- Security: run `bin/brakeman`

---

### Phase 5: Advanced Features (Weeks 9-12)
**Goal**: Power user features

**Tasks**:
1. Tax optimization:
   - Tax-lot tracking for capital gains
   - Tax-loss harvesting recommendations
   - RMD calculator (required minimum distributions)

2. Portfolio optimization:
   - Modern Portfolio Theory (efficient frontier)
   - Rebalancing recommendations
   - Asset correlation analysis

3. Reporting:
   - PDF export for projections (use Prawn gem)
   - CRA-ready tax reports 🇨🇦 for debt optimization strategies
   - Annual portfolio review generator

4. API exposure:
   - Add projections to `/api/v1/` namespace
   - OAuth scopes for projection access
   - Webhook notifications for milestone achievements

**Validation**:
- Beta testing with real users
- Gather feedback
- Iterate on UX

---

## Part 5: Key Decisions Summary

These architectural decisions have been finalized:

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Monte Carlo** | Pure Ruby (Box-Muller) | Simpler deployment, acceptable performance for 1000 simulations |
| **PAG Assumptions** | Database with Seed Data | Version tracking, user overrides, auditable updates |
| **Chart Library** | Extend D3.js | Consistent with existing charts, no new dependencies |
| **Debt Simulator** | Port to Rails + ViewComponents | Native UX, integrates with Account/Loan models |
| **Multi-Jurisdiction** | Built-in from day 1 | No refactoring needed for US/UK expansion |

**Implementation References:**
- Monte Carlo: `app/calculators/projection_calculator.rb` (Box-Muller transform)
- PAG Assumptions: `db/seeds/projection_standards.rb`
- Charts: Extend `app/javascript/controllers/time_series_chart_controller.js`
- Jurisdiction: `app/models/jurisdiction.rb`, `app/models/concerns/jurisdiction_aware.rb`

---

## Part 6: Reference Checklist

**Use this checklist when making design decisions:**

### ✅ Architecture
- [ ] Does this follow "skinny controllers, fat models" pattern?
- [ ] Is business logic in models/concerns, not controllers?
- [ ] Are calculations in Calculator classes (>10 lines)?
- [ ] Are multi-step processes in Service objects?
- [ ] Is this a reusable ViewComponent (used >2 times or complex)?
- [ ] Does this feature support multiple jurisdictions (if tax/compliance-related)? 🔧
- [ ] Are jurisdiction-specific rules in database (not hardcoded)? 🔧
- [ ] Can new countries be added via seed data (not code changes)? 🔧

### ✅ Financial Accuracy
- [ ] Are projections realistic (not overly optimistic)?
- [ ] Is inflation considered for long-term projections?
- [ ] Are fees/costs included in calculations?
- [ ] Does it handle edge cases (zero balance, negative returns)?
- [ ] Is PAG compliance optional but encouraged?

### ✅ Data Quality
- [ ] Are there database constraints for critical fields?
- [ ] Are there model validations with helpful messages?
- [ ] Are there data quality warnings (not hard errors)?
- [ ] Is user input validated before expensive calculations?

### ✅ Performance
- [ ] Are expensive calculations cached?
- [ ] Do long-running operations use background jobs?
- [ ] Is Monte Carlo lazy-loaded (not on initial page load)?
- [ ] Are database queries optimized (no N+1)?
- [ ] Are response times measured?

### ✅ Testing
- [ ] Are financial calculations tested with known values?
- [ ] Are edge cases covered?
- [ ] Are business logic paths tested?
- [ ] Are fixtures used (not factories)?
- [ ] Is test coverage focused (critical paths, not 100%)?

### ✅ UX/UI
- [ ] Is uncertainty communicated clearly (ranges, not false precision)?
- [ ] Are warnings prominent but not blocking?
- [ ] Is the UI progressive (basic first, enhanced with JS)?
- [ ] Are charts interactive and responsive?
- [ ] Is loading state shown for async operations?

### ✅ Rails Conventions (CLAUDE.md)
- [ ] Does this push Rails to its limits before adding dependencies?
- [ ] Is it Hotwire-first (server-driven, not client-heavy)?
- [ ] Does it use native HTML where possible?
- [ ] Is it optimized for simplicity, not premature optimization?
- [ ] Does it follow the provider pattern for external data?

---

## Part 7: Success Metrics

**How will we know this integration is successful?**

### User Metrics
- [ ] Users create at least 1 projection within first week
- [ ] >50% of users with investment accounts use milestone tracking
- [ ] Users run HELOC simulator before making debt decisions
- [ ] Projection accuracy improves over time (lower MAPE as more data collected)

### Technical Metrics
- [ ] Projection calculations: <500ms (deterministic), <2s (Monte Carlo)
- [ ] CSV import with 100 holdings: <1 second
- [ ] Chart rendering: <100ms
- [ ] Database queries: No N+1, all <100ms
- [ ] Test coverage: >80% for calculators and critical business logic

### Quality Metrics
- [ ] Zero data loss incidents
- [ ] <1% of users report "inaccurate projections"
- [ ] All financial calculations validated against Excel/external tools
- [ ] PAG assumptions match official FP Canada documentation
- [ ] CRA audit trail compliance verified by accountant

---

## Part 8: Adding New Jurisdictions 🔧

Add support for a new country without modifying core application code.

### Implementation Checklist

| Step | Files to Create | Purpose |
|------|-----------------|---------|
| 1 | `db/seeds/<country>_jurisdiction.rb` | Jurisdiction record (country_code, name, settings) |
| 2 | `db/seeds/<country>_projection_standards.rb` | Projection assumptions (e.g., CFP Board for US) |
| 3 | `db/seeds/<country>_tax_config.rb` | Tax brackets and deductibility rules |
| 4 | `app/services/<country>_<strategy>_simulator.rb` | Strategy simulator (if different from Canadian) |
| 5 | `app/views/tax_reports/<form>.pdf.erb` | Compliance report template |

### Key Differences by Country

| Aspect | 🇨🇦 Canada | 🇺🇸 US | 🇬🇧 UK |
|--------|----------|------|------|
| Tax Authority | CRA | IRS | HMRC |
| Primary mortgage interest deductible | No | Yes | No (since 2020) |
| Rental mortgage interest deductible | No | Yes | No |
| Investment-purpose HELOC interest | Yes | Yes (up to $100K) | Offset mortgage |
| Projection Standard | PAG 2025 | CFP Board | FCA Guidelines |
| Purpose tracking required | Yes (CRA strict) | No | Yes |

### Architectural Benefits

- **Canadian users**: Jurisdiction invisible, defaults to Canada with PAG 2025 and CRA compliance
- **Future expansion**: Add new jurisdiction with seed files + simulator class - no core model changes
- **Maintainability**: Tax rules versioned in database, easy to update when regulations change

**Reference**: See `db/seeds/jurisdictions.rb` and `db/seeds/projection_standards.rb` for Canadian implementation.

---

## Conclusion

This document serves as the **authoritative design reference** for integrating sophisticated financial planning features into Maybe Finance. The key principles are:

1. **Adaptive, not naive** 🌍 - Learn from actual history, don't assume perfection
2. **Probabilistic, not deterministic** 🌍 - Show ranges, not false precision
3. **Professional-grade** 🇨🇦 - PAG 2025 compliant, CRA audit-ready
4. **Rails-first** 🌍 - Leverage existing patterns, extend don't replace
5. **User-focused** 🌍 - Simple for users, sophisticated under the hood
6. **Canadian-first, globally-extensible** 🔧 - Build for Canada, architect for expansion

**When in doubt, refer back to:**
- **Part 0**: Multi-Jurisdiction Architecture Philosophy 🔧
- **Part 1**: Investment Dashboard principles (adaptive projections, Monte Carlo, PAG compliance) 🇨🇦 + 🌍
- **Part 2**: Tax-Optimized Debt Strategies (Smith Manoeuvre, cash flow modeling, CRA audit trail) 🇨🇦
- **Part 8**: Adding New Jurisdictions (blueprint for US/UK/EU expansion) 🔧
- **Maybe Finance conventions** (skinny controllers, Hotwire-first, concerns over services, Provider pattern)

**Architecture Summary:**

This design achieves **80% Canadian focus** while maintaining **100% architectural readiness** for global expansion:

- **Canadian users** get a polished, feature-complete experience with PAG 2025 and CRA compliance
- **Developers** work with clear patterns: universal concepts (🌍), Canadian implementations (🇨🇦), and extensibility hooks (🔧)
- **Future expansion** requires only seed data + simulators, no refactoring

**Next Steps:** See `docs/FEATURE_ROADMAP.md` for the current feature roadmap and sprint planning priorities.

---

**Document Version**: 2.4
**Last Updated**: 2026-02-16
**Major Changes**:
- v2.4: Symmetrized Plaid/SnapTrade provider descriptions — both now have account selection/review flow
- v2.3: Updated Part 1.3 with SnapTrade brokerage integration and provider routing
- v2.2: **Phase 3 Complete** - Canadian Modified Smith Manoeuvre fully implemented
- v2.2: Added debt optimization models, simulators, UI components, and tests (61 new tests)
- v2.2: Updated implementation status table with Phase 3 completion
- v2.2: Updated next steps to reflect Phase 4+ priorities
- v2.1: Updated implementation status - Phase 1 & 2 complete, deployed with test data
- v2.1: Added performance optimization notes (pre-stored projections vs live Monte Carlo)
- v2.1: Updated next steps to reflect Phase 3+ priorities
- v2.0: Added Part 0: Multi-Jurisdiction Architecture Philosophy
- v2.0: Restructured Part 1 Feature 3 with jurisdiction support
- v2.0: Renamed Part 2 to "Tax-Optimized Debt Strategies" with jurisdiction patterns
- v2.0: Added Part 8: Adding New Jurisdictions guide
- v2.0: Introduced visual markers (🇨🇦 🌍 🔧 🇺🇸 🇬🇧)
- v2.0: Renamed models: `LoanStrategy` → `DebtOptimizationStrategy` (jurisdiction-aware)

**Author**: Design vision compiled from investment dashboard, HELOC tool, and Maybe Finance architecture analysis, restructured for multi-jurisdiction support while maintaining Canadian focus
