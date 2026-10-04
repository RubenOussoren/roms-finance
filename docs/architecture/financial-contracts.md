# Financial contracts

This document separates **observed behavior** from **requirements for future
changes**. Requirements are not assertions that the current application already
satisfies them. Changes should preserve characterized behavior unless a reviewed
financial correction explicitly changes it.

## Amounts, rates and rounding

### Existing behavior

- `db/schema.rb` stores many amounts (accounts, balances, projections and debt
  ledger amounts) as decimal `(19,4)`, not integer cents. Other fields have
  different scales; there is no single application-wide precision policy.
- `lib/money.rb` is the application's Money class: amount is a BigDecimal in
  currency units, with a currency object. `app/models/concerns/monetizable.rb`
  wraps model fields and returns nil for absent amounts/currency. This is not
  a claim that every financial operation uses Money.
- `app/calculators/projection_calculator.rb` converts principal/rate/contribution
  with `to_d`, uses an annual fractional rate divided by 12, and rounds many
  emitted balances to two decimals. Statistical math also uses Math/Float.
- `app/calculators/loan_payoff_calculator.rb` takes a percentage rate (5 means
  5%), converts it by dividing by 100, evolves an unrounded running balance,
  and rounds schedule fields to two decimals. Summary totals sum the rounded
  schedule fields. It stops at a 0.01 balance threshold or 360 months; an empty
  or truncated schedule must not automatically be interpreted as paid off.
- `app/models/canadian_mortgage.rb` converts nominal semiannual mortgage rates
  to monthly rates and uses floating-point constants/exponents. Its simple
  monthly-rate method is separate. LoanPayoffCalculator selects the Canadian
  conversion by mortgage subtype, not by a complete jurisdiction policy.
- `app/calculators/family_projection_calculator.rb` converts some output to
  Float and warns about mixed currencies without converting all projected
  account amounts. `app/models/balance_sheet/account_totals.rb` uses SQL
  `COALESCE(exchange_rates.rate, 1)`, even when a foreign-currency rate is absent.

### Requirements for future changes

Specify units, currency, liability/sign convention, rate convention (fraction vs
percentage, nominal vs effective), compounding and contribution timing at each
new boundary. Do not silently switch storage to cents, change scales, or convert
all existing algorithms to a different numeric type.

Document where rounding occurs and the chosen rounding mode for new financial
logic; test terminal payments, cumulative totals and persistence precision.
Prefer decimal inputs for monetary arithmetic, but recognize that statistical
and exponential routines may use Float. Test their error tolerance rather than
claiming exact arithmetic. Presentation rounding is not permission to round
intermediate balances. Mixed-currency aggregation requires dated conversion or
an explicit incomplete/unsupported result, not an unlabeled sum.

## Dates and randomness

**Existing:** projection, loan, milestone and family calculators read
`Date.current`. Milestone target-date calculations approximate months with
30-day intervals. Debt loops start at `Date.current.beginning_of_month`, and
ledger timestamps use `Time.current` (`app/services/abstract_debt_simulator.rb`,
`app/services/canadian_smith_manoeuvr_simulator.rb`). Projection Monte Carlo uses
a Box–Muller transform; analytical bands are a separate path. ProjectionCalculator
now accepts optional `as_of:` and `random:` inputs. A fresh `Random.new(seed)` plus
explicit date supports repeatable output; an already-advanced RNG is mutable state.
Default callers retain current-date/global-random behavior. Numeric inputs alone
do not guarantee reproducibility throughout the application.

**Future:** accept an explicit as-of/start date and calendar convention in
extracted kernels, and an injectable random generator or seed for stochastic
runs. Record enough run context to reproduce results, including assumptions,
algorithm version, date, seed and simulation count. Freeze time/control randomness
in characterization tests until those seams exist. Test month-end, leap-year,
year-boundary privilege resets and renewal behavior; do not quietly replace
30-day estimates with calendar-month behavior in an extraction.

## Sources, assumptions and jurisdictions

