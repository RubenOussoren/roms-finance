# Dependency Upgrades Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Upgrade all 16 pending dependencies (Tiers 1-3) with zero regressions, deferring Rails 8 to a separate effort.

**Architecture:** Phased approach — merge safe dependabot PRs via `gh pr merge` (Tiers 1-2), then create separate branches with code changes for breaking upgrades (Tier 3: puma 7, rubyzip 3, pagy 43). Each phase has a verification gate before proceeding.

**Tech Stack:** Rails 7.2.3, Ruby 3.4.4, Minitest, GitHub CLI (`gh`)

---

## Task 1: Merge Tier 1 — Docker Actions (Batch A)

**Files:** `.github/workflows/publish.yml` (modified by dependabot PRs)

**Step 1: Merge all 5 Docker action PRs**

```bash
gh pr merge 17 --merge --delete-branch  # docker/setup-buildx-action 3→4
gh pr merge 18 --merge --delete-branch  # docker/build-push-action 6→7
gh pr merge 19 --merge --delete-branch  # docker/login-action 3→4
gh pr merge 20 --merge --delete-branch  # docker/setup-qemu-action 3→4
gh pr merge 21 --merge --delete-branch  # docker/metadata-action 5→6
```

**Step 2: Pull changes locally**

```bash
git pull origin main
```

**Step 3: Verify workflow file has updated versions**

```bash
grep -E 'docker/' .github/workflows/publish.yml | head -10
```

Expected: All docker actions at v4/v6/v7 (no v3/v5/v6 references for the upgraded ones).

**Step 4: Commit checkpoint — no code changes needed**

No commit needed; these are merged PRs.

---

## Task 2: Merge Tier 1 — Gem Patches (Batch B)

**Files:** `Gemfile.lock` (modified by dependabot PRs)

**Step 1: Merge all 5 gem patch PRs**

```bash
gh pr merge 22 --merge --delete-branch  # sidekiq-cron 2.3.0→2.3.1
gh pr merge 24 --merge --delete-branch  # propshaft 1.1.0→1.3.1
gh pr merge 25 --merge --delete-branch  # i18n-tasks 1.0.15→1.1.2
gh pr merge 29 --merge --delete-branch  # jbuilder 2.13.0→2.14.1
gh pr merge 30 --merge --delete-branch  # logtail-rails 0.2.10→0.2.12
```

**Step 2: Pull and install**

```bash
git pull origin main
bundle install
```

**Step 3: Run full test suite as Tier 1 gate**

```bash
bin/rails test
```

Expected: All tests pass (currently ~1500 tests, 0 failures).

---

## Task 3: Merge Tier 2 — faraday-retry

**Files:** `Gemfile.lock`

**Step 1: Merge PR**

```bash
gh pr merge 28 --merge --delete-branch  # faraday-retry 2.3.2→2.4.0
git pull origin main
bundle install
```

**Step 2: Run targeted tests**

```bash
bin/rails test test/models/provider/
```

Expected: All provider tests pass. faraday-retry is used in `Provider::AlphaVantage` with standard retry config (`max: 2, interval: 0.05`). Also used internally by SnapTrade and Plaid SDKs.

---

## Task 4: Merge Tier 2 — snaptrade

**Files:** `Gemfile.lock`

**Step 1: Merge PR**

```bash
gh pr merge 23 --merge --delete-branch  # snaptrade 2.0.162→2.0.169
git pull origin main
bundle install
```

**Step 2: Run targeted tests**

```bash
bin/rails test test/models/snaptrade_account/
bin/rails test test/controllers/snaptrade_connections_controller_test.rb
bin/rails test test/controllers/webhooks_controller_test.rb
```

Expected: All pass. SDK is 7 patch increments within 2.0.x — method signatures should be stable.

---

## Task 5: Merge Tier 2 — plaid

**Files:** `Gemfile.lock`

**Step 1: Merge PR**

```bash
gh pr merge 26 --merge --delete-branch  # plaid 41.0.0→45.4.0
git pull origin main
bundle install
```

**Step 2: Run targeted tests**

