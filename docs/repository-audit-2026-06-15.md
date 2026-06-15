# Repository Audit - 2026-06-15

## Final Local State

- `main` has been pushed to `origin/main` with the repository health fixes and the completed dependency updates listed below.
- The local worktree was clean before the final audit/test-helper update.
- `AGENTS.md` was committed as the repository-specific contributor guide.
- Personal/exported notes were moved out of the repository for review:
  - `dev.md`
  - `meta.md`
  - `work-moments.md`
  - `docs/design/claude-design-workflow.md`
  - Destination: `/private/tmp/roms-finance-untracked-notes-20260615/`

## Repository Health Fixes

- Updated `brakeman` from `8.0.4` to `8.0.5`, restoring `bin/brakeman --no-pager`.
- Stabilized AlphaVantage provider tests by freezing the provider test date to `2026-03-01`, keeping VCR `outputsize` expectations deterministic.
- Stabilized equity sale action executor coverage by selecting the created sale outflow using the expected transaction attributes instead of the first transaction on a shared date.
- Included `Turbo::Broadcastable::TestHelper` in `ActiveSupport::TestCase` so `DeveloperMessageTest` does not depend on test load order for Turbo broadcast assertions.

## Completed Dependabot Updates

Merged normally:

- #41 `pg` `1.5.9` -> `1.6.3`
- #42 `doorkeeper` `5.8.2` -> `5.9.0`
- #43 `ruby_llm` `1.13.2` -> `1.14.1`
- #44 `stripe` `15.3.0` -> `19.0.0`
- #45 `debug` `1.11.0` -> `1.11.1`
- #46 `sentry-rails`, `sentry-ruby`, `sentry-sidekiq` `5.26.0` -> `6.5.0`
- #47 `intercom-rails` `1.0.6` -> `1.1.0`
- #49 `aws-sdk-s3` `1.208.0` -> `1.219.0`
- #51 `yard` `0.9.38` -> `0.9.42`
- #52 `erb` `6.0.2` -> `6.0.4`
- #54 `nokogiri` `1.19.2` -> `1.19.3`
- #55 `css_parser` `2.0.0` -> `2.1.0`
- #58 `faraday` `2.14.1` -> `2.14.2`
- #60 `puma` `7.2.0` -> `7.2.1`
- #61 `net-imap` `0.6.3` -> `0.6.4.1`

Applied manually and closed because the PR lockfiles conflicted after earlier dependency merges:

- #50 `tailwindcss-rails` `4.2.3` -> `4.4.0`, `tailwindcss-ruby` `4.1.8` -> `4.2.2`
- #59 `jwt` `2.10.2` -> `2.10.3`

## Remaining Dependabot PRs

- #48 `minitest` `5.27.0` -> `6.0.6`: blocked. CI fails before tests run with `LoadError: cannot load such file -- minitest/mock` from `test/test_helper.rb:21` under Minitest 6.
- #56 `view_component` `4.5.0` -> `4.9.0`: still open. Dependabot rebase was requested after the latest dependency merges; fresh checks were pending at the final audit update.
- #57 `sidekiq-cron` `2.3.1` -> `2.4.0`: still open. Dependabot rebase was requested after the latest dependency merges; fresh checks were pending at the final audit update.

## Feature Branch

`feature/ai-upgrade-combined` was not merged. Treat it as feature recovery and reconciliation work, not as a dependency upgrade. GitHub marks PR #32 as merged, but current `main` does not contain that branch tip, and the branch removes substantial equity compensation and provider code relative to current `main`. Review by behavior and cherry-pick only still-desired AI changes that do not regress equity compensation or current provider functionality.

## Branch Cleanup

- Deleted local `security-hardening-consolidation`; it had no unique commits beyond `main`.
- Preserved `claude/review-ai-upgrade-plan-kzZ3G`; it still contains unmerged AI documentation/provider commits.
- Preserved `claude/security-scan-Hywpn`; it still contains an unmerged security scan report commit.
- Preserved `feature/ai-upgrade-phases-3-5`; it is checked out in `.worktrees/ai-upgrade-phases-3-5` and contains unmerged AI memory/provider/UI commits.

## Verification

Final local verification on `main`:

- `RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bin/rubocop`: passed
- `npm run lint`: passed
- `bin/importmap audit`: passed
- `bin/brakeman --no-pager`: passed with zero security warnings; Brakeman still reports one obsolete ignore entry, `698d3963105c7ce11b6558ad35686cd2ff2a1f861354e8fa1ea54c9f0542c239`
- `bin/rails test`: passed, `1918 runs, 8883 assertions, 0 failures, 0 errors, 16 skips`
