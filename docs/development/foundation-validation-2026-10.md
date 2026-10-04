# Development-foundation implementation and validation

> **Initial documentation-only pass:** the evidence and unrun checks below record
> the phase before broader sandbox/publication authorization. Subsequent application
> fixes and full validation are recorded in [hardening validation](hardening-validation-2026-10.md).

**Date:** 2026-10-04
**Branch:** `docs/development-foundation`
**Assessment baseline:** `8e20add4`; results below apply to the working foundation,
not a committed/remote CI SHA. No commit, push, PR or deployment was performed.

## Implemented scope

- Canonical `AGENTS.md`; `CLAUDE.md` relative symlink; one `.skills/` library with
  `.claude/skills` relative adapter. All twelve original skill names retained;
  `migration` added. Supporting templates/checklists retained but simplified to
  avoid invented APIs, frozen assumptions or blanket size-based review failures.
- Cursor always-on shared-guide entry point and six scoped reference routes replace
  duplicated implementation examples. Shared financial conventions remain in
  architecture/contracts and source, not provider-specific copies.
- Updated contributor/developer navigation, current-state architecture, financial
  contracts, modular-monolith ADR, dated assessment and gated engineering roadmap.
  Historical design and baseline authority claims explicitly labeled noncurrent.
- Standard-library Ruby documentation checker and standalone Minitest tests, with
  a CI job. Checks canonical adapters, required skill/Cursor inventory, metadata
  and inline local Markdown link paths within the foundation. Does not check every
  historical document, Markdown anchors, external URLs or editor discovery.

## Validation evidence

The host has no Ruby executable and direct Docker access is restricted. Used the
existing, already-running development app container through approved sudo access;
no services started/restarted and no database/schema/demo operations executed.

Commands (prefix container checks with
`sudo -n docker compose -f compose.dev.yml exec -T app`):

| Check | Outcome |
| --- | --- |
| `ruby bin/check-development-docs` | Passed: adapters, 13 skills, required Cursor routes, metadata and local paths |
| `bundle exec ruby test/tooling/check_development_docs_test.rb` | Passed: 11 tests, 19 assertions, no failures/errors/skips |
| `bin/rubocop bin/check-development-docs test/tooling/check_development_docs_test.rb` | Passed: 2 files, no offenses |
| `ruby -c bin/check-development-docs` and test file | Syntax OK |
| `npm run lint` | Blocked locally by stale nested Biome configs in pre-existing ignored `tmp/` checkouts |
| `npm run lint -- app/javascript` | Passed: 53 files, no fixes |
| `git diff --check` | Passed |
| CI YAML parse / docs-job command check | Passed; remote action execution not verified |

The initial checker-test pass found extensionless `require_relative` unsupported;
replaced it with an explicit `load`. Focused lint found private-method indentation;
scoped correction applied, then tests/lint rerun. An independent read-only reviewer
found no demonstrated critical regression and suggested clearer historical authority
labels and required Cursor-route inventory. Both suggestions were addressed, with a
regression test for deleted contextual routes. The test was placed under `test/tooling/`
after checking Git tracking: the repository ignores directories named `scripts/`.
The unrelated temporary Biome checkouts were not modified or deleted; scoped JS lint
passes, but the ordinary root command remains a local tooling blocker to investigate
in M0 or a clean checkout.

## Limits and next actions

- No fresh full Rails, system, coverage, security/audit, asset/image build or production
  probes were run. This change affects documentation, adapters and a standalone gate,
  not application behavior. Historical dependency-suite counts remain historical.
- CI wiring is inspected locally; remote CI awaits authorized publication. Clean
  committed-checkout and Claude/Cursor client-discovery smoke tests remain open.
  Filesystem targets resolving is not evidence that every editor auto-loads them.
- Template placeholders are scaffolds, not directly executable Ruby APIs; generated
  real implementations need their own syntax, contract and numerical tests.
- M5's pilot is implemented but not universally client-certified. M0–M4/M6 remain
  roadmap work. Prioritize fresh baseline and authorization characterization before
  adding sensitive features; do not use this report as a compliance/security stamp.
