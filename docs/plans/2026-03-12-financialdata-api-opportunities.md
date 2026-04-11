# FinancialData API — Opportunity Areas

*Identified during troubleshooting of the symbol sync pagination bug (2026-03-12)*

## Context

ROMS Finance uses [financialdata.net](https://financialdata.net) as its primary market data provider (Standard tier). During investigation of the equity compensation search bug (US securities missing due to `page` vs `offset` pagination), we audited the full API surface and identified four opportunity areas that could enrich the product without adding new provider dependencies.

All opportunities below are **supplemental** to Plaid and SnapTrade — they enhance display and analytics, not replace transactional data sources.

---

## API Audit Findings

### Current Usage

| Endpoint | Purpose | Correct? |
|---|---|---|
| `stock-prices` | US historical prices | Yes |
| `international-stock-prices` | TSX/LSE prices | Yes |
| `crypto-prices` | BTC, ETH, etc. | Yes |
| `company-information` | US company details | Yes |
| `international-company-information` | TSX/LSE company details | Yes |
| `stock-symbols` | US symbol cache | **Fixed** — was sending `page`, now sends `offset` |
| `etf-symbols` | ETF symbol cache | **Fixed** — same pagination bug |
| `international-stock-symbols` | Intl symbol cache | **Fixed** — same pagination bug |

### `usage` Method

The `usage` method in `Provider::FinancialData` currently hardcodes `plan: "free"` and `limit: 300`. This should be updated to reflect Standard tier limits. The FinancialData API does not expose a usage/quota endpoint, so the values must be configured manually. Standard tier allows 5,000 requests/day.

```ruby
# Current (line 37-46)
def usage
  with_provider_response do
    UsageData.new(used: nil, limit: 300, utilization: nil, plan: "free")
  end
end

# Suggested
def usage
  with_provider_response do
    UsageData.new(used: nil, limit: 5000, utilization: nil, plan: "standard")
  end
end
```

---

## Opportunity 1: Richer Security Details

### What's Available

The `key-metrics` endpoint (Standard tier) returns fundamental data per security:

- P/E ratio (trailing and forward)
- EPS (earnings per share)
- Dividend yield
- Market capitalization
- 52-week high/low
- Revenue, profit margins
- Book value, price-to-book

### What We Currently Have vs What's New

| Data | Current Source | New |
|---|---|---|
| Price history | `stock-prices` | — |
| Company name, description | `company-information` | — |
| Logo | Clearbit via company website | — |
| P/E, EPS, dividend yield | **None** | `key-metrics` |
| Market cap | **None** | `key-metrics` |
| 52-week range | Derivable from price history | Direct from `key-metrics` |

### Integration Approach

Add a `fetch_security_metrics` method to `Provider::FinancialData` that returns a new `SecurityMetrics` struct. Display on security detail pages and holding cards. Cache aggressively (metrics change daily at most).

### Key Files

- `app/models/provider/financial_data.rb` — new `fetch_security_metrics` method
- `app/models/security.rb` — add `metrics` association or cached method
- `app/views/holdings/` — display P/E, dividend yield, market cap
- `app/components/` — new `SecurityMetricsComponent`

### Complexity

**Low-Medium.** Single new endpoint call + UI display. No schema changes needed if metrics are cached (Rails.cache) rather than persisted.

---

## Opportunity 2: Index Benchmarking

### What's Available

Two endpoints enable portfolio-vs-benchmark comparison:

- `index-prices` — historical prices for major indices (S&P 500, TSX Composite, FTSE 100, etc.)
- `index-constituents` — list of securities in each index (useful for "your overlap with S&P 500")

### What We Currently Have vs What's New

| Data | Current Source | New |
|---|---|---|
| Portfolio return over time | Calculated from holdings + prices | — |
| Benchmark index prices | **None** | `index-prices` |
| Index constituents | **None** | `index-constituents` |
| Portfolio vs benchmark chart | **None** | Derived from above |

### Integration Approach

1. Allow users to select a benchmark index per investment account (or family-wide default)
2. Fetch index price history alongside portfolio value history
3. Render comparison chart using existing D3.js infrastructure
4. Optionally show "holdings overlap" with index constituents

### Key Files

- `app/models/provider/financial_data.rb` — `fetch_index_prices`, `fetch_index_constituents`
- `app/models/account/investment.rb` — `benchmark_index` attribute
- `app/calculators/` — new `BenchmarkComparisonCalculator`
- `app/views/investments/` or `app/components/` — comparison chart
- `db/migrate/` — add `benchmark_index` column to accounts or investment accountable

### Complexity

**Medium.** New data model for benchmark selection, new calculator for relative returns, new chart component. The index price fetching itself is straightforward.

---

## Opportunity 3: Dividend Tracking

### What's Available

Dividend data comes from two complementary sources:

1. **FinancialData `key-metrics`** — current dividend yield (annual %)
2. **Plaid/SnapTrade transactions** — actual dividend payment transactions already flowing into the system

### What We Currently Have vs What's New

| Data | Current Source | New |
|---|---|---|
| Dividend transactions | Plaid/SnapTrade (if connected) | Already available, needs tagging |
| Dividend yield (annual %) | **None** | `key-metrics` |
| Projected annual income | **None** | Derived from yield × holdings |
| Dividend history per holding | **None** | Filter existing transactions by category |

### Integration Approach

1. Tag dividend transactions from Plaid/SnapTrade using existing transaction categorization
2. Pull dividend yield from `key-metrics` (same call as Opportunity 1)
3. Calculate projected annual dividend income: `sum(holding_value × dividend_yield)` per account
4. Display on investment dashboard: actual received (from transactions) + projected (from yield)

### Key Files

- `app/models/holding.rb` — `projected_dividend_income` method
- `app/models/account/investment.rb` — `total_dividend_income`, `projected_dividend_income`
- Transaction categorization rules — identify dividend transactions
- `app/views/investments/` — dividend income summary section

### Complexity

**Low.** Dividend yield piggybacks on Opportunity 1's `key-metrics` call. Transaction tagging may already partially exist. The main work is UI presentation.

---

## Opportunity 4: Smarter Predictions

### What's Available

No new API calls needed — this uses **existing historical price data** already fetched via `stock-prices` and `international-stock-prices`.

### What We Currently Have vs What's New

| Data | Current Source | New |
|---|---|---|
| PAG 2025 asset class returns | Hardcoded constants | — |
| Per-security historical volatility | **None** | Derived from price history |
| Per-security annualized return | **None** | Derived from price history |
| Correlation between holdings | **None** | Derived from price history |

### Integration Approach

Currently, `ProjectionCalculator` uses PAG 2025 blended return assumptions (equity 6.28%, fixed 4.09%). With historical price data already in the system, we could:

1. Calculate per-security annualized return and volatility from stored prices
2. Use actual portfolio composition for weighted return/volatility instead of generic asset class assumptions
3. Improve the correlation matrix (currently hardcoded rho=0.8 same-class, 0.3 cross-class) with empirical correlations
4. Keep PAG 2025 as the default/fallback; offer "historical" as an alternative projection mode

### Key Files

- `app/calculators/projection_calculator.rb` — accept per-security return overrides
- `app/calculators/` — new `SecurityStatisticsCalculator` (return, volatility, correlation from price series)
- `app/models/concerns/projectable.rb` — toggle between PAG and historical modes
- `app/models/projection_assumption.rb` — store computed per-security assumptions

### Complexity

**Medium-High.** The math (log returns, rolling volatility, correlation matrix) is well-defined but needs careful validation against PAG 2025 baselines. Must not break existing projection tests or PAG compliance.

---

## Priority Recommendation

| # | Opportunity | Effort | Value | Suggested Order |
|---|---|---|---|---|
| 1 | Richer Security Details | Low-Medium | High (visible to all users) | First |
| 3 | Dividend Tracking | Low | Medium (investment users) | Second (shares API call with #1) |
| 2 | Index Benchmarking | Medium | High (investment users) | Third |
| 4 | Smarter Predictions | Medium-High | Medium (accuracy improvement) | Fourth (depends on price data coverage) |

Opportunities 1 and 3 share the same `key-metrics` API call and should be implemented together.
