# Repository Audit - 2026-06-15

## Local State

- `main` is aligned with `origin/main` at `cfcda220`.
- No unpushed commits were found on `main`.
- Untracked files are present and should be handled intentionally before committing other work:
  - `AGENTS.md`
  - `dev.md`
  - `meta.md`
  - `work-moments.md`
  - `docs/design/claude-design-workflow.md`

## Untracked File Disposition

- Committed: `AGENTS.md`, because the contributor guide is repository-specific.
- Moved outside the repository for review: `dev.md`, `meta.md`, `work-moments.md`, and `docs/design/claude-design-workflow.md`. These looked like personal or exported notes unless they are intentionally project documentation. They were moved to `/private/tmp/roms-finance-untracked-notes-20260615/`.

## Dependabot PRs

- Safe merge candidates after local health is green: #41, #42, #43, #44, #45, #46, #47, #49, #50, #51.
- Blocked by failing CI test job: #48, #52, #54, #55, #56, #57, #58, #59, #60, #61.

Merge dependency PRs individually so any failure remains attributable to one dependency change.

## Feature Branch

Treat `feature/ai-upgrade-combined` as feature recovery and reconciliation work, not as a dependency upgrade. GitHub marks PR #32 as merged, but current `main` does not contain that branch tip. Do not merge it wholesale because it deletes substantial equity compensation and provider code relative to current `main`. Review by behavior and cherry-pick only still-desired AI changes that do not regress equity compensation or provider functionality.

## Branch Cleanup Candidates

Local branches with gone upstream should be pruned or deleted only after confirming their unique commits are merged, obsolete, or intentionally archived:

- `claude/review-ai-upgrade-plan-kzZ3G`
- `claude/security-scan-Hywpn`
- `feature/ai-upgrade-phases-3-5`
- `security-hardening-consolidation`

## Local Health Remediation

- Bump `brakeman` from `8.0.4` to `8.0.5` so `bin/brakeman --no-pager` does not crash while checking for the latest release.
- Freeze AlphaVantage provider tests to `2026-03-01` so date-dependent `outputsize` selection continues to match the committed VCR cassettes.

## Required Verification

Run these checks on `main` after remediation:

- `RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bin/rubocop`
- `npm run lint`
- `bin/importmap audit`
- `bin/brakeman --no-pager`
- `bin/rails test`
