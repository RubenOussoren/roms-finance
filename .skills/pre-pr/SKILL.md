---
name: pre-pr
description: Run non-mutating pre-PR checks and report evidence and blockers
---

# Pre-PR checks

Read [shared guidance](../references/operating-guidance.md), `CONTRIBUTING.md`, and the
canonical development workflow. Inspect current CI/configuration for applicable checks;
this skill does not freeze a test count or replace CI. Do not edit CI.

1. Confirm diff scope and dependencies. Run tests through `/test` with isolated DB/Redis
   and blocked provider traffic. Include full suite before readiness where required;
   use system tests only when relevant.
2. Run non-autofixing checks supported by the checkout: `bin/rubocop`, ERB lint using
   the installed configuration (e.g. `bundle exec erb_lint --lint-all`),
   `bin/brakeman --no-pager`, and `npm run lint`. Include other checks required by current
   workflow; verify their executables/options. Never silently add `-a`/`--write`.
3. Run configured dependency audits (e.g. `bin/importmap audit`) only with appropriate
   advisory-network access. Report unavailable tools/network as blocked; do not use
   real provider secrets or change dependencies automatically to satisfy an audit.
4. Report each command, exit status, counts/findings, and skipped/blocked checks.
   Readiness requires the required checks to pass, with security warnings assessed;
   disclose focused-only coverage and unresolved risks. Offer scoped fixes separately.
5. Inspect `git diff` for accidental changes and secrets. No commit, branch push, PR,
   release mutation, destructive DB repair, or reviewer delegation is implied.
