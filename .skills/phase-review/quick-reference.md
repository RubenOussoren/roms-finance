# Phase review quick reference

| Dimension | Evidence to seek |
| --- | --- |
| Reuse | Duplicated rules/formulas causing concrete drift risk |
| Structure | Cohesion, state ownership, failure paths and dependency direction |
| Architecture | Real contract integration, tenant integrity and rollout compatibility |
| Tests | Behavioral regressions, independent financial values and deterministic edges |
| Documentation | Sources, decisions, changed contracts and operational instructions |

Each finding needs severity, `file:line`, evidence/failure scenario, impact and a scoped
fix. Long methods, nesting, one-caller helpers or large documents are prompts to inspect,
not automatic failures. Record uncertainty and unassessed scope explicitly.

- **PASS:** sufficient evidence, no material findings.
- **PASS WITH WARNINGS:** sufficient evidence, only nonblocking findings.
- **BLOCKED:** required evidence is unavailable; no fabricated assurance.
- **FAIL:** demonstrated correctness/security/data/rollout risk needs correction.

Save reports in `docs/reviews/phase-<slug>-review.md`, preserving earlier work. Re-review
tracks prior findings and new evidence. Review/fix/commit/publication are separate scopes;
never automatically spawn a reviewer at phase completion.
