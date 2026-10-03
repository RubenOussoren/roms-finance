# Dependency security baseline — October 3, 2026

The subsequent 12-PR non-security queue is tracked separately in
[the maintenance resolution report](dependency-maintenance-2026-10.md), including
the updated regression-test baseline. The original security results below remain
historical evidence rather than being overwritten by maintenance upgrades.

## Inventory and resolution

The refreshed starting inventory contained 24 open Dependabot PRs and 29 open
GitHub vulnerability alerts: one critical, six high, ten medium, and twelve low.
All alerts referred to `Gemfile.lock`. Old passing PR checks were not treated as
validation against the merged sandbox stabilization baseline (PR #87).

Changes were rebuilt on dedicated branches in focused batches, retaining the
reviewed Dependabot target versions and avoiding unrelated resolver updates.
Each batch passed full local unit/integration and browser suites and fresh GitHub
CI before merging. Original Dependabot PRs were closed with links to their
validated replacements, rather than merging stale lockfiles.

| Batch | Replacement | Dependabot PRs covered |
| --- | --- | --- |
| Rails 8.1.3.1 critical Active Storage fix | [#89](https://github.com/RubenOussoren/roms-finance/pull/89) | #84 |
| rubyzip, WebSocket driver, Faraday, concurrent-ruby | [#90](https://github.com/RubenOussoren/roms-finance/pull/90) | #82, #74, #75; rubyzip had no existing PR |
| Nokogiri, Loofah, HTML sanitizer, Crass | [#92](https://github.com/RubenOussoren/roms-finance/pull/92) | #73, #81, #83 |
| ViewComponent, CSS parser, YARD | [#93](https://github.com/RubenOussoren/roms-finance/pull/93) | #78, #77, #76 |
| Mail, Pagy, MessagePack | [#94](https://github.com/RubenOussoren/roms-finance/pull/94) | #86, #65, #85 |
| RubyLLM 2.0 security/API migration | [#91](https://github.com/RubenOussoren/roms-finance/pull/91) | #69 |
| Routine Ruby maintenance | [#95](https://github.com/RubenOussoren/roms-finance/pull/95) | #71, #70, #68, #67, #66, #64, #63, #62 |
| Checkout/setup-node v7 and Node 22 CI | [#88](https://github.com/RubenOussoren/roms-finance/pull/88) | #72, #80 |

The independent, freshly updated `ruby-advisory-db` audit found additional Crass
advisories and a RubyLLM high-severity advisory that GitHub's initial inventory
omitted. These were resolved too; **RubyLLM 1.16.0 was not a security fix**.
See [the RubyLLM migration notes](ruby-llm-security-upgrade.md) for its API changes
and regression coverage. No database migration or new environment variable was
introduced by these upgrades.

## Verification baseline

- Stabilized main before dependency changes: **1,922 unit/integration tests,
  9,135 assertions, zero failures/errors, 16 existing skips**.
- Integrated dependency baseline: **1,933 unit/integration tests, 9,176 assertions,
  zero failures/errors, the same 16 skips**. Eleven RubyLLM regression tests were
  added; no existing tests were disabled to make an upgrade pass.
- Both baselines: **72 Chromium browser tests, 253 assertions, zero
  failures/errors/skips**.
- Ruby and JavaScript lint, Brakeman, Zeitwerk eager-load checks, updated Ruby
  advisory audit, importmap audit, and npm audit are part of final verification.
- Local tests use separate Compose services, database/Redis volumes, and bundle
  cache, with `RAILS_ENV=test POSTGRES_DB=roms_test
  REDIS_URL=redis://redis:6379/2`. The live sandbox's development data is never
  used for tests. Follow the [README sandbox verification commands](../README.md#sandbox-verification).

## Keeping the baseline reliable

CI checks application code with Brakeman **and** locked Ruby dependencies with
`bundle exec bundler-audit check --update`; these are different checks. JavaScript
security checks cover both importmap and npm dependencies. npm installation uses
`npm ci` rather than resolving a new lockfile during lint. Dependabot monitors
Bundler, npm, and GitHub Actions weekly.

Do not suppress a new audit failure merely to make CI green. Refresh the advisory
inventory, identify patched versions and overlapping PRs, and reproduce test
failures on unchanged main before attributing them to an upgrade. External audit
services can fail transiently; retry and investigate without bypassing the gate.

The clean audit is a dated dependency-security result, not a claim that the entire
application or every optional provider is vulnerability-free. Existing Brakeman
suppressions and the 16 test skips remain separate review items. Provider tests
use deterministic/stubbed HTTP; no live-provider credentials were required.