**Existing:** `app/models/projection_standard.rb` has a jurisdiction,
`effective_year`, year selection and code-based `PAG_2025` identification.
`app/models/concerns/pag_compliant.rb` also embeds PAG 2025 constants. These
labels/badges are implementation choices, not an independent regulatory audit.
`app/models/projection_assumption.rb#create_default_for` uses
`Jurisdiction.default`, which prefers Canada (`app/models/jurisdiction.rb`),
not necessarily the family's country. `app/models/concerns/jurisdiction_aware.rb`
also falls back to default jurisdiction and to CA when country is absent.

`app/models/debt_optimization_strategy.rb` checks Smith Manoeuvre support,
resolves province with an Ontario fallback, and uses a 40% fallback when the
computed marginal rate is missing or nonpositive. Its account validation checks
required strategy accounts but is not a same-family authorization check.
`app/models/canadian_mortgage.rb` cites the Canadian Interest Act for its
semiannual convention. These rules do not establish general US/UK tax support.

**Future:** keep external data provenance (provider, requested/observed date,
currency and retrieval context) and policy provenance (source/version,
effective year, jurisdiction/province and overrides) with the calculation
inputs or run record. Validate applicable jurisdiction and authorized account
membership before simulation. Distinguish custom assumptions from published
standards; surface fallback use. A new jurisdiction or guideline year requires
source-backed rules and tests, not just a label or inherited Canadian defaults.
Source comments in code are starting references, not proof that laws or
published guidelines are current.

## Missing is not zero

**Existing:** `app/calculators/forecast_accuracy_calculator.rb` excludes missing
actual/projected balances and can return nil for unavailable metrics.
`lib/money.rb#exchange_to` raises ConversionError for missing FX unless an
explicit fallback is provided. Conversely, loan payoff defaults missing rates
and payments to estimates, family loan projections return zero when a schedule
entry is absent, and jurisdiction/SQL paths use fallbacks described above.
`app/models/provider.rb` distinguishes success/data/error; missing configuration
can also return nil from `app/models/provider/registry.rb`.

**Future:** distinguish known zero, missing input, failed fetch, estimated value,
unreachable target and capped/incomplete simulation. Do not turn nil/errors into
zero with blanket `to_d`, defaults or rescue. Estimates may be legitimate, but
must be identified with their assumptions and uncertainty. Test zero-rate,
zero-balance, absent-rate and failed-provider cases independently. Preserve
existing fallbacks during extraction; removing them is a separate behavior
change with user-facing implications.

## Persistence: no blind bulk writes

**Existing:** debt simulators build ActiveRecord ledger objects and call
`DebtOptimizationLedgerEntry.insert_all` with their attributes and timestamps.
This does **not** run model validations/callbacks merely because objects were
constructed. `app/models/debt_optimization_ledger_entry.rb` validates month and
date, but that insert path bypasses those checks.
`app/models/debt_optimization_strategy.rb#run_simulation!` supplies the outer
transaction for destroying old rows, writing scenarios, computing summaries
and saving status. A strategy row lock now serializes concurrent supported runs;
regression tests exercise real PostgreSQL contention and rollback. This does not
lock changes to associated accounts or make direct simulator calls replacement-safe.

**Future:** do not copy bulk-write patterns blindly. Before adding/changing a
bulk path, establish authorized family/strategy ownership, validate generated
rows and scenario completeness, identify skipped callbacks, and preserve
required cache/audit/summary effects. Define duplicate/retry/concurrent-run
behavior and database constraints deliberately. Keep replacement and summary
updates atomic; use normal model persistence when required effects cannot be
reliably reproduced by an explicit bulk contract. Test rollback and reruns as
well as arithmetic. A docs-only contract does not repair existing bypasses.

## Change evidence

Start with `test/calculators/` and `test/services/` (including debt simulator
comparison and edge-case tests). Add focused characterization of changed
rounding, missing-data, date, jurisdiction and persistence behavior. Separate a
structural extraction from a financial correction so numerical differences are
explainable. See [current state](current-state.md) for effects that must first
be moved to explicit orchestration boundaries.
