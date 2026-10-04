# Foundation hardening — October 2026

**Date:** 2026-10-04
**Baseline:** `8e20add4`
**Scope:** user-authorized sandbox validation, focused fixes, feature-branch PR and
merge. No production data operations or financial-assumption changes.

This follows the initial [documentation-only validation](foundation-validation-2026-10.md).
The original [assessment](assessment-2026-10.md) remains historical. Current behavior
is in [architecture](../architecture/current-state.md); the roadmap's full milestones
are broader than this bounded tranche.

## Implemented and demonstrated

| Area | Finding / disposition | Evidence |
| --- | --- | --- |
| Access scopes | Fixed viewer-default and joint-account SQL/instance disagreements; permission rows validate same-family membership | Executed SQL/model regressions; 4 failures before fixes, related models then green |
| Valuation previews | Fixed hidden/balance-only preview bypass using mutation's full-access lookup | 2 request failures before fix (200 instead of 404), then both denied |
| API / export / permission writes | Added cross-family and restricted-account negatives; denied API create now returns generic 404 instead of rescued 500 | Request tests assert no disclosure, mutation or enqueue; cross-family permission changes roll back |
| Simulation lifecycle | Strategy row lock serializes replacement; rollback, refreshed association and obsolete summary clearing | Sequential/changed reruns, partial insert/final save failures and real PostgreSQL lock contention tests; removed-lock override reproduced race |
| Projection replay | Optional explicit date and RNG preserve default clock/draw behavior and all formulas | Seeded fresh RNG tests across time/global draws, month-end/leap-year, known values, zero guard; calculator suite green |
| CI / publication | Service majors match sandbox; resolved immutable SHA flows through every checkout, image SHA tag, OCI revision and build argument | YAML/static contracts, actual resolver in temporary Git repo, actionlint; manual runs SHA-only, push main/tag retains channel promotion |
| Historical publication | Pre-foundation targets lack newly added docs tooling | Compatibility applies only to nonempty publication checkout and absence of both canonical skills/checker; PR gate and partially deleted foundation remain mandatory; other application/security gates always run |
| Lint | Enabled Biome VCS ignore integration; stale ignored tmp configs no longer break root lint | Ordinary lint passes; temporary invalid application JS still rejected, then removed |
| Sidekiq production access | Removed usable implicit `roms` password, fail closed for missing/blank/default credentials without failing app boot | Standalone Basic Auth tests, constant-time comparison, production-only wiring; development/application/API auth unchanged |
| Coverage | Measured line/branch baseline; CI retains unit/integration report including resultset | Coverage is evidence, not a new percentage threshold; no skip/ignore suppression added |

**Upgrade note:** production Sidekiq dashboard operators must explicitly set both
credential variables with a unique password. The example password now defaults empty;
`roms`/`roms` no longer works. App boot and the private development dashboard still work.
Manual publication now emits only immutable SHA tags; rolling/semver promotion is
reserved for push events. Old revisions can still fail existing security/compatibility
gates; compatibility is not a promise to publish vulnerable or unsupported software.

## Environment and evidence

Existing Docker sandbox: Ruby 3.4.4, Node 22.23.3, PostgreSQL 16, Redis 7,
matching Ruby/npm Playwright 1.63.0 and installed Chromium. Main integrated tests use
new disposable `roms_foundation_test`; specialists used separate disposable test DBs.
All use explicit `RAILS_ENV=test`, database host `db`, Redis DB 2, unset
`DATABASE_URL`, disabled dotenv file loading, dummy provider values, VCR replay-only
and blocked external provider HTTP. Browser tests allow the local test app; advisory
audit traffic is separately allowlisted. Development volumes/configuration preserved.

Initial integrated run: **2,012 tests / 9,627 assertions / 10 skips**, zero failures
or errors; **72 Chromium tests / 253 assertions**, zero failures/errors/skips.
Measured serial-suite coverage: **77.61% line (11,685/15,056)** and **61.53% branch
(2,714/4,411)**. These are earlier tranche results, not the final tested SHA.
The final integrated revision/results and remote CI/PR evidence are recorded below
when available. Local logs and raw coverage remain ignored; CI artifacts retain
revision-attributable results.

