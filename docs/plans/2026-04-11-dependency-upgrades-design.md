# Dependency Upgrades Design

**Date:** April 11, 2026
**Scope:** 16 pending dependency upgrades (Tiers 1-3)
**Excludes:** Rails 8.0 upgrade (deferred to separate effort)

## Problem

The dependency upgrade report lists 16 pending upgrades across dependabot PRs. 12 have already been completed. The remaining items range from safe patch bumps to breaking major version changes (pagy 43, puma 7, rubyzip 3). We need a phased approach that ensures zero regressions.

## Approach: Phased Merges with Verification Gates

### Phase 1 — Tier 1: Safe Merges (10 PRs)

Merge via `gh pr merge`. Two batches:

**Batch A — Docker Actions (5 PRs):**
- docker/setup-buildx-action 3→4 (PR #17)
- docker/build-push-action 6→7 (PR #18)
- docker/login-action 3→4 (PR #19)
- docker/setup-qemu-action 3→4 (PR #20)
- docker/metadata-action 5→6 (PR #21)

**Batch B — Gem Patches (5 PRs):**
- sidekiq-cron 2.3.0→2.3.1 (PR #22)
- propshaft 1.1.0→1.3.1 (PR #24)
- i18n-tasks 1.0.15→1.1.2 (PR #25)
- jbuilder 2.13.0→2.14.1 (PR #29)
- logtail-rails 0.2.10→0.2.12 (PR #30)

**Gate:** `bundle install && bin/rails test`

### Phase 2 — Tier 2: Targeted Testing (3 PRs)

Merge one at a time via `gh pr merge`:

1. **faraday-retry 2.3.2→2.4.0** (PR #28) → `bin/rails test test/models/provider/`
2. **snaptrade 2.0.162→2.0.169** (PR #23) → `bin/rails test test/models/snaptrade_account/ test/controllers/snaptrade_connections_controller_test.rb`
3. **plaid 41.0.0→45.4.0** (PR #26) → `bin/rails test test/models/plaid_item/ test/controllers/plaid_connections_controller_test.rb`

**Gate:** Full `bin/rails test`

### Phase 3 — Tier 3: Breaking Changes (3 separate PRs)

Each gets its own branch and PR.

**3a. Puma 7 (PR #27)**
- Current `config/puma.rb` uses `preload_app!` and `plugin :tmp_restart` — both stable in Puma 7
- No `on_*` hooks found — no renaming needed
- Merge dependabot PR, verify `bin/rails server` starts cleanly
- Gate: `bin/rails test`

**3b. Rubyzip 3 (new branch — prior PR was closed)**
- Update Gemfile: `~> 2.3` → `~> 3.0`
- Verify `Zip::OutputStream.write_buffer` + `put_next_entry` + `write` pattern in `app/models/family/data_exporter.rb`
- Gate: `bin/rails test test/models/family/data_exporter_test.rb`

**3c. Pagy 43 (PR #31 as base)**
- Rewrite `config/initializers/pagy.rb`: `Pagy::DEFAULT` → `Pagy.options`, remove `require "pagy/extras/*"`
- Update `app/views/shared/_pagination.html.erb` for new API
- Verify all paginated controllers (accounts, transactions, API endpoints)
- Gate: `bin/rails test test/controllers/transactions_controller_test.rb test/controllers/accounts_controller_test.rb test/controllers/api/`

### Phase 4 — Final Verification

Full regression suite:
```bash
bin/rails test
bin/rails test:system
bin/rubocop
bin/brakeman
```

## Key Files

| File | Relevance |
|------|-----------|
| `config/puma.rb` | Puma 7 hook changes |
| `config/initializers/pagy.rb` | Pagy 43 config rewrite |
| `app/views/shared/_pagination.html.erb` | Pagy 43 view helpers |
| `app/models/family/data_exporter.rb` | Rubyzip 3 API changes |
| `Gemfile` | Version constraints for rubyzip, puma, rails |
| `.github/workflows/publish.yml` | Docker action versions |
