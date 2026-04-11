# Dependency Upgrade Report

**Created:** March 10, 2026
**Last Updated:** April 11, 2026
**Current Stack:** Rails 7.2.3 / Ruby 3.4.4 / PostgreSQL / Redis

This report assesses all pending dependabot upgrades and the Rails 8.0 upgrade path. Each dependency is categorized by risk level with specific code changes required.

---

## Table of Contents

1. [Completed Upgrades](#completed-upgrades)
2. [Summary Matrix — Remaining](#summary-matrix--remaining)
3. [Tier 1: Merge Immediately](#tier-1-merge-immediately-no-code-changes)
4. [Tier 2: Merge After Test Suite](#tier-2-merge-after-running-test-suite)
5. [Tier 3: Requires Code Changes](#tier-3-requires-code-changes-before-merge)
6. [Tier 4: Rails 8.0 Upgrade](#tier-4-rails-80-upgrade)
7. [Recommended Upgrade Order](#recommended-upgrade-order)

---

## Completed Upgrades

The following 12 upgrades from the original report have been merged:

| Dependency | From | To | Tier |
|------------|------|----|------|
| actions/checkout | 4 | 6 | 1 |
| actions/setup-node | 4 | 6 | 1 |
| actions/upload-artifact | 4 | 7 | 1 |
| vcr | 6.3.1 | 6.4.0 | 1 |
| vernier | 1.8.0 | 1.10.0 | 1 |
| ruby-lsp-rails | 0.4.6 | 0.4.8 | 1 |
| rack-mini-profiler | 4.0.0 | 4.0.1 | 1 |
| bcrypt | 3.1.20 | 3.1.21 | 1 |
| turbo-rails | 2.0.16 | 2.0.23 | 2 |
| lookbook | 2.3.11 | 2.3.14 | 2 |
| aasm | 5.5.1 | 5.5.2 | 2 |
| mocha | 2.7.1 | 3.0.2 | 2 |

---

## Summary Matrix — Remaining

| Dependency | Current | Target | Risk | Tier | PR # | Gemfile Constraint |
|------------|---------|--------|------|------|------|--------------------|
| docker/build-push-action | 6 | 7 | None | 1 | #18 | N/A |
| docker/login-action | 3 | 4 | None | 1 | #19 | N/A |
| docker/metadata-action | 5 | 6 | None | 1 | #21 | N/A |
| docker/setup-buildx-action | 3 | 4 | None | 1 | #17 | N/A |
| docker/setup-qemu-action | 3 | 4 | None | 1 | #20 | N/A |
| logtail-rails | 0.2.10 | 0.2.12 | None | 1 | #30 | unpinned |
| jbuilder | 2.13.0 | 2.14.1 | None | 1 | #29 | unpinned |
| i18n-tasks | 1.0.15 | 1.1.2 | None | 1 | #25 | unpinned |
| propshaft | 1.1.0 | 1.3.1 | None | 1 | #24 | unpinned |
| sidekiq-cron | 2.3.0 | 2.3.1 | Low | 1 | #22 | unpinned |
| faraday-retry | 2.3.2 | 2.4.0 | Low | 2 | #28 | unpinned |
| snaptrade | 2.0.162 | 2.0.169 | Medium | 2 | #23 | `~> 2.0` |
| plaid | 41.0.0 | 45.4.0 | Medium | 2 | #26 | unpinned |
| puma | 6.6.0 | 7.2.0 | **High** | 3 | #27 | `>= 5.0` |
| rubyzip | 2.4.1 | 3.2.2 | **High** | 3 | closed | `~> 2.3` (blocks) |
| pagy | 9.3.5 | 43.3.1 | **Critical** | 3 | #31 | unpinned |
| **Rails** | **7.2.3** | **8.0.x** | **High** | 4 | — | `~> 7.2.2` |

---

## Tier 1: Merge Immediately (No Code Changes)

These are safe to merge without any code modifications.

### GitHub Actions (5 branches)

All standard GitHub-maintained actions with no app code impact:

- `docker/build-push-action` 6 → 7 (PR #18)
- `docker/login-action` 3 → 4 (PR #19)
- `docker/metadata-action` 5 → 6 (PR #21)
- `docker/setup-buildx-action` 3 → 4 (PR #17)
- `docker/setup-qemu-action` 3 → 4 (PR #20)

**Action:** Merge all 5 branches.

### Low-Risk Production Gems (5 branches)

Patch bumps with minimal API surface:

- **logtail-rails** 0.2.10 → 0.2.12 — Logging service, patch bump. (PR #30)
- **jbuilder** 2.13.0 → 2.14.1 — JSON template builder, patch bump. (PR #29)
- **i18n-tasks** 1.0.15 → 1.1.2 — i18n linting (dev only). (PR #25)
- **propshaft** 1.1.0 → 1.3.1 — Asset pipeline, minor bump. No config changes needed. (PR #24)
- **sidekiq-cron** 2.3.0 → 2.3.1 — 3 cron jobs in `config/schedule.yml`. Patch bump, no API changes. (PR #22)

**Action:** Merge all 5 branches.

---

## Tier 2: Merge After Running Test Suite

These should be safe but warrant running `bin/rails test` after merge to confirm.

### faraday-retry (2.3.2 → 2.4.0) — LOW RISK (PR #28)

Minor bump. Single direct usage in `Provider::AlphaVantage` with standard retry config (`max: 2, interval: 0.05`). Also used internally by SnapTrade and Plaid SDKs.

**Verification:** `bin/rails test test/models/provider/`

### snaptrade (2.0.162 → 2.0.169) — MEDIUM RISK (PR #23)

7 patch increments within 2.0.x. SDK method signatures should be stable but SnapTrade SDK has a history of subtle changes. Used in `Provider::SnapTrade` (122 lines) with 9 SDK method calls.

**Key files:** `app/models/provider/snaptrade.rb`, `app/models/snaptrade_account/`

**Verification:**
```bash
bin/rails test test/controllers/snaptrade_connections_controller_test.rb
bin/rails test test/models/snaptrade_account/
bin/rails test test/controllers/webhooks_controller_test.rb
```

### plaid (41.0.0 → 45.4.0) — MEDIUM RISK (PR #26)

4 major version bumps, but the Plaid Ruby SDK is auto-generated from the OpenAPI spec — "major" versions track API releases, not breaking Ruby API changes. The core patterns (`Plaid::*Request.new(...)`, `client.method(request)`, `Plaid::ApiError`) remain stable across these versions.

**Breaking changes between v41-v45:**
- Removed deprecated `longest_gap_between_transactions`, `average_inflow_amount`, `average_outflow_amount` fields (not used in ROMS)
- Some `number` types changed to `integer` (minor, Ruby handles both)
- `PlaidCheckScore.score` changed from float to integer (not used in ROMS)

**Key files:** `app/models/provider/plaid.rb` (213 lines), `config/initializers/plaid.rb`

**Verification:**
```bash
bin/rails test test/models/provider/plaid_test.rb
bin/rails test test/models/plaid_item/
bin/rails test test/controllers/plaid_connections_controller_test.rb
```

---

## Tier 3: Requires Code Changes Before Merge

These have confirmed breaking changes that require code modifications.

### pagy (9.3.5 → 43.3.1) — CRITICAL: Complete API Redesign (PR #31)

Pagy 43 is a **complete overhaul** (the "Leaping Gem" release). The version jump from 9 to 43 signals this is not incremental — it's a rewrite.

**Breaking changes:**
1. `Pagy::DEFAULT[...]` → `Pagy.options[...]`
2. Extras system removed entirely (ROMS uses `overflow` and `array` extras)
3. `Pagy::OverflowError` → `Pagy::RangeError` (no longer raised by default)
4. `pagy_url_for(pagy, page_num)` — signature may have changed
5. `pagy.series` — structure changed
6. Initializer format completely different

**Files requiring changes:**

| File | Change Required |
|------|----------------|
| `config/initializers/pagy.rb` | Rewrite: `Pagy::DEFAULT` → `Pagy.options`, remove extras |
| `app/views/shared/_pagination.html.erb` | Update: `pagy_url_for`, `.series`, `.prev`/`.next` calls |
| `app/controllers/accounts_controller.rb` | Verify `pagy()` call signature |
| `app/controllers/transactions_controller.rb` | Verify `pagy()` call signature |
| `app/controllers/api/v1/transactions_controller.rb` | Verify `pagy()` with `page:`, `limit:` |
| `app/controllers/api/v1/accounts_controller.rb` | Verify `pagy()` with `page:`, `limit:` |
| `app/models/assistant/function/get_transactions.rb` | Verify pagy usage in AI function |

**Migration steps:**
1. Read the official [Upgrade to 43 Guide](https://ddnexus.github.io/pagy/guides/upgrade-guide/)
2. Rename `config/initializers/pagy.rb` → `pagy-old.rb`
3. Create new `config/initializers/pagy.rb` with `Pagy.options` syntax
4. Update `_pagination.html.erb` partial for new view helper API
5. Test all paginated views (transactions list, accounts list, API endpoints)

**Verification:**
```bash
bin/rails test test/controllers/transactions_controller_test.rb
bin/rails test test/controllers/accounts_controller_test.rb
bin/rails test test/controllers/api/
# Manual: browse transaction/account lists, test pagination links
```

### puma (6.6.0 → 7.2.0) — HIGH RISK: Hook Name Changes (PR #27)

Puma 7 renames lifecycle hooks from `on_*` to `after_*`.

**Files requiring changes:**

| File | Change Required |
|------|----------------|
| `config/puma.rb` | Check for `on_*` hooks → rename to `after_*` |

**Current config uses:** `threads`, `workers`, `preload_app!`, `plugin :tmp_restart`, `worker_timeout`, `port`, `environment`, `pidfile`. The `plugin :tmp_restart` plugin needs verification for Puma 7 compatibility.

**Migration steps:**
1. Review `config/puma.rb` for any `on_worker_boot`, `on_booted`, etc. hooks
2. Rename `on_*` → `after_*` if present
3. Verify `plugin :tmp_restart` still works
4. Test in development with `bin/rails server`

**Verification:**
```bash
bin/rails server  # verify startup without errors
# Load test with concurrent requests to verify thread pool
```

### rubyzip (2.4.1 → 3.2.2) — HIGH RISK: API Parameter Changes + Gemfile Block (no open PR)

**Note:** The dependabot PR for this upgrade was closed. The branch `dependabot/bundler/rubyzip-3.2.2` still exists in the remote.

**Gemfile constraint `~> 2.3` blocks this upgrade.** Must change to `~> 3.0`.

**Breaking changes in RubyZip 3.0:**
1. Methods now use **named parameters** instead of positional
2. `Zip::File.open(file, offset)` → `Zip::File.open(file, offset: 0)`
3. `Entry#initialize` uses explicit named parameters
4. `File::add_buffer` removed
5. `GPFBit3Error` renamed to `StreamingError`
6. Zip64 enabled by default
7. Path traversal protection now enforced by default on extraction
8. Requires Ruby 3.0+ (ROMS uses 3.4.4 — OK)

**Files requiring changes:**

| File | Change Required |
|------|----------------|
| `Gemfile` | Change `"~> 2.3"` → `"~> 3.0"` |
| `app/models/family/data_exporter.rb` | Verify `Zip::OutputStream.write_buffer` + `put_next_entry` + `write` |
| `test/models/family/data_exporter_test.rb` | Verify `Zip::File.open_buffer` + `.entries` + `.read` |

**Migration steps:**
1. Update Gemfile constraint
2. Review [Updating to version 3.x](https://github.com/rubyzip/rubyzip/wiki/Updating-to-version-3.x) wiki
3. Test `Zip::OutputStream.write_buffer` block pattern (likely unchanged)
4. Test `Zip::File.open_buffer` in test (may need named params)

**Verification:**
```bash
bin/rails test test/models/family/data_exporter_test.rb
# Manual: export data from Settings → Data Export and verify ZIP downloads correctly
```

---

## Tier 4: Rails 8.0 Upgrade

### Current State

- **Rails:** 7.2.3 (`~> 7.2.2` in Gemfile)
- **Ruby:** 3.4.4 (Rails 8 requires 3.2+ — OK)
- **Config:** `config.load_defaults 7.2`

### Rails 8.0 Breaking Changes

Rails 8.0 is described as "the smoothest upgrade" with very few breaking changes:

1. **Removed deprecated configs:**
   - `config.active_record.commit_transaction_on_non_local_return`
   - `config.active_record.allow_deprecated_singular_associations_name`
   - `config.action_controller.allow_deprecated_parameters_hash_equality`
   - `config.active_record.warn_on_records_fetched_greater_than`
   - `config.active_record.sqlite3_deprecated_warning`
   - `ActiveRecord::ConnectionAdapters::ConnectionPool#connection`

2. **View changes:**
   - Passing `nil` to `model:` in `form_with` no longer supported
   - Passing content to void tag elements in tag builder no longer supported

3. **New defaults in `config.load_defaults 8.0`**

### Blockers to Investigate

| Blocker | Details | Action |
|---------|---------|--------|
| `connection_pool < 3.0` | Pinned due to Rails 7.2 RedisCacheStore bug. Rails 8 likely fixes this — remove pin and test. |
| `lucide-rails` fork | GitHub fork from maybe-finance. Verify it works with Rails 8 asset pipeline. |
| Doorkeeper 5.8.2 | Check if v6.x is needed for Rails 8 compatibility. |
| Hotwire stack | `turbo-rails`, `stimulus-rails` — verify latest versions are Rails 8 compatible. |
| `rails-settings-cached` | Verify Rails 8 compatibility. |

### Migration Steps

1. **Complete Tier 1-3 upgrades first** — get all dependencies current
2. Update Gemfile: `"~> 7.2.2"` → `"~> 8.0.0"`
3. Run `rails app:update` — review generated diffs carefully
4. Update `config.load_defaults 7.2` → `8.0`
5. Remove `connection_pool < 3.0` pin and test Redis caching
6. Remove any deprecated config options listed above
7. Grep for `form_with model: nil` patterns and fix
8. Run full test suite
9. Test Sidekiq, cron jobs, Plaid/SnapTrade flows, exports

### Verification

```bash
bin/rails test              # full unit/integration suite
bin/rails test:system       # system tests with Playwright
bin/rubocop                 # linting
bin/brakeman                # security scan
# Manual: test account linking (Plaid + SnapTrade), data export, AI chat
```

---

## Recommended Upgrade Order

### Phase 1: Quick Wins — Remaining (10 branches)

Merge remaining Tier 1 branches:

```bash
# GitHub Actions (5)
gh pr merge 17 --merge  # docker/setup-buildx-action v4
gh pr merge 18 --merge  # docker/build-push-action v7
gh pr merge 19 --merge  # docker/login-action v4
gh pr merge 20 --merge  # docker/setup-qemu-action v4
gh pr merge 21 --merge  # docker/metadata-action v6

# Low-risk production gems (5)
gh pr merge 22 --merge  # sidekiq-cron 2.3.1
gh pr merge 24 --merge  # propshaft 1.3.1
gh pr merge 25 --merge  # i18n-tasks 1.1.2
gh pr merge 29 --merge  # jbuilder 2.14.1
gh pr merge 30 --merge  # logtail-rails 0.2.12

# Run tests to confirm
bundle install && bin/rails test
```

### Phase 2: Tier 2 Gems (1-2 hours)

Merge one at a time, running tests after each:

1. `faraday-retry` (PR #28) → `bin/rails test test/models/provider/`
2. `snaptrade` (PR #23) → `bin/rails test test/models/snaptrade_account/`
3. `plaid` (PR #26) → `bin/rails test test/models/plaid_item/`

### Phase 3: Tier 3 Code Changes (half day)

Each requires a dedicated branch with code changes:

1. **puma 7** (PR #27) — Update `config/puma.rb` hooks, test server startup
2. **rubyzip 3** (no open PR) — Update Gemfile constraint, verify export API compatibility
3. **pagy 43** (PR #31) — Most effort. Rewrite initializer, update pagination partial, test all paginated views

### Phase 4: Rails 8.0

Only after all gems are updated. Follow the migration steps above.

---

## Sources

- [Pagy Upgrade to 43 Guide](https://ddnexus.github.io/pagy/guides/upgrade-guide/)
- [Pagy 9.1 to 43.0 Changes](https://dev.to/jessalejo/pagy-91-to-430-what-have-changed-2933)
- [RubyZip Updating to 3.x](https://github.com/rubyzip/rubyzip/wiki/Updating-to-version-3.x)
- [Puma Releases](https://github.com/puma/puma/releases)
- [Puma 7 Hook Changes](https://github.com/rails/solid_queue/issues/633)
- [Plaid Ruby SDK Changelog](https://github.com/plaid/plaid-ruby/blob/master/CHANGELOG.md)
- [Mocha 3.0 Release Notes](https://mocha.jamesmead.org/file.RELEASE.html)
- [Rails 8.0 Upgrade Guide](https://www.fastruby.io/blog/upgrade-rails-7-2-to-8-0.html)
- [Rails 8.0 Release Notes](https://edgeguides.rubyonrails.org/8_0_release_notes.html)
- [Rails Upgrading Guide](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html)
