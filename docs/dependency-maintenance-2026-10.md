# October 2026 maintenance queue resolution

The 12 non-security Dependabot PRs generated after the security cleanup were
refreshed against `be598213` and rebuilt into focused replacements. Initial GitHub
vulnerability alerts were zero; refreshed Ruby/importmap/npm audits remain clean.
The original [security baseline](dependency-security-baseline.md) is preserved.

| Group | Original PRs | Replacement / migration evidence |
| --- | --- | --- |
| CSV 3.3.6, activerecord-import 2.3.0, Doorkeeper 5.9.9, Pagy 43.6.3 | #100, #103, #104, #106 | #110; four lock entries only; import/export, OAuth and pagination coverage |
| Propshaft 1.3.2, Tailwind Rails 4.6.0/compiler 4.3.3 | #101, #102 | #111; unrelated Ruby/stdlib/RDoc/Rack resolver changes excluded; assets build/browser suite |
| Stripe 19.6.2 + existing snapshot webhook repair | #105 | #112; [real SDK signature/billing contracts](stripe-regression-coverage.md) |
| JWT 3.3.0 | #108 | #113; [ES256/JWK/claim/body-hash coverage](jwt-3-upgrade.md) |
| Plaid 51.0.0 | #98 | #114; [all five major-version schema notes and HTTP contracts](plaid-51-upgrade.md) |
| Puma 8.0.2 | #107 | #115; [HTTP/WebSocket/restart/cluster/shutdown probes](puma-8-upgrade.md) |
| Ruby/npm Playwright 1.63.0 | #99 | #116; [matching locked CLI/browser and new drift gate](playwright-1.63-upgrade.md) |
| Biome 2.5.15 | #97 | [configuration and targeted diagnostic migration](biome-2-migration.md), separate final PR |

Every group ran full isolated local unit/integration and Chromium suites, lint,
Brakeman, refreshed dependency audits, and Zeitwerk. Fresh GitHub CI on the
then-current main is required before every merge. No tests were disabled and no
security or CI gate was suppressed. No live provider financial mutation was used.

## Updated validation baseline

- Fresh unchanged main: **1,933 tests, 9,176 assertions, 16 existing skips**;
  **72 browser tests, 253 assertions**, zero failures/errors.
- Integrated maintenance candidate: **1,987 tests, 9,464 assertions**, zero
  failures/errors, the same **16 skips**; **72 browser tests, 253 assertions**,
  zero failures/errors/skips.
- Net 54 additional tests: Stripe +25 (existing coverage retained/replaced with
  deterministic contracts), JWT +18, Plaid +11.
- Ruby/JavaScript lint, strict Biome lint, Brakeman, refreshed bundler-audit,
  importmap/npm audits, Zeitwerk, Playwright toolchain guard, and actionlint pass.
- Optional `style:check` still has the **same 22 pre-existing formatting files**
  as unchanged Biome 1 main. These are not new diagnostics or failed required CI
  checks; unrelated formatting was intentionally left alone.

Local tests used the isolated validation Compose project's DB/Redis/cache and
explicit `RAILS_ENV=test POSTGRES_DB=roms_test REDIS_URL=redis://redis:6379/2`.
The bind-mounted root checkout stayed unchanged throughout candidate validation.
Private development backups are ignored and never committed. Sandbox refresh
must preserve configuration and development volumes, then verify `/up`, Rails,
Tailwind, Sidekiq, admin/member login, dashboard/account pages, and financial data.

## Remaining separate follow-ups

- Consider explicit future-`iat` rejection/normalized malformed claims in Plaid
  webhook application policy. These were pre-existing, not JWT upgrade regressions.
- Existing formatting debt, Brakeman suppressions, and test skips remain separate
  maintenance items, not reasons to weaken the established dependency gates.
- Other IPv6/proxy production platforms should verify Puma 8 ingress behavior.
  Local IPv4 and production-equivalent clustered test-mode probes passed; this
  does not claim validation of an unrelated live production deployment.

Final merged SHA, final-main CI/Docker publication, refreshed alert/PR inventory,
and sandbox preservation evidence are recorded in maintenance issue #109 after
verification completes; those moving results cannot be self-referenced by a
commit that is still awaiting merge.
