# Developer guide

## Read in this order

1. [README](../README.md#development-setup): product and environment setup.
2. [Contributing](../CONTRIBUTING.md): human contribution and PR expectations.
3. [Development workflow](development/workflow.md): commands, isolation and validation.
4. [Current architecture](architecture/current-state.md): implemented boundaries and gaps.
5. [Financial contracts](architecture/financial-contracts.md): observed semantics and
   requirements for future changes.
6. [Engineering roadmap](development/roadmap.md): prioritized hardening milestones;
   [assessment](development/assessment-2026-10.md) records baseline evidence and uncertainty.

## Documentation ownership and status

| Content | Canonical location | Maintenance trigger |
| --- | --- | --- |
| Agent working agreement / task routing | [AGENTS.md](../AGENTS.md) | Workflow changes |
| Contribution process | [CONTRIBUTING.md](../CONTRIBUTING.md) | PR/gate changes |
| Commands and isolation | [workflow](development/workflow.md) | Scripts, CI or environment changes |
| Architecture / financial contracts | `docs/architecture/` | Boundary, formula or convention changes |
| Architectural decisions | [decisions](architecture/decisions/0001-rails-modular-monolith.md) | Material design decisions; supersede rather than erase |
| Test references | [golden masters](testing/golden-masters.md), [debt simulators](testing/debt-simulators.md) | Test/fixture behavior changes |
| Product proposals / refinement | [feature roadmap](FEATURE_ROADMAP.md), [October refinement roadmap](product/refinement-roadmap-2026-10.md) and linked GitHub issues | Product prioritization and user-journey evidence |
| Hosting / API | [Docker](hosting/docker.md), [chat API](api/chats.md) | Deployment/API changes |
| Task recipes | `.skills/*/SKILL.md` | Procedure changes |
| Dated assessments/reviews | `docs/development/`, `docs/reviews/` when created | Preserve original evidence; add follow-up |

The contributor owns relevant doc updates in their change; the maintainer reviews
cross-cutting policy. Runtime configuration and implementation establish current
behavior. Docs describe it and identify intended changes; aspirations cannot override
code silently. [Design vision](architecture/design-vision.md) is historical and
non-authoritative. Historical dependency reports describe the tested SHA only.

## AI documentation layout

Borrowing Discourse's shared-guide/skill/adapter pattern, adapted to Rails financial
work rather than its RSpec/Ember/service framework:

```text
AGENTS.md                  shared agent working agreement
CLAUDE.md -> AGENTS.md      Claude entry point
.skills/                   canonical task recipes and supporting resources
.claude/skills -> ../.skills
.cursor/rules/             always-on entry point and contextual reference routing
docs/                      human-readable shared knowledge
```

Edit canonical files, not another tool's copy. Cursor rules route to shared references
and contain scope metadata rather than duplicate financial implementation examples.
Symlinks require checkout support; if a tool/platform cannot follow them, read the
canonical targets explicitly. No Gemini/Copilot adapter is claimed supported here.
Automatic loading in every editor is **not** established by link validation: smoke-test
AGENTS loading and representative calculator/simulator/test skills in each supported
client after changing adapters. Check case-sensitive paths in a clean Linux checkout.

Skills are task recipes, not a substitute for authorization, runtime checks or source
inspection. Add new skills only for repeated, distinctive workflows. Keep stable rules
in shared docs and avoid copying code APIs or financial constants into prompts.

Run `ruby bin/check-development-docs` to check adapters, skill inventory, frontmatter
and local links in this foundation. The check is also wired into PR CI. It does not
prove editor discovery, prose correctness or financial compliance.