```bash
bin/rails test test/models/provider/plaid_test.rb
bin/rails test test/models/plaid_item/
bin/rails test test/controllers/plaid_connections_controller_test.rb
```

Expected: All pass. Plaid SDK is auto-generated from OpenAPI spec — "major" versions track API releases, not breaking Ruby changes. Core patterns (`Plaid::*Request.new(...)`, `client.method(request)`, `Plaid::ApiError`) remain stable.

**Step 3: Run full test suite as Tier 2 gate**

```bash
bin/rails test
```

Expected: All ~1500 tests pass.

---

## Task 6: Upgrade Puma 6→7 (Tier 3a)

**Files:**
- Modify: `config/puma.rb` (verify, likely no changes needed)
- Modify: `Gemfile.lock` (via dependabot PR)

**Step 1: Merge the dependabot PR**

```bash
gh pr merge 27 --merge --delete-branch  # puma 6.6.0→7.2.0
git pull origin main
bundle install
```

**Step 2: Verify no `on_*` hooks exist (they should have been renamed to `after_*` in Puma 7)**

```bash
grep -n 'on_worker_boot\|on_booted\|on_restart\|on_refork' config/puma.rb
```

Expected: No matches. Current config uses only `preload_app!`, `plugin :tmp_restart`, `threads`, `workers`, `port`, `environment`, `pidfile`, `worker_timeout` — all stable in Puma 7.

**Step 3: Verify server starts**

```bash
timeout 10 bin/rails server 2>&1 || true
```

Expected: Server boots without errors. Look for "Listening on" or "Puma starting" message.

**Step 4: Run test suite**

```bash
bin/rails test
```

Expected: All tests pass.

---

## Task 7: Upgrade Rubyzip 2→3 (Tier 3b)

**Files:**
- Modify: `Gemfile:74` — change `gem "rubyzip", "~> 2.3"` → `gem "rubyzip", "~> 3.0"`
- Verify: `app/models/family/data_exporter.rb` — uses `Zip::OutputStream.write_buffer`, `put_next_entry`, `write`
- Test: `test/models/family/data_exporter_test.rb` — uses `Zip::File.open_buffer`, `.entries`, `.read`

**Step 1: Create upgrade branch**

```bash
git checkout -b upgrade/rubyzip-3
```

**Step 2: Update Gemfile constraint**

Change line 74 in `Gemfile`:
```ruby
# Before:
gem "rubyzip", "~> 2.3"

# After:
gem "rubyzip", "~> 3.0"
```

**Step 3: Install and verify resolution**

```bash
bundle install
```

Expected: Resolves to rubyzip 3.2.2 (or latest 3.x). If dependency conflicts arise, check if any other gem pins rubyzip < 3.

**Step 4: Run data exporter tests**

```bash
bin/rails test test/models/family/data_exporter_test.rb
```

Expected: All pass. The app uses standard patterns:
- Production: `Zip::OutputStream.write_buffer { |zf| zf.put_next_entry("name"); zf.write(data) }` — stable in v3
- Tests: `Zip::File.open_buffer(data) { |zip| zip.entries; zip.read("name") }` — stable in v3

**Step 5: Run full test suite**

```bash
bin/rails test
```

Expected: All tests pass.

**Step 6: Commit and create PR**

```bash
git add Gemfile Gemfile.lock
git commit -m "Upgrade rubyzip from 2.x to 3.x

Breaking changes in rubyzip 3.0:
- Methods now use named parameters instead of positional
- Zip64 enabled by default
- Path traversal protection enforced by default

Our usage (Zip::OutputStream.write_buffer + put_next_entry/write in
data_exporter.rb) is compatible with v3 without code changes.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

**Step 7: Push and create PR**

```bash
git push -u origin upgrade/rubyzip-3
gh pr create --title "Upgrade rubyzip 2.x → 3.x" --body "$(cat <<'EOF'
## Summary
- Updates rubyzip from ~> 2.3 to ~> 3.0
- No code changes needed — our usage patterns (write_buffer, put_next_entry, open_buffer) are stable across versions
- Gemfile constraint was the only blocker

