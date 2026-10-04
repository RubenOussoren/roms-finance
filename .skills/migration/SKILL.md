---
name: migration
description: Design and validate database migrations with integrity and safe rollout controls
---

# Safe database migration

Read [shared guidance](../references/operating-guidance.md), the canonical current-state,
financial contracts, and development workflow. Authoring a migration does not authorize
executing it. Use `/db` for target confirmation and explicit execution approval.

## Design and integrity

1. Read the current schema, affected models/callers, prior migrations, and database
   version. Define the invariant and inspect existing nulls, duplicates, orphaned foreign
   keys, row counts, and monetary precision/currency semantics with safe scoped queries.
2. Enforce required invariants with appropriate NOT NULL, unique/check constraints and
   foreign keys, matching model behavior. Design indexes from real access patterns.
   Do not silently delete duplicates, coerce money, or discard records to make DDL pass.
3. Keep migration logic independent of mutable application models and external providers.
   Separate schema changes from large data backfills. Backfills must be bounded, batched,
   restartable/idempotent, observable, and explicit about callbacks and concurrent writes.

## Rollout and locking

4. Use expand/backfill/validate/switch/contract stages for incompatible changes. Old and
   new application versions must coexist during deployment; delay drops/renames until
   old readers/writers are gone. Define dual-write/reconciliation needs where applicable.
5. Assess table size, expected lock modes/duration, scans/rewrites, disk/WAL growth,
   replication lag, and index build cost. Plan lock/statement timeouts and retry/abort
   behavior. Use PostgreSQL concurrent indexes where suitable and the required transaction
   handling; account for invalid indexes left by interrupted builds. Stage constraint
   validation when supported; verify database/version semantics rather than assuming
   every DDL operation is online. No blanket disabling of transactions or integrity checks.
6. Document backup/restore readiness, operational window, monitoring, success criteria,
   and rollback/forward-fix strategy. Reversible DDL does not restore deleted data; mark
   irreversibility clearly and require an approved recovery plan for destructive changes.

## Validate and execute

7. Test on an approved isolated scratch database: existing-schema upgrade, fresh install,
   invariant failures, and backfill restart behavior. Test rollback only where safe;
   examine the schema diff and explain incidental changes. Production-scale cost needs
   representative measurements, not a claim based on tiny fixtures.
8. Present exact migration versions, redacted target, command, lock/data risks, and recovery
   plan. Obtain specific user authorization before migrate/prepare/rollback/schema load,
   including scratch DB execution. Never run production deployment commands automatically.
9. After approved execution, check versions, constraints/index validity, counts and financial
   reconciliation, app compatibility, and errors. Stop on unexpected results; report
   blockers and the next safe action instead of automatically rolling back or resetting.
