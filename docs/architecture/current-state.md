# Current architecture

This is a source-based snapshot, not a claim that every boundary is enforced.
For financial change requirements see [financial contracts](financial-contracts.md);
for the architectural choice see [ADR 0001](decisions/0001-rails-modular-monolith.md).
The older `design-vision.md` is explicitly aspirational.

## Runtime and domain

ROMS Finance is one Rails 8 application with PostgreSQL, Sidekiq jobs and
Hotwire/ViewComponent UI (`Gemfile`). Models hold associations, validations and
much orchestration; calculators live in `app/calculators/`, debt simulators in
`app/services/`. These directories are conventions, not isolated packages.

The tenancy root is **Family**, not User. `app/models/family.rb` owns accounts,
users, imports, budgets, categories, projection assumptions and debt strategies.
Entries, transactions, trades and holdings are reached through accounts.
`app/models/account.rb` belongs to a family and a required `created_by_user`;
its delegated `accountable` supplies the financial account type. Creator
ownership is distinct from the family's tenancy ownership and from percentage
ownership used for personal reporting.

`app/models/current.rb` derives the current user from a session (including
impersonation) and delegates family to that user. This request convenience is
not a database-wide tenant filter. Background work must carry its context;
`app/jobs/sync_job.rb`, for example, receives a sync record and calls `perform`.

## Visibility and ownership

`app/controllers/application_controller.rb` starts account access from
`Current.family.accounts`, then applies `accessible_by` or `full_access_for`.
`app/controllers/accounts_controller.rb` looks up an account through the scoped
relation. Tenant scoping and visibility are separate checks; a bare Account
query or visibility predicate alone does not establish family membership.

`app/models/concerns/account_accessible.rb` and `app/models/account_permission.rb`
implement full, balance-only and hidden access. Instance visibility grants full
access to the creator, joint accounts and users without a permission row.
Permission validation rejects restrictions for joint accounts and permission
rows for the creator; permission changes touch the account for cache invalidation.
Balance-only access is not permission to expose transaction detail.

The foundation hardening aligns visibility scopes with instance predicates:
viewer-specific absence means default-full even if another member has a permission
row; creator/joint overrides apply consistently, including legacy restrictions
saved before an account became joint. AccountPermission and AccountOwnership both
validate same-family membership. These are not database-wide tenant filters;
callers still preserve a family-scoped relation, and bulk writes bypass validation.

Valuation update previews now use the same full-access entry lookup as mutations.
Negative request tests cover hidden/balance-only previews, API transaction reads/
writes and cross-family permission/export boundaries. This is targeted coverage,
not a universal authorization guarantee for every endpoint or background task.

`app/models/account_ownership.rb` stores percentage ownership, validates
same-family users and a total at most 100%, and touches accounts on changes.
`Account#ownership_fraction_for` uses explicit percentages when present;
otherwise joint accounts split equally among family members and non-joint
accounts belong to their creator. Personal reporting uses `with_ownership_for`
and fractions, not simply `owned_by`.

`app/models/balance_sheet/account_totals.rb` and
`app/calculators/family_projection_calculator.rb` accept viewer/scope context:
household reports use accessible accounts; personal reports use ownership.
A nil viewer means family-wide calculation, not privacy-filtered calculation.
Balance-sheet cache keys include viewer and scope. These entry points are
examples of implemented filtering, not proof of coverage for every export,
API, assistant function or job.

## External providers

`app/models/provider/registry.rb` selects configured adapters. Its concept
registry currently covers exchange rates (Frankfurter), securities (configured
FinancialData or AlphaVantage) and LLM (RubyLlm). It also exposes named factories
for integrations including regional Plaid, SnapTrade, Stripe and GitHub.
Factories such as market-data and Stripe can return nil when unconfigured;
the registry does not guarantee every returned slot is a usable provider.

`app/models/provider/exchange_rate_concept.rb`, `security_concept.rb` and
`llm_concept.rb` define method signatures and `Data` result shapes, with
`NotImplementedError` defaults. They are Ruby concerns, not a universal plugin
framework or an interface covering every integration.
`app/models/provider.rb` supplies `Response(success?, data, error)`, error
transformation and a Faraday client with timeouts/retries. Methods using
`with_provider_response` convert exceptions to failed responses; callers must
check success, not interpret missing data as a zero value.

Adapters are not all network-only: `app/models/provider/financial_data.rb`
searches local Security records and Rails cache as well as remote data.
`app/models/provider/frankfurter.rb` fetches FX rates and returns floating-point
rates. Configuration and external I/O remain coupled to Rails.

## Financial computation and effects

- `app/calculators/projection_calculator.rb` contains scalar growth math. Optional
  `as_of:` and `random:` inputs support replayable date/Monte Carlo output (use a
  fresh seeded RNG for each replay). Omitting them preserves per-call `Date.current`
  and instance/global `rand` behavior; other calculators are not uniformly pure.
- `app/calculators/loan_payoff_calculator.rb` reads Account/Loan objects and
  current dates, estimates missing inputs, and memoizes schedules.
- `app/calculators/milestone_calculator.rb` reads assumption objects and current
  dates; target-date conversion approximates a month as 30 days.
- `app/calculators/family_projection_calculator.rb` queries associations, reads
  historical reports, logs currency warnings and resolves assumptions.
  `ProjectionAssumption.for_account` can create a family default through
  `default_for` (`app/models/projection_assumption.rb`), so even a projection
  read can cause persistence.
- `app/calculators/forecast_accuracy_calculator.rb` materializes its input with
  `to_a` (which can load a relation); its metrics exclude missing balances.
- `app/services/abstract_debt_simulator.rb` evolves monthly state and bulk inserts
  ledger rows. Baseline and prepay-only subclasses share that loop;
  `app/services/canadian_smith_manoeuvr_simulator.rb` runs both comparisons and
  its own HELOC/readvanceable loop, also persisting rows.
- `app/models/debt_optimization_strategy.rb#run_simulation!` wraps ledger
  destruction, simulation, summary updates and strategy save in a transaction,
  with a strategy row lock serializing replacement. Unsaved inputs are saved in
  the same transaction; association state is reset on success/failure and obsolete
  comparison metrics cleared. Direct simulator calls lack that lifecycle guarantee;
  associated account changes are not locked by the strategy lock.

## Incremental target boundaries (not yet enforced)

Keep Rails, existing models and deployment. Improve seams one use case at a time:

1. **Authorized input assembly:** request/job orchestration resolves family,
   viewer, permitted accounts, assumptions, FX and jurisdiction. Do not pass
   implicit `Current` into a numerical core.
2. **Numerical kernels:** extract explicit scalar/snapshot inputs, as-of dates
   and random generators; return results without database, cache or network
   effects. Retain compatibility wrappers during migration.
3. **Simulation orchestration and persistence:** separate monthly transitions
   from ledger validation/replacement and summary updates. Preserve the existing
   transaction and callback semantics before changing storage mechanics.
4. **Provider adapters:** use the existing registry/concepts; normalize external
   data at the edge, making absent configuration and failed/missing results
   explicit. Do not expand a concept interface merely to hide unrelated APIs.

Characterization tests in `test/calculators/` and `test/services/` are the starting
point, alongside visibility/ownership model and controller tests. Directory
moves alone do not establish these boundaries.
