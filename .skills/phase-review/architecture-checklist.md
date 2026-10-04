# Architecture and risk checklist

Use applicable items for the agreed review scope, alongside canonical architecture and
financial contracts. These are investigation prompts, not automatic pass/fail rules.

## Data and migrations

- Associations, tenant ownership and deletion behavior match domain invariants.
- Constraints/indexes support real integrity rules and access patterns; pre-existing
  nulls, duplicates and orphans are handled deliberately, not silently discarded.
- Migration locking, mixed-version rollout, backfill restart and recovery are addressed
  (see `/migration`). DDL reversibility alone does not protect deleted data.
- Query shape and actual plans/data volumes support performance claims; safe parameterized
  SQL is not a violation simply because it is not expressed as an ActiveRecord scope.

## Models, calculators, services and jobs

- Responsibilities and dependencies fit actual interfaces; no shadow rule implementations.
- New pure calculations have explicit inputs and no DB/cache/provider side effects.
- Multi-step state, persistence, job retries and idempotency have clear ownership.
- Money/currency, rate units, compounding, rounding, tax provenance and cash-flow timing
  reconcile with financial contracts and known-value tests.
- Duplication is evaluated for divergence risk; extraction and single-caller helpers can
  be justified. Method length is not proof of architectural failure.

## Controllers and UI

- Authorization, `Current.user`/`Current.family`, tenant scoping and strong parameters
  prevent cross-family reads/writes; errors avoid exposing internal or personal data.
- Queries avoid harmful N+1 patterns; transaction boundaries and failure paths are sound.
- Hotwire, actual helpers/design tokens and existing view/component patterns are reused;
  financial math stays out of templates. Accessibility and safe output are checked.

## Tests and operations

- Regression tests assert observable behavior, financial expected values and meaningful
  boundaries; randomness/time/shared mutable state are controlled.
- Golden-master changes explain the new contract, not just replace failures.
- Tests use isolated DB/Redis and no live providers; skipped checks remain visible.
- Provider failures, secrets/logging, queue/cache isolation and deployment compatibility
  are addressed where applicable.
- Documentation explains decisions, formulas, changed contracts and operational risks.
  Neither public-method comment counts nor doc/code length ratios establish quality.
