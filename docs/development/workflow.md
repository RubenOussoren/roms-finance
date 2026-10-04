# Development workflow

## Environment and side effects

Use [README setup](../../README.md#development-setup) as the environment source of
truth. Ruby is pinned in `.ruby-version`; Node and service versions are in CI and
Compose. Local commands below assume locked dependencies and reachable **local**
services. The Docker equivalent prefixes commands with
`docker compose -f compose.dev.yml exec app` (use your approved Docker access method).

Inspect scripts before execution. `bin/setup`, container startup, `db:prepare`,
migrations, seeds and demo tasks mutate state; setup can also clear logs/tempfiles.
Never use those as automatic fallback validation. Do not overwrite `.env.local`,
read secrets, start/restart services or reset data without authorization. Demo reload
is destructive even if called from a development terminal.

## Test isolation is mandatory

`RAILS_ENV=test` alone does not establish safety: Compose passes a development
`POSTGRES_DB`. Explicitly select a disposable test database and separate Redis DB.
Check `config/database.yml` and environment precedence (including `DATABASE_URL`)
without printing credentials. Confirm no production/shared/customer endpoint is in use.
Do not copy production secrets; use fixtures/VCR/stubs and provider-network guards.
Test preparation/migrations require a verified disposable target and scoped approval.

Container examples for an **already prepared** test DB:

```sh
docker compose -f compose.dev.yml exec -e RAILS_ENV=test -e POSTGRES_DB=roms_test \
  -e REDIS_URL=redis://redis:6379/2 -e PARALLEL_WORKERS=2 app \
  bin/rails test test/models/account_test.rb
docker compose -f compose.dev.yml exec -e RAILS_ENV=test -e POSTGRES_DB=roms_test \
  -e REDIS_URL=redis://redis:6379/2 -e PARALLEL_WORKERS=2 app bin/rails test
docker compose -f compose.dev.yml exec -e RAILS_ENV=test -e POSTGRES_DB=roms_test \
  -e REDIS_URL=redis://redis:6379/2 -e DISABLE_PARALLELIZATION=true app bin/rails test:system
```

If `DATABASE_URL` is set, explicitly override it with the approved test URL or
remove it for the command; it can override the database-name setting. Do not blindly
paste commands into a different environment. For local execution use the same explicit
test context with local service addresses. Never reset a database to make a test pass.

## Validation matrix

| Change | Minimum focused evidence (then applicable CI gates) |
| --- | --- |
| Numerical calculation | Known-value, rounding, rates, date/empty/missing inputs; explicit randomness control |
| Tenancy/access/API | Cross-family, creator/joint/hidden/balance-only negatives, scopes and response field exclusions |
| Jobs/providers/webhooks | Stubbed boundary outcomes, missing config/data, failures and repeated delivery/retry |
| Persistence/migrations | Constraints, transactions, replacement/retry semantics, rollout/locking/recovery plan |
| UI | Controller/component tests; system coverage for critical user flow and privacy/error behavior; screenshots |
| Documentation/adapters | `ruby bin/check-development-docs`, source comparison and client discovery smoke check |

Use Minitest and mirror `app/` in `test/`. Prefer behavior assertions and independently
derived expectations. Snapshot/golden-master changes need an explanation of financial
output changes; don't accept them merely because the implementation generated them.
Time-sensitive tests use controlled dates; randomness needs a reproducible source/seed.
Quarantines/skips need a reason, follow-up owner and restoration condition.

## Commands and PR readiness

Run focused checks first, inspect failures, then full applicable gates. Current CI
in `.github/workflows/ci.yml` is authoritative for required automated checks:

```sh
bin/rubocop
npm run lint
bin/brakeman --no-pager
bundle exec bundler-audit check --update
bin/importmap audit
npm audit
bundle exec ruby bin/verify-playwright
```

Audits require advisory-network access, not live financial-provider credentials.
Browser setup must match the locked Ruby/npm/Chromium toolchain. Rails equivalents
of compilation/loading checks are `bin/rails zeitwerk:check` and a relevant asset
build when applicable, with safe environment/configuration established first.

`npm run lint` is Biome lint only. `npm run format:check` and `npm run style:check`
are broader/nonrequired checks with documented existing formatting debt; do not claim
lint proves formatting or silently reformat the repository. Use autofix only for an
intentional scoped change. Coverage is opt-in (`COVERAGE=true`); start with measured
high-risk branch gaps rather than inventing a percentage gate.

Before PR readiness run the full unit/integration suite; CI also runs system tests.
A docs-only change can use the documentation check without local Rails/browser tests,
provided the handoff says so; CI still owns its configured gates. Do not waive CI.
Never run `bin/setup` or DB tasks simply to satisfy documentation checks.

## Completion evidence

Review `git diff` and report changed scope, commands/exit results, test counts when
available, skips/blocked checks, altered assumptions/output and remaining risks.
Label historical results with their SHA/report. Keep temporary logs under `tmp/`,
not shared policy. Record architectural decisions in numbered ADRs; record findings
with evidence and confidence. Publication/deployment requires separate authorization.
