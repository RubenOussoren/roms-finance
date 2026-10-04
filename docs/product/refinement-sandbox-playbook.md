# Product refinement — synthetic sandbox playbook

**Status:** acceptance/discovery scenarios, not executed results\
**Audit date/baseline:** 2026-10-04 / `9477538732da1acf7d52720f358ea27b66777134`\
**Work item:** [#121](https://github.com/RubenOussoren/roms-finance/issues/121)\
**Planning context:** [roadmap](refinement-roadmap-2026-10.md) ·
[evidence and issue register](refinement-backlog-2026-10.md)

## Purpose

Observe a user finishing a task, explaining the result and recovering from
mistakes. These scenarios complement regression tests; a passing assertion or
successful HTTP response cannot substitute for an understandable journey.

## Safety preflight — before starting any session

Follow [development workflow](../development/workflow.md) and canonical test/setup
skills. Do not paste a test command into an unverified environment.

- Confirm a **prepared, disposable local/sandbox** app/database and isolated Redis,
  cache, jobs, storage and mail targets. Explicitly inspect effective environment
  precedence without printing secrets. `RAILS_ENV=test` alone is not isolation.
- If setup/service startup/schema/fixture replacement is necessary, request the
  exact target/action authorization first. Never reload production/demo data or
  reset a retained database to make these scenarios work.
- Use fictional families/users/account labels; no real credentials or customer
  data. Providers and outbound email/payment/market/banking/LLM calls are stubbed;
  browser egress is restricted to the approved test app.
- Fix the as-of date and synthetic prices/FX/observations. Record assumption/source
  versions and applicable RNG/seed. Do not use today's live prices as expectations.
- Capture sanitized screenshots, not environment variables, authentication
  headers, financial-provider payloads with real data or session tokens.
- Keep actual UI clicks and provider-stub observations distinct from source-based
  reasoning. A failed environment setup is a blocker, not an application failure.

## Fixture pack to specify before implementation

This document **does not create or load fixtures**. Build the smallest fixture pack
for the selected session; avoid one enormous all-features demo.

| Dimension | Synthetic cases |
| --- | --- |
| Tenancy | Family A with two members; unrelated Family B. |
| Access | Creator/joint/default full, explicit full, balance-only and hidden accounts. |
| Ownership | Explicit 70/30 joint ownership; distinguish ownership from permission. |
| Currencies | CAD reporting currency, CAD/USD accounts, known USD-to-CAD 1.35; separate missing FX case. |
| Equity | RSU and option grants; monthly/quarterly, cliff/no cliff, future-only, partially/fully vested, sold/remaining, terminated/expired and no price. |
| History | Complete monthly observations, sparse history, no history, negative net worth. |
| Forecasts | A run issued before target maturity, later run with changed inputs, missing actual, late observation. |
| Operations | Validation failure, partial stream timeout, duplicate click/job retry, disabled AI, missing provider configuration. |
| Destructive flows | Imported account with imported entries plus a later manual entry; cancel before confirmation. |

## Session protocol

1. Record tested SHA, date, runtime/browser/viewport, fixture pack version and
   verified nonsecret environment description.
2. Give an outcome-oriented prompt, not click-by-click instructions.
3. Let the user attempt it without coaching. Capture time, completion, wrong turns,
   clarification requests, errors and how they recover. Do not invent target times.
4. Ask them to explain key values in their own words. Compare against independent
   calculations and the approved domain contract, not the displayed value itself.
5. Repeat critical flows on mobile and keyboard-only; inspect labels, focus,
   error messages and a table/text alternative for charts.
6. Record before/after evidence per issue. Separate observations from proposed
   design solutions. Discovery can conclude the current flow is adequate.

## Priority scenario matrix

| Task prompt | Independent expectation / observation | Issues |
| --- | --- | --- |
| “Set up this equity grant from your statement.” | Account/grant relationship is clear; 1,000 units, four years, monthly with one-year cliff gives the agreed first-vest quantity/date. User understands inputs and optional fields. No provider/security configuration gives an honest next step. | #123, #126, #129 |
| “How many units are vested before your next anniversary?” | Jan 15 grant: Feb 1 precedes Feb 15 first monthly vest. Next event respects cliff. Check month-end/leap dates separately against approved conventions. | #123 |
| “What are these ten USD options worth in CAD?” | USD market 100, strike 60, FX 1.35 gives CAD 540 intrinsic value. Missing FX is incomplete, not parity. Distinguish exercise cost and gross share proceeds. | #124, #129 |
| “Record a sale and the cash you received.” | 10 RSUs sold at USD 100, USD 700 net after withholding: held units decrease by 10, not 7. Cash and equity reconcile once; inference is reviewable. | #125, #127, #128 |
| “Correct that mistaken sale, then remove your last grant.” | Linked/standalone correction contract is explicit; generated valuations disappear when no longer justified; legitimate opening/manual balances remain. | #122, #128 |
| “Tell me your current net worth and outlook.” | Actuals, scope, current anchor and forecast use the same currency/ownership basis. CAD 100 + USD 100 at 1.30 gives CAD 230; missing FX remains incomplete. | #130, #132, #133 |
| “Where did you land compared with the forecast issued earlier?” | Only retained ex-ante run bands qualify. Select earlier run, overlay matured actuals, disclose gaps; dates before first run say No prior forecast. | #131, #134, #135 |
| “Change savings while keeping guideline market assumptions.” | Contribution 500 is saved even with defaults selected; zero clears it. Personal/20-year context survives save/reset/reload. Unsupported horizons have bounded recovery. | #136, #137, #138 |
| “Explain what the band and guideline badge mean.” | User can identify method, source year/jurisdiction, nominal/real basis, contributions and estimates. No guarantee or unsupported compliance claim. | #139 |
| “Why did spending increase last month?” | Comparable periods, transfers and category/merchant drivers match synthetic entries. USD 1,234.56 category is not removed by display parsing; cross-currency amounts are comparable. | #141, #142, #144, #149, #150 |
| “What is my financial position?” | Ask/use explicit personal versus household scope; ownership and excluded coverage are clear. Observation/sync/run timestamps are not confused with query time. Hidden debt/connection details never enter stubbed outbound prompts. | #140, #149, #150 |
| “What if I add another 200?” after loan analysis | Scenario retains context/tools or asks about ambiguity. Known-value baseline/extra-payment outputs are grounded; review link does not execute payment. | #144, #149, #150 |
| “Retry this failed reply, then regenerate a completed one.” | Partial output is visibly failed; exactly one replacement attempt targets the correct prompt. Effective-model fallback is really sent and attributed. | #145, #146 |
| “Disable AI before this queued response runs.” | Behavior follows reviewed consent/revocation policy at dispatch; all outbound prompt/history/tool data are accounted for. No false anonymization promise. | #147 |
| “Remember this privately; share only this other household goal.” | Audience is explicit; inspect user B's stubbed prompt. Review/edit/forget, chat deletion and expiry follow the agreed policy. | #148 |
| “Generate a tax report.” | Unrelated personal-use HELOC interest is a candidate requiring review, never an established deduction from name matching. Currency and source rows are clear. | #142, #143 |
| “Add income dated last month; correct an invalid field.” | Only writable accounts are offered. Invalid submission retains income/date/account/amount/categories; correction does not reverse sign or use today. | #151, #152 |
| “Undo this import.” | Preview discloses imported account and later records affected, not only imported transactions. Cancel preserves all data; confirm is exercised only in authorized disposable fixtures. | #153 |
| “Edit this already-achieved milestone.” | Refresh/name edit does not silently rewrite its attainment date; below-target/regain behavior follows the approved history policy. | #154 |

## Breadth pass after the priority journeys

These are discovery targets, **not findings of breakage**:

- First-run onboarding and manual/connected account choice: user understands which
  accounts are supported, how to proceed without credentials and why setup is blocked.
- Bank/brokerage account selection, stale/failed sync and recovery: distinguish
  connectivity from data freshness and prevent duplicate/unwanted imports.
- CSV mapping, signs/dates/currency/duplicate review: preview effects and recover
  from invalid rows without losing completed mappings.
- Manual and linked transfers: identify both sides, currency, confirmation and
  edit/undo semantics; do not count internal transfers as household income/expense.
- Budgets: first budget, changed month, category rules, uncategorized spending and
  zero versus missing data. Explain calculations without forcing users to learn internals.
- Debt strategy: eligible accounts, province/jurisdiction, fallback estimates,
  simulation readiness, scenario differences and stale results.
- Navigation/settings: names match user intent, no dead-end empty states, context
  survives navigation and account visibility applies to all menus/actions.

## Evidence record template

```text
Task / linked issue:
Tester / date / tested SHA:
Fixture version / fixed date / synthetic price and FX assumptions:
Verified disposable environment / provider stubs (no secrets):
Browser / viewport / input method:
User prompt:
Observed path / wrong turns / clarification requests:
Completion / elapsed time (measured, not target):
User's explanation of numbers:
Independent expected values / approved contract:
Screenshots or sanitized trace links:
Observed error / recovery:
Disposition: reproduced bug | usability friction | tested-adequate | blocked
Follow-up issue / owner / next evidence needed:
```

After a fix, repeat the same task/fixture comparison and its relevant automated
negative/known-value/system coverage. Report exact fresh checks and limitations;
never cite this playbook itself as an executed test result.
