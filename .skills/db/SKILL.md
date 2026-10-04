---
name: db
description: Inspect database state and perform only explicitly authorized local data operations
---

# Database operations

Read [shared guidance](../references/operating-guidance.md) and the canonical development
workflow. `/db` with no action lists options; it never prepares, migrates, or resets data.

1. Establish action and target: Rails environment, effective database host/name/user,
   `DATABASE_URL` overrides, `POSTGRES_DB`, and any multi-database configuration. Read
   task implementations/seeds first; report targets without credentials. Status/version
   commands are read-only but still require a verified target before booting Rails.
2. For setup/create/prepare/seed, explain exact writes and obtain user authorization
   for that environment/database. `db:prepare` may migrate and seed; it is not inspection.
   Seed once only when required and approved; do not assume seeds create demo users.
3. For migration or rollback, use `/migration`: inspect pending versions and integrity/
   rollout risks first. Never auto-migrate to repair setup or test failures.
4. Reset/drop/schema load/truncate/rollback/demo reload requires specific authorization
   naming the disposable local database, exact deletion/replacement scope, and backup
   or explicit disposability. Refuse shared/production targets; prefer a new scratch DB.
   `db:reset` loads schema and seeds; it is not migration replay. Do not seed twice.
5. Read `lib/tasks/demo_data.rake` and the generator before any `demo_data:*` invocation:
   demo operations can purge/recreate existing records. Approval to run tests/setup
   does not approve demo replacement. Never infer credentials from old instructions.
6. Execute only the approved command(s), stop on errors, and verify schema version,
   expected record/integrity checks, and absence of unintended changes. Report outcomes
   without personal financial data or secrets. Never flush shared Redis to fix DB issues.

For tests, use the isolated targets and offline guards in the shared guidance and `/test`.
Rails environment names alone do not prove database safety.