## Test plan
- [x] `bin/rails test test/models/family/data_exporter_test.rb` passes
- [x] `bin/rails test` full suite passes
- [ ] Manual: Settings → Data Export → verify ZIP downloads correctly

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Task 8: Upgrade Pagy 9→43 (Tier 3c)

This is the largest upgrade. Pagy 43 is a complete API redesign.

**Files:**
- Modify: `config/initializers/pagy.rb` — rewrite config
- Modify: `app/controllers/application_controller.rb:6` — `Pagy::Backend` → `Pagy::Method`
- Modify: `app/controllers/api/v1/accounts_controller.rb:4` — `Pagy::Backend` → `Pagy::Method`
- Modify: `app/controllers/api/v1/transactions_controller.rb:4` — `Pagy::Backend` → `Pagy::Method`
- Modify: `app/controllers/api/v1/chats_controller.rb:4` — `Pagy::Backend` → `Pagy::Method`
- Modify: `app/helpers/application_helper.rb:2` — remove `include Pagy::Frontend`
- Modify: `app/models/assistant/function/get_transactions.rb:2` — `Pagy::Backend` → `Pagy::Method`
- Modify: `app/controllers/import/cleans_controller.rb:15` — `pagy_array(...)` → `pagy(:offset, ...)`
- Modify: `app/views/shared/_pagination.html.erb` — `pagy_url_for` → `pagy.page_url`, `.prev` → `.previous`
- Modify: `app/views/api/v1/chats/index.json.jbuilder:15` — `.vars[:items]` → `.options[:items]`
- Modify: `app/views/api/v1/chats/show.json.jbuilder:29` — `.vars[:items]` → `.options[:items]`
- Test: `test/controllers/transactions_controller_test.rb`, `test/controllers/accounts_controller_test.rb`, `test/controllers/api/`

**Step 1: Create upgrade branch from the dependabot PR**

```bash
git checkout -b upgrade/pagy-43
git merge origin/dependabot/bundler/pagy-43.3.1
bundle install
```

**Step 2: Rewrite the initializer**

Replace `config/initializers/pagy.rb` with:

```ruby
# Pagy 43+ — overflow and array extras are built-in
# overflow: pages beyond range return empty results by default (no config needed)
# array: use pagy(:offset, array) instead of pagy_array(array)
```

The old config was:
```ruby
require "pagy/extras/overflow"
require "pagy/extras/array"
Pagy::DEFAULT[:overflow] = :last_page
```

In pagy 43, `overflow` is built-in (returns empty page by default), and `array` is handled via `pagy(:offset, array)`. The `overflow: :last_page` behavior is no longer available as a built-in option — the new default (empty page) is safer.

**Step 3: Run tests to see what breaks**

```bash
bin/rails test 2>&1 | tail -20
```

Expected: Failures related to `Pagy::Backend`, `pagy_url_for`, `pagy_array`, `.vars`.

**Step 4: Update Backend/Frontend includes**

In `app/controllers/application_controller.rb` line 6:
```ruby
# Before:
include Pagy::Backend
# After:
include Pagy::Method
```

In `app/controllers/api/v1/accounts_controller.rb` line 4:
```ruby
# Before:
include Pagy::Backend
# After:
include Pagy::Method
```

In `app/controllers/api/v1/transactions_controller.rb` line 4:
```ruby
# Before:
include Pagy::Backend
# After:
include Pagy::Method
```

In `app/controllers/api/v1/chats_controller.rb` line 4:
```ruby
# Before:
include Pagy::Backend
# After:
include Pagy::Method
```

In `app/models/assistant/function/get_transactions.rb` line 2:
```ruby
# Before:
include Pagy::Backend
# After:
include Pagy::Method
```

In `app/helpers/application_helper.rb` line 2:
```ruby
# Before:
include Pagy::Frontend
# After:
# (remove this line entirely — Frontend is integrated into Pagy::Method)
```

**Step 5: Update `pagy_array` → `pagy(:offset, ...)`**

