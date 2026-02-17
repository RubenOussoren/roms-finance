# Developer Guide

This guide explains how documentation is organized in ROMS Finance, where new content should go, and how to use the AI skills workflow effectively.

## Documentation Structure

```
Root/
├── README.md              # Public-facing: project description, setup quickstart, license
├── CLAUDE.md              # AI agent instructions (Claude Code). THE canonical dev reference.
├── CONTRIBUTING.md        # How to contribute (upstream Maybe Finance guide)
│
docs/
├── DEVELOPER_GUIDE.md     # This file — doc structure + skills workflow
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
| Contribution guidelines, PR workflow | `CONTRIBUTING.md` | Maintainer (update when workflow changes) |
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

Eleven skills available as slash commands:

| Skill | Command | Description |
|---|---|---|
| commit | `/commit` | Create a git commit with proper message and Co-Authored-By attribution |
| pr | `/pr` | Create a pull request with structured summary and test plan |
| pre-pr | `/pre-pr` | Full CI gate: tests, linting (Rubocop + ERB + Biome), security (Brakeman), dependency audits |
| test | `/test` | Run tests: all unit tests, system tests, or specific file/line |
| setup | `/setup` | Full project setup with environment verification |
| db | `/db` | Database management — setup, reset, migrate, or check status |
| review | `/review` | Code review for N+1 queries, design tokens, auth, security, conventions |
| phase-review | `/phase-review` | Structured post-phase review with pass/fail verdicts across 5 dimensions |
| pag-check | `/pag-check` | Verify PAG 2025 compliance for financial projections |
| calculator | `/calculator` | Generate financial calculator (pure function, PAG-aware, JurisdictionAware) |
| simulator | `/simulator` | Generate debt simulator with AbstractDebtSimulator inheritance + mortgage math |

## Skills Workflow

### Workflow Stages

```
Setup ──────→ Development Loop ──────→ Pre-PR Gate ──────→ PR
/setup         /test, /review          /pre-pr            /pr, /commit
/db            /calculator              /phase-review
               /simulator              /pag-check
```

### Decision Trees

**"Run tests?"**
- Quick feedback on current changes → `/test`
- Full CI validation before opening PR → `/pre-pr` (runs tests + all linters + security + audits)

**"Review code?"**
- Per-commit convention check → `/review`
- End-of-phase quality gate with pass/fail verdicts → `/phase-review`

**"Financial code?"**
- New calculator → `/calculator` (scaffolds with PagCompliant, JurisdictionAware, Result struct)
- New debt simulator → `/simulator` (scaffolds with AbstractDebtSimulator inheritance)
- Verify PAG compliance → `/pag-check`

**"First time?"**
- Clone → `/setup` → `/db`

### Common Scenarios

| Scenario | Skill sequence |
|---|---|
| I just cloned the repo | `/setup` → `/db` |
| Adding a feature | `/test` → `/review` → `/commit` → `/pre-pr` → `/pr` |
| New financial calculator | `/calculator` → `/pag-check` → `/pre-pr` |
| New debt simulator | `/simulator` → `/pag-check` → `/pre-pr` |
| Phase complete | `/phase-review` |
| Quick linting + security | `/pre-pr` (linting is part of the pre-PR gate) |

### CI ↔ Skill Parity

| CI Check | Skill | Command |
|---|---|---|
| `bin/rails test` | `/test` | Unit + integration tests |
| `bin/rubocop -f github -a` | `/pre-pr` | Ruby linting with auto-fix |
| `bundle exec erb_lint ./app/**/*.erb -a` | `/pre-pr` | ERB linting with auto-fix |
| `bin/brakeman --no-pager` | `/pre-pr` | Security analysis |
| `bin/importmap audit` | `/pre-pr` | JS dependency audit |
| `npm run lint` | `/pre-pr` | JS/TS linting |

## Maintenance Principles

1. **CLAUDE.md is the single source of truth** for development conventions. Cursor rules expand on topics CLAUDE.md summarizes — they must not contradict it.
2. **Fewer, richer documents** over many thin ones. Merge before creating new files.
3. **Delete stale content** rather than letting it rot. If a doc hasn't been updated in 3+ phases, evaluate whether it's still needed.
4. **Every file has an owner** (see table above). If no one owns it, delete it.
5. **AI rules should be DRY**. No two Cursor rules or Claude skills should cover the same ground.
