# Dependency Upgrade Report

**Created:** March 10, 2026
**Last Updated:** April 11, 2026
**Current Stack:** Rails 7.2.3 / Ruby 3.4.4 / PostgreSQL / Redis

All Tier 1-3 dependency upgrades are complete. Rails 8.0 (Tier 4) is deferred to a separate effort.

---

## Table of Contents

1. [Completed Upgrades](#completed-upgrades)
2. [Tier 4: Rails 8.0 Upgrade](#tier-4-rails-80-upgrade-deferred)
3. [Sources](#sources)

---

## Completed Upgrades

All 28 dependency upgrades across Tiers 1-3 have been merged. Verified with:
- 1853 unit/integration tests, 0 failures
- 72 system tests (Playwright), 0 failures
- RuboCop: 0 offenses
- Brakeman: 0 warnings

### GitHub Actions

| Dependency | From | To | PR |
|------------|------|----|-----|
| actions/checkout | 4 | 6 | merged pre-report |
| actions/setup-node | 4 | 6 | merged pre-report |
| actions/upload-artifact | 4 | 7 | merged pre-report |
| docker/build-push-action | 6 | 7 | #18 |
| docker/login-action | 3 | 4 | #19 |
| docker/metadata-action | 5 | 6 | #21 |
| docker/setup-buildx-action | 3 | 4 | #17 |
| docker/setup-qemu-action | 3 | 4 | #20 |

### Tier 1 — Safe Merges (no code changes)

| Dependency | From | To | PR |
|------------|------|----|-----|
| vcr | 6.3.1 | 6.4.0 | merged pre-report |
| vernier | 1.8.0 | 1.10.0 | merged pre-report |
| ruby-lsp-rails | 0.4.6 | 0.4.8 | merged pre-report |
| rack-mini-profiler | 4.0.0 | 4.0.1 | merged pre-report |
| bcrypt | 3.1.20 | 3.1.21 | merged pre-report |
| logtail-rails | 0.2.10 | 0.2.12 | #30 |
| jbuilder | 2.13.0 | 2.14.1 | #29 |
| i18n-tasks | 1.0.15 | 1.1.2 | #25 |
| propshaft | 1.1.0 | 1.3.1 | #24 |
| sidekiq-cron | 2.3.0 | 2.3.1 | #22 |

### Tier 2 — Required Test Verification

| Dependency | From | To | PR | Notes |
|------------|------|----|-----|-------|
| turbo-rails | 2.0.16 | 2.0.23 | merged pre-report | |
| lookbook | 2.3.11 | 2.3.14 | merged pre-report | |
| aasm | 5.5.1 | 5.5.2 | merged pre-report | |
| mocha | 2.7.1 | 3.0.2 | merged pre-report | Beyond target 3.0.1 |
| faraday-retry | 2.3.2 | 2.4.0 | #28 | |
| snaptrade | 2.0.162 | 2.0.178 | #23 | Beyond target 2.0.169 |
| plaid | 41.0.0 | 46.0.0 | #26 | Beyond target 45.4.0 |

### Tier 3 — Required Code Changes

| Dependency | From | To | PR | Notes |
|------------|------|----|-----|-------|
| puma | 6.6.0 | 7.2.0 | #27 | No code changes needed — no `on_*` hooks were in use |
| rubyzip | 2.4.1 | 3.2.2 | #33 | Gemfile constraint `~> 2.3` → `~> 3.0`. No code changes needed. |
| pagy | 9.3.5 | 43.3.1 | #34 | Major API migration (see below) |

#### Pagy 43 Migration Details

Code changes made in PR #34:
- `include Pagy::Backend` → `include Pagy::Method` (5 files)
- `include Pagy::Frontend` removed (integrated into `Pagy::Method`)
- `pagy_array(...)` → `pagy(:offset, ...)`
- `pagy_url_for(pagy, page)` → `pagy.page_url(page)`
- `pagy.prev` → `pagy.previous`
- `items:` param → `limit:` param
- `.vars[:items]` → `.limit`
- Overflow/array extras now built-in (removed `require` statements)
- `.series` is now protected — custom pagination partial uses `pagy.send(:series)` with `require "pagy/toolbox/helpers/support/series"`
- Model context (`GetTransactions`) passes dummy `request:` hash since models lack HTTP context
- Overflow behavior: pages beyond range return empty results (was `:last_page` redirect)

### CI Fix

| Issue | PR | Notes |
|-------|-----|-------|
| Playwright chromium-headless-shell | #35 | Playwright 1.58+ needs separate `chromium-headless-shell` binary for headless mode |

---

## Tier 4: Rails 8.0 Upgrade (Deferred)

### Current State

- **Rails:** 7.2.3 (`~> 7.2.2` in Gemfile)
- **Ruby:** 3.4.4 (Rails 8 requires 3.2+ — OK)
- **Config:** `config.load_defaults 7.2`
- **Prerequisite:** All Tier 1-3 upgrades are now complete

### Rails 8.0 Breaking Changes

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

| Blocker | Details |
|---------|---------|
| `connection_pool < 3.0` | Pinned due to Rails 7.2 RedisCacheStore bug. Rails 8 likely fixes this — remove pin and test. |
| `lucide-rails` fork | GitHub fork from maybe-finance. Verify it works with Rails 8 asset pipeline. |
| Doorkeeper 5.8.2 | Check if v6.x is needed for Rails 8 compatibility. |
| Hotwire stack | `turbo-rails`, `stimulus-rails` — verify latest versions are Rails 8 compatible. |
| `rails-settings-cached` | Verify Rails 8 compatibility. |

### Migration Steps

1. Update Gemfile: `"~> 7.2.2"` → `"~> 8.0.0"`
2. Run `rails app:update` — review generated diffs carefully
3. Update `config.load_defaults 7.2` → `8.0`
4. Remove `connection_pool < 3.0` pin and test Redis caching
5. Remove any deprecated config options listed above
6. Grep for `form_with model: nil` patterns and fix
7. Run full test suite
8. Test Sidekiq, cron jobs, Plaid/SnapTrade flows, exports

---

## Sources

- [Pagy Upgrade to 43 Guide](https://ddnexus.github.io/pagy/guides/upgrade-guide/)
- [RubyZip Updating to 3.x](https://github.com/rubyzip/rubyzip/wiki/Updating-to-version-3.x)
- [Puma Releases](https://github.com/puma/puma/releases)
- [Plaid Ruby SDK Changelog](https://github.com/plaid/plaid-ruby/blob/master/CHANGELOG.md)
- [Rails 8.0 Upgrade Guide](https://www.fastruby.io/blog/upgrade-rails-7-2-to-8-0.html)
- [Rails 8.0 Release Notes](https://edgeguides.rubyonrails.org/8_0_release_notes.html)
