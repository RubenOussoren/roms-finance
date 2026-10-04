# Contributing to ROMS Finance

Originally forked from [Maybe Finance](https://github.com/maybe-finance/maybe).
Use issues and PRs in this repository. Check existing work before starting;
prefer focused changes aligned with the application's financial product goals.

## Start here

1. Read the [developer guide](docs/DEVELOPER_GUIDE.md),
   [current architecture](docs/architecture/current-state.md) and
   [financial contracts](docs/architecture/financial-contracts.md).
2. Follow [README development setup](README.md#development-setup) for Docker,
   devcontainer or local prerequisites. Do not use production Compose for development.
3. Use [development workflow](docs/development/workflow.md) for safe validation.
   Setup, migrations and demo reloads have side effects: inspect scripts and targets.
4. Agents additionally follow [AGENTS.md](AGENTS.md); no AI tool is required to contribute.

## Design and implementation

Preserve the Rails modular monolith, Minitest and Hotwire-first UI. Match existing
Ruby/Rails naming and Biome JavaScript style. Models retain invariants and domain
queries; extract numerical kernels or workflow orchestration only where a concrete
change benefits. Prefer existing utilities/dependencies to parallel implementations.

Treat privacy, calculation correctness, currency handling and data provenance as
first-class requirements. Fixes need regression tests. Financial changes need
known-value expectations and documented conventions/sources, not only snapshots.
Authorization work needs negative cross-family and account-visibility cases.
Provider work needs deterministic boundary tests; never contact live providers
with customer credentials during validation.

Architecture proposals belong in `docs/architecture/decisions/`; unresolved ideas
must not masquerade as current implementation. The
[engineering roadmap](docs/development/roadmap.md) governs hardening priorities;
[feature roadmap](docs/FEATURE_ROADMAP.md) remains a product planning artifact,
not evidence that a feature is shipped.

## Pull requests

- Work on a feature branch/worktree; target `main`. Keep unrelated changes out.
- Use concise imperative commit summaries, e.g. `Fix projection date boundaries`.
- Describe behavior, rationale, issue links (`fixes #123` when applicable), validation
  and remaining limitations. Call out migrations, env vars, provider changes and
  altered financial assumptions/results. Include screenshots for visible UI changes.
- Run relevant tests, full unit/integration suite and applicable static/security checks
  before declaring readiness; CI also runs system tests. Disclose anything blocked
  or skipped rather than presenting it as passing. Wait for required checks/review.
- Do not commit secrets, local environment files, customer data or unsanitized cassettes.
  Document new required configuration in README or the hosting guide.

For agents, commits, pushes, PR creation, releases and production actions require
scoped user authorization; implementation permission alone is not publication
permission. Never bypass checks or push directly to `main` without explicit approval.