In `app/controllers/import/cleans_controller.rb` line 15:
```ruby
# Before:
@pagy, @rows = pagy_array(rows, limit: params[:per_page] || "10")
# After:
@pagy, @rows = pagy(:offset, rows, limit: params[:per_page] || "10")
```

**Step 6: Update `items:` → `limit:` in ChatsController**

In `app/controllers/api/v1/chats_controller.rb` lines 11, 16:
```ruby
# Before:
@pagy, @chats = pagy(Current.user.chats.ordered, items: 20)
@pagy, @messages = pagy(@chat.messages.ordered, items: 50)
# After:
@pagy, @chats = pagy(Current.user.chats.ordered, limit: 20)
@pagy, @messages = pagy(@chat.messages.ordered, limit: 50)
```

**Step 7: Update `.vars[:items]` → `.limit` in jbuilder templates**

In `app/views/api/v1/chats/index.json.jbuilder` line 15:
```ruby
# Before:
json.per_page @pagy.vars[:items]
# After:
json.per_page @pagy.limit
```

In `app/views/api/v1/chats/show.json.jbuilder` line 29:
```ruby
# Before:
json.per_page @pagy.vars[:items]
# After:
json.per_page @pagy.limit
```

**Step 8: Update the pagination partial**

Replace `app/views/shared/_pagination.html.erb` with:

```erb
<%# locals: (pagy:) %>

<nav class="flex w-full items-center justify-between">
  <div class="flex items-center gap-1">
    <div>
      <% if pagy.previous %>
        <%= link_to pagy.page_url(pagy.previous),
              data: { turbo_frame: :_top },
              class: "inline-flex items-center p-2 text-sm font-medium text-secondary bg-container-inset hover:border-secondary hover:text-secondary" do %>
          <%= icon("chevron-left") %>
        <% end %>
      <% else %>
        <div class="inline-flex items-center p-2 text-sm font-medium hover:border-secondary">
          <%= icon("chevron-left") %>
        </div>
      <% end %>
    </div>
    <div class="rounded-xl p-1 bg-container-inset">
      <% pagy.series.each do |series_item| %>
        <% if series_item.is_a?(Integer) %>
          <%= link_to pagy.page_url(series_item),
                data: { turbo_frame: :_top },
                class: "rounded-md px-2 py-1 inline-flex items-center text-sm font-medium text-secondary hover:border-secondary hover:text-secondary" do %>
            <%= series_item %>
          <% end %>
        <% elsif series_item.is_a?(String) %>
          <%= link_to pagy.page_url(series_item),
                data: { turbo_frame: :_top },
                class: "rounded-md px-2 py-1 bg-container border border-secondary shadow-xs inline-flex items-center text-sm font-medium text-primary" do %>
            <%= series_item %>
          <% end %>
        <% elsif series_item == :gap %>
          <span class="inline-flex items-center px-2 py-1 text-sm font-medium text-secondary">...</span>
        <% end %>
      <% end %>
    </div>
    <div>
      <% if pagy.next %>
        <%= link_to pagy.page_url(pagy.next),
              data: { turbo_frame: :_top },
              class: "inline-flex items-center p-2 text-sm font-medium text-secondary hover:border-secondary hover:text-secondary" do %>
          <%= icon("chevron-right") %>
        <% end %>
      <% else %>
        <div class="inline-flex items-center p-2 text-sm font-medium hover:border-secondary">
          <%= icon("chevron-right") %>
        </div>
      <% end %>
    </div>
  </div>
  <div class="flex items-center gap-4">
    <%= select_tag :per_page,
                   options_for_select(["10", "20", "30", "50"], pagy.limit),
                   data: { controller: "selectable-link" },
                   class: "py-1.5 pr-8 text-sm text-primary font-medium bg-container-inset border border-secondary rounded-lg focus:border-secondary focus:ring-secondary focus-visible:ring-secondary" %>
  </div>
</nav>
```

