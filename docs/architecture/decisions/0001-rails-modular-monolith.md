# ADR 0001: Retain the Rails modular monolith

- **Status:** Accepted
- **Date:** 2026-10-04
- **Scope:** Architecture direction; no runtime or framework migration

## Context

ROMS Finance is already a Rails application with PostgreSQL, Sidekiq and
Hotwire/ViewComponent (`Gemfile`). Family is the tenancy root, with per-account
visibility and reporting ownership layered on top (`app/models/family.rb`,
`app/models/concerns/account_accessible.rb`, `app/models/account_ownership.rb`).
Provider adapters already have a registry and selected concept interfaces
(`app/models/provider/registry.rb` and the provider concept concerns).

Financial code spans calculators, models and debt services. The separation is
useful but incomplete: calculators can read time, randomness, database state
and even create default assumptions; simulators compute and bulk-write ledger
rows. `app/models/debt_optimization_strategy.rb#run_simulation!` coordinates
transactional ledger replacement and summary persistence. These are actual
couplings, not a pure domain layer behind an enforced module system.

See [current state](../current-state.md) for implementation references and
[financial contracts](../financial-contracts.md) for numeric and effect risks.

## Decision

**Retain Rails as a modular monolith.** Improve domain boundaries incrementally
inside the existing application and deployment. “Modular” describes the target
separation of responsibilities, not a newly installed framework or a claim that
all modules are already isolated.

Use existing Ruby classes, Rails models/jobs and provider interfaces. Keep
Family tenancy and account authorization explicit at use-case entry points.
Separate authorized input assembly, numerical kernels, simulation orchestration,
persistence and external-provider normalization as individual use cases change.
Keep business invariants near their domain models; orchestration owns multi-step
operations and transactions. Do not force every method into a new service layer.

There is no decision here to adopt microservices, Rails engines, a packaging
framework, event sourcing, a new dependency-injection container or a second
financial runtime. Existing directories may remain while dependencies improve.

## Alternatives considered

- **Extract financial/provider microservices now:** adds distributed failure,
  deployment and cross-boundary transaction complexity before stable input and
  output contracts exist. Defer until a concrete operational need justifies it.
- **Replace Rails or impose a new modularity framework:** does not itself fix
  tenancy leaks, rounding semantics or implicit I/O; creates unrelated migration
  risk. Reject for this scope.
- **Keep all current coupling indefinitely:** cheapest short term, but hides
  financial side effects and makes reproducibility difficult. Reject as the
  target, while accepting compatibility wrappers during incremental work.

## Consequences and implementation direction

- Preserve current UI, integrations, database and job deployment. Numerical
  extractions can ship independently with characterization tests and wrappers.
- Authorization remains a first-class concern: visibility scopes are not
  tenant filters, nil-viewer reports are family-wide, and percentage ownership
  is not permission to read account detail.
- Provider interfaces remain concept-specific. Network/cache/database work
  belongs at explicit edges, not inside newly extracted numerical kernels.
- Current impurity and bulk-write bypasses remain until separately implemented
  changes address them. This ADR does not authorize blind rewrites or claim
  regulatory compliance.
- Start by characterizing a selected calculator/simulator, supplying explicit
  dates/assumptions/randomness, then separating output from persistence while
  preserving transaction and callback effects. Follow the financial contracts
  when a change intentionally alters results.
- Boundary enforcement initially depends on code discipline and tests, not
  package tooling. Revisit tooling or service extraction only with evidence of
  an independently scalable workload, required isolation, or team ownership
  that outweighs operational costs and has stable contracts.

## Validation

Architecture changes should demonstrate unchanged authorized account selection,
explainable numerical output, reproducible run inputs and preserved atomic
persistence. Existing tests in `test/calculators/` and `test/services/` provide
starting coverage, not proof that all proposed boundaries are satisfied.
