# Documentation Guide

This guide explains how documentation is organized in ROMS Finance and where new content should go.

## Structure

```
Root/
├── README.md              # Public-facing: project description, setup quickstart, license
├── CLAUDE.md              # AI agent instructions (Claude Code). THE canonical dev reference.
├── CONTRIBUTING.md        # How to contribute (upstream Maybe Finance guide)
│
docs/
├── DOCS_GUIDE.md          # This file — explains the doc structure
├── FEATURE_ROADMAP.md     # Forward-looking feature specs (F1–F10)
├── architecture/
│   └── design-vision.md   # Historical design reference for investment + debt features
├── testing/
│   ├── golden-masters.md  # Golden master test traceability (scenarios A/B/C)
│   └── debt-simulators.md # Debt simulator test architecture and known-value guide
├── api/
│   └── chats.md           # Chat API endpoint documentation
├── hosting/
│   └── docker.md          # Self-hosting with Docker Compose
└── reviews/
    └── phase-1-review.md  # Post-phase code review reports
```

## Where Things Go

| Content Type | Location | Owner |
|---|---|---|
| Quick-start setup, project overview | `README.md` | Anyone (keep minimal) |
| AI agent rules, dev commands, conventions | `CLAUDE.md` | Maintainer (update when conventions change) |
| Detailed architecture and design decisions | `docs/architecture/` | Maintainer (update per phase) |
| Test documentation and golden masters | `docs/testing/` | Maintainer (update when test infra changes) |
| API documentation | `docs/api/` | Maintainer (update when API changes) |
| Hosting and deployment guides | `docs/hosting/` | Maintainer (update when Docker config changes) |
| Feature roadmap and specs | `docs/FEATURE_ROADMAP.md` | Product owner (update per sprint) |
| Post-phase review reports | `docs/reviews/` | Reviewer (one file per phase) |
| Cursor rules (AI agent patterns) | `.cursor/rules/` | Maintainer (see below) |
| Claude skills (AI slash commands) | `.claude/skills/` | Maintainer (see below) |

## AI Agent Configuration

### What Are Cursor Rules and Claude Skills?

- **Cursor rules** (`.cursor/rules/*.mdc`) are contextual AI guidance files that automatically activate based on which files you're editing. They teach the AI assistant project-specific patterns and conventions without you having to repeat yourself.
- **Claude skills** (`.claude/skills/*/SKILL.md`) are slash commands you type in the AI chat (e.g. `/commit`, `/test`) to trigger predefined workflows. Each skill defines a repeatable recipe the AI follows.

### Cursor Rules (`.cursor/rules/`)

Six rules, each with a clear scope:

| Rule | What's inside | Triggers on |
|---|---|---|
| `project-design.mdc` | Delegated types, signed amount convention, sync architecture, Provider pattern | `app/models/**` |
| `testing.mdc` | Minitest + fixtures conventions (Part 1), financial calculation testing with known values (Part 2) | `test/**` |
| `view_conventions.mdc` | ViewComponent vs Partial decision tree (Part 1), Stimulus declarative actions (Part 2), design system tokens (Part 3) | `app/{views,components,javascript}/**` |
| `financial-architecture.mdc` | Calculator pure-function pattern (Part 1), Simulator state pattern (Part 2), concern modules (Part 3), multi-jurisdiction Canadian-first design (Part 4) | `app/{calculators,services,concerns}/**` |
| `debt-optimization.mdc` | Smith Manoeuvre, HELOC waterfall, Canadian mortgage semi-annual compounding, auto-stop rules, CRA audit trail | Debt models/simulators |
| `investment-projections.mdc` | Adaptive projections, Monte Carlo Box-Muller, PAG 2025 assumptions with safety margin, milestone tracking | Projection models/calculators |

### Claude Skills (`.claude/skills/`)

Twenty skills available as slash commands:

| Skill | Command | Description |
|---|---|---|
| commit | `/commit` | Create a git commit with proper message and Co-Authored-By attribution |
| pr | `/pr` | Create a pull request with structured summary and test plan |
| branch | `/branch` | Create, list, or clean up git branches |
| pre-pr | `/pre-pr` | Run all pre-PR checks: tests, linting (Rubocop + Biome), security (Brakeman) |
| db | `/db` | Database management — setup, reset, migrate, or check status |
| test | `/test` | Run tests: all unit tests, system tests, or specific file/line |
| lint | `/lint` | Run all linters with auto-fix (Rubocop, ERB, Biome) |
| setup | `/setup` | Full project setup with environment verification |
| review | `/review` | Code review for N+1 queries, design tokens, auth, security, conventions |
| phase-review | `/phase-review` | Structured post-phase review with pass/fail verdicts across 5 dimensions |
| pag-check | `/pag-check` | Verify PAG 2025 compliance for financial projections |
| component | `/component` | Generate ViewComponent with template, optional Stimulus, and preview |
| stimulus | `/stimulus` | Generate Stimulus controller (global or component-scoped) |
| api-endpoint | `/api-endpoint` | Generate API v1 endpoint with controller, views, routes, and tests |
| calculator | `/calculator` | Generate financial calculator (pure function, PAG-aware) |
| simulator | `/simulator` | Generate financial simulator with state tracking and comparisons |
| provider | `/provider` | Generate data provider for third-party service integration |
| import | `/import` | Generate CSV import handler with field mapping and validation |
| sync | `/sync` | Generate Sidekiq background sync job with retry logic |
| oauth | `/oauth` | Configure Doorkeeper OAuth scopes, applications, and test tokens |

## Maintenance Principles

1. **CLAUDE.md is the single source of truth** for development conventions. Cursor rules expand on topics CLAUDE.md summarizes — they must not contradict it.
2. **Fewer, richer documents** over many thin ones. Merge before creating new files.
3. **Delete stale content** rather than letting it rot. If a doc hasn't been updated in 3+ phases, evaluate whether it's still needed.
4. **Every file has an owner** (see table above). If no one owns it, delete it.
5. **AI rules should be DRY**. No two Cursor rules or Claude skills should cover the same ground.