Changes from original:
- `pagy.prev` → `pagy.previous` (line 6, 7)
- `pagy_url_for(pagy, pagy.prev)` → `pagy.page_url(pagy.previous)` (line 7)
- `pagy_url_for(pagy, series_item)` → `pagy.page_url(series_item)` (lines 21, 27)
- `pagy_url_for(pagy, pagy.next)` → `pagy.page_url(pagy.next)` (line 39)
- `pagy.limit` stays the same (line 53)

**Step 9: Run tests**

```bash
bin/rails test test/controllers/transactions_controller_test.rb
bin/rails test test/controllers/accounts_controller_test.rb
bin/rails test test/controllers/api/
bin/rails test test/controllers/import/
```

Expected: All pass. If `.series` method doesn't exist in pagy 43, we'll need to investigate the replacement (check `pagy.data_hash` or generate series data manually).

**Step 10: Run full test suite**

```bash
bin/rails test
```

Expected: All ~1500 tests pass.

**Step 11: Run rubocop**

```bash
bin/rubocop
```

Expected: Clean (or only pre-existing offenses).

**Step 12: Commit and create PR**

```bash
git add -A
git commit -m "Upgrade pagy 9.x → 43.x

Major API migration:
- Pagy::Backend → Pagy::Method (5 files)
- Pagy::Frontend removed (integrated into Pagy::Method)
- pagy_array() → pagy(:offset, ...)
- pagy_url_for(pagy, page) → pagy.page_url(page)
- pagy.prev → pagy.previous
- items: param → limit: param
- .vars[:items] → .limit
- Overflow/array extras now built-in (removed requires)

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"

git push -u origin upgrade/pagy-43
gh pr create --title "Upgrade pagy 9.x → 43.x" --body "$(cat <<'EOF'
## Summary
- Major version upgrade from pagy 9.3.5 to 43.3.1
- API migration: Backend→Method, pagy_url_for→page_url, pagy_array→pagy(:offset,...)
- Updated pagination partial, 5 controllers, 1 model, 1 helper, 2 jbuilder templates
- Overflow and array extras are now built-in (removed explicit requires)

## Test plan
- [x] `bin/rails test test/controllers/transactions_controller_test.rb` passes
- [x] `bin/rails test test/controllers/accounts_controller_test.rb` passes  
- [x] `bin/rails test test/controllers/api/` passes
- [x] `bin/rails test` full suite passes
- [ ] Manual: browse transactions list, verify pagination links work
- [ ] Manual: browse account detail, verify activity pagination
- [ ] Manual: test per-page selector (10/20/30/50)
- [ ] Manual: test API pagination endpoints

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Task 9: Final Verification

**Step 1: Ensure main is up to date (after all PRs are merged)**

```bash
git checkout main
git pull origin main
bundle install
```

**Step 2: Run full regression suite**

```bash
bin/rails test
```

**Step 3: Run system tests**

```bash
bin/rails test:system
```

**Step 4: Run linting**

```bash
bin/rubocop
```

**Step 5: Run security scan**

```bash
bin/brakeman
```

Expected: All green. If any failures, investigate and fix before declaring complete.

**Step 6: Update the dependency upgrade report**

Mark all 16 items as completed in `docs/DEPENDENCY_UPGRADE_REPORT.md`. Move them to the "Completed Upgrades" section.

---

## Risk Notes

- **Pagy `.series` method**: The upgrade guide confirms `series_nav` for HTML output, but our custom partial iterates `.series` directly. If `.series` is removed in v43, we'll need to either use `series_nav` with custom CSS or extract page numbers from `pagy.data_hash`. Verify at Step 9 of Task 8.
- **Pagy `overflow: :last_page`**: This option is discontinued in v43. The new default returns an empty page for out-of-range requests. This is a behavior change — pages beyond the last page will show empty results instead of redirecting to the last page. If this is unacceptable, implement a controller-level rescue for `Pagy::RangeError`.
- **Plaid 41→45**: 4 major versions but auto-generated SDK. Monitor for subtle field type changes in API responses during manual testing.
- **Rubyzip `Zip::File.open_buffer`**: v3 docs mention it "no longer assumes opening a buffer is to create a new archive." Our test usage (reading existing ZIP data) should be fine, but verify the `create:` parameter isn't needed.
