# Shared skill operating guidance

Paths below are repository-relative. Skills provide task procedures; canonical rules
live in:

- [AGENTS.md](../../AGENTS.md): agent scope, conventions, safety and ownership.
- [CONTRIBUTING.md](../../CONTRIBUTING.md): contribution and publication workflow.
- [Current architecture](../../docs/architecture/current-state.md): implemented boundaries and APIs.
- [Financial contracts](../../docs/architecture/financial-contracts.md): units, assumptions, money and date semantics.
- [Development workflow](../../docs/development/workflow.md): supported runtimes, setup and checks.

Read applicable sources and the code before acting. If a canonical document is missing
or conflicts with observed code, report the gap and verify the relevant implementation;
do not invent APIs or create/edit those documents as part of a skill task. Preserve
other agents' work. Only delegate review when the user explicitly requests review,
a second opinion, or a reviewer. Preparation never implies publication authorization.

## Test preflight: before Rails boots

Tests load fixtures and can maintain/replace schema. `RAILS_ENV=test` alone is unsafe:
`config/database.yml` uses `POSTGRES_DB` in both development and test, and Rails can
merge `DATABASE_URL`. Environment files can supply credentials and overrides.

1. Inspect current environment loading, DB configuration, `test/test_helper.rb`, Redis/
   cache/Sidekiq/cable configuration and selected test code without printing secrets.
   Confirm the effective host/database is a dedicated disposable local test target,
   unrelated to development/shared/production data. Override both `POSTGRES_DB` and
   `DATABASE_URL` consistently, or remove the URL override safely from this process;
   confirm every configured connection, not just the primary name.
2. Set `RAILS_ENV=test` **before** starting the command. Use `DISABLE_PARALLELIZATION=true`
   initially; if parallelizing, verify worker database names/permissions and isolation.
   Obtain approval for fixture/schema replacement in the named disposable DB. If its
   creation or schema preparation is needed, stop for `/db` and `/migration` approval.
3. Use a dedicated local Redis instance/container for tests; set `REDIS_URL` and any
   configured `CACHE_REDIS_URL`/queue URLs to it. Verify no fallback reaches shared
   Redis. A database number alone is not isolation from `FLUSHALL`; never flush shared
   Redis. Keep job execution in the test adapter; no live workers or external queues.
4. Remove real provider credentials from the process and account for environment-file
   reloads. Use dummy values only where required by tests. Inspect VCR/WebMock setup
   and recording modes; replay cassettes/stub responses with external HTTP blocked.
   Sandbox flags do not prevent real network activity. Do not record new cassettes or
   allow live banking, market-data, AI, payment or email providers. Browser tests may
   reach only the verified local test app; block other egress. If blocking cannot be
   established, report the test as blocked rather than running it.
5. Report the command and redacted verified targets. Do not expose URLs containing
   passwords, personal financial records, or API keys. Missing infrastructure does
   not authorize service startup, reset, migration, seed or demo reload.

Use process-local overrides, not persistent edits to another agent's environment files.
Read-only status checks and audits may require network access to approved local services
or advisory endpoints; this does not authorize live provider calls.

## Mutations and authorization

Describe exact action, environment/target and scope before requesting approval.
Specific user requests can authorize their stated scope; clarify ambiguous or broader
actions. Never automatically migrate, rollback, reset/drop/load schema, purge records,
reload demo data, start services, or remediate a failed check destructively. A warning
without approval is not consent. Protect retained data with a verified recovery plan;
prefer new disposable resources over repairs to shared ones.

Commit, push, PR creation/edit, release draft edits, tag creation and publication each
need user authorization for their scope. Never push directly to `main` or another
protected base branch, force-push, bypass hooks, or sweep unrelated files into commits.