Checks already passed: full Ruby lint, Brakeman (zero active warnings/errors;
5 existing ignored warnings and one obsolete ignore entry), updated bundler audit,
importmap/npm audits, ordinary JS lint with negative probe, Playwright compatibility,
Zeitwerk in isolated environments, actionlint and whitespace checks. No security
ignores, financial snapshots, formulas or fixture expectations were weakened.

Independent review found a historical-publication compatibility regression; corrected
with tested legacy/current-PR/partial-tooling cases. Review also emphasized final
integrated concurrency/runtime evidence and actual remote Actions validation.

## Final pre-publication validation

Full integrated parallel run (two workers): **2,050 tests / 10,074 assertions /
10 existing skips**, no failures/errors. Chromium: **72 tests / 253 assertions**,
no failures/errors/skips. Parallel coverage aggregation explicitly reported the
main and two worker resultsets: **75.25% line (11,442/15,206)** and **62.82% branch
(2,687/4,277)**. Do not treat serial/parallel counts with different loaded-file
universes as a clean coverage trend. CI now retains the unit/integration artifact.

After the final reviewer suggestions, focused workflow regressions passed **9 tests /
100 assertions**, authentication **10 / 42**, docs checker **11 / 19**, and actual
PostgreSQL concurrency **1 / 12**. Full Ruby lint (**1,068 files**), root JS lint,
actionlint and whitespace checks passed. Reviewer found no remaining concrete blocker;
added both directions of partial-tooling compatibility tests and bounded the final
concurrency queue assertion. These final two test-only refinements follow the full
run above; exact committed-SHA CI and local closeout evidence are attached to the PR.

Existing skips, not added or suppressed here (owner: repository maintainer):

| Area | Count | Follow-up / restoration condition |
| --- | --- | --- |
| i18n maintenance | 4 | Establish translation/key policy and fix measured missing/unused/normalization/interpolation findings |
| AutoSync | 2 | Decide whether intentionally disabled feature is restored or tests replaced with disabled-behavior contracts |
| Assistant message retry | 1 | Reproduce retry flow and repair or document supported API contract |
| API resource-owner test placeholder | 1 | Replace placeholder with authenticated controller behavior assertion |
| Accounts OAuth scope | 1 | Reconcile invalid-scope token rejection with documented read/read_write contract, then enable negative test |
| Debt summary query performance | 1 | Correct obsolete fixture name and assert real query-shape/bounded-load contract with generated ledger |

## Remaining scope / risk disposition

- **R1 — mitigated, not closed universally:** demonstrated scopes and valuation
  preview fixed; sampled API/exports/assistant boundaries have tests/evidence. Complete
  route/job/impersonation boundary inventory remains a next-tranche task.
- **R2 — tested for supported lifecycle:** repeated/changed/failed/concurrent
  `run_simulation!` covered. Direct simulator calls and concurrent account-input
  changes remain outside the strategy-lock contract.
- **R3 — partially mitigated:** production Sidekiq known defaults removed. Full public
  proxy/TLS posture, CSP enforcement and operator exposure/restore drill remain open.
- **R4 — partially mitigated:** ProjectionCalculator replay seam added; no production
  caller behavior changed. Other model-backed calculators need incremental work.
- **R5 — unverified:** callback/job enqueue cost, provenance and retries need targeted
  inventory/measurements, not an automatic service-layer rewrite.
- **R6 — partially mitigated:** CI majors and publication identity made deliberate;
  real manual publication/image inspection remains follow-up, not Actions-emulator proof.
- **R7 — measured:** fresh suite and coverage evidence available; skip/ignore ownership
  and broader critical-path coverage work remain. Historical count differences are
  not assumed to mean removed skips; environment/mode and additions affect counts.
- **M5 — implemented with limits:** canonical guide/skills and adapter checks work;
  Claude/Cursor client auto-discovery and Windows symlink checkouts remain uncertified.
- Operator backup/restore of DB, stored files and encryption/configuration is not
  established by this sandbox test run. No compliance or production-readiness stamp.
