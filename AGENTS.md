# Repository guidance for development agents

ROMS Finance is a Rails financial application. This is the canonical, tool-neutral
agent guide. Read [CONTRIBUTING.md](CONTRIBUTING.md) and the
[developer guide](docs/DEVELOPER_GUIDE.md) before changing code. Runtime versions
come from `.ruby-version`, lockfiles and CI/container configuration, not this file.

## Working agreement

- Read affected code, tests and existing patterns before editing. Preserve unrelated
  work. Use a dedicated branch/worktree for meaningful changes; keep patches scoped.
- Plan multi-step work and delegate bounded tasks when useful. Give parallel agents
  non-overlapping write ownership; retain integration and verification responsibility.
- Prefer Rails and existing dependencies over a new framework. Do not rewrite the app
  or move directories merely to match a proposed architecture.
- Ask before changing financial assumptions, access policy, destructive data operations,
  or irreversible rollout behavior. Never run migrations, resets or demo-data tasks
  automatically. Inspect scripts and targets before execution.
- Do not read/expose credentials or local secret files, use live provider data in tests,
  start/restart services, or operate on production without scoped authorization.
- Commit, push, PR creation and release mutations require user authorization. Never
  push directly to `main` unless explicitly requested. No force pushes or history
  rewriting without specific authorization.

## Architecture and design

Read [current architecture](docs/architecture/current-state.md),
[financial contracts](docs/architecture/financial-contracts.md), and
[ADR 0001](docs/architecture/decisions/0001-rails-modular-monolith.md).

- Retain the Rails modular monolith: models own associations, invariants and domain
  queries; POROs/concerns organize cohesive behavior. Use explicit orchestration for
  multi-step workflows where it improves clarity—not a mandatory service abstraction.
- `app/calculators/` is the financial computation home; `app/services/` contains debt
  simulators. Existing classes are not uniformly pure. New numerical kernels should
  take explicit inputs, dates and random sources and avoid DB/network/cache effects.
- Family is the tenancy root. `Current.user` / `Current.family` are request context,
  not authorization. Scope lookups by family **and** account visibility; balance-only
  access must not disclose details. Jobs carry explicit context, not ambient `Current`.
- Preserve signed-entry, currency, rounding and rate conventions. Missing data is not
  zero. Financial corrections need independent expected values and documented sources.
- Use existing provider registry/concepts and normalize external results at the edge.
  Test success, missing configuration, errors, retries and idempotency as appropriate.
- Keep controllers thin and UI Hotwire-first: native HTML, Turbo, Stimulus,
  ViewComponents, server formatting and functional Tailwind tokens in
  `app/assets/tailwind/roms-design-system.css`. Use the `icon` helper.
- Follow surrounding localization conventions; do not introduce a blanket i18n bypass.
  Use connection-pool `with_connection` for raw SQL. Consider callbacks, auditability,
  constraints and transactions before bulk writes.

## Task routing

Canonical recipes live in `.skills/`; tool directories are adapters, not copies.
Load the relevant `SKILL.md` before task-specific work:

| Task | Skills |
| --- | --- |
| Environment / database | `setup`, `db`; `migration` for schema/backfill work |
| Financial implementation | `calculator`, `simulator`; `pag-check` for planning assumptions |
| Validation | `test`, `pre-pr` |
| Requested review / phase audit | `review`, `phase-review` |
| Authorized publication | `commit`, `pr`, `release` |

Skills supplement this guide and the shared human references. If instructions
contradict code/configuration, investigate and correct the docs; do not silently
change behavior to satisfy stale examples. Tool availability/discovery must be
verified; manually read canonical skills when automatic loading is unavailable.

## Verification and handoff

Commands and safe local/container usage are in
[development workflow](docs/development/workflow.md). Use Minitest, fixtures,
VCR and independently derived financial expectations. Run focused tests first,
then applicable lint/security and full-suite checks before PR readiness. Test DB
and Redis isolation must be verified before any test task. Do not automatically
"fix" a failed check by resetting data, updating dependencies or skipping tests.

Inspect `git diff`; report what changed, exact checks/results, blocked/unrun
checks, remaining risks and any altered financial outputs. Historical validation
is not a fresh test result. Persist durable knowledge in shared docs/ADRs, not
only conversations or provider-specific instructions.
