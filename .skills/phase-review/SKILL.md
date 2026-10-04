---
name: phase-review
description: Review a completed phase with evidence and risk based findings and a saved report
---

# Phase review

Use only when review/audit is requested, not automatically after each phase. Read
[shared guidance](../references/operating-guidance.md), canonical architecture/contracts,
and the supporting [checklist](architecture-checklist.md) and
[quick reference](quick-reference.md). Do not automatically spawn a reviewer; delegate
only when the user explicitly requests review, a second opinion, or the reviewer agent.

1. Confirm phase name, base/commit range or working diff, and scope. Inspect changed files
   and relevant callers/tests; include migrations and deployment/configuration impacts.
2. Review five dimensions with concrete evidence:
   - **Reuse:** duplicated rules/formulas and drift risk; one-caller extraction can be valid.
   - **Structure:** cohesion, state ownership, failure paths and dependency direction.
     Line count/nesting are investigation signals, never blanket failures.
   - **Architecture:** fit with current contracts, tenant boundaries, persistence and
     rollout compatibility; distinguish justified deviations from shadow systems.
   - **Tests:** behavioral regression coverage, independent financial expected values,
     determinism and meaningful edge cases; update golden masters only for justified
     contract changes, not simply to make tests pass.
   - **Documentation:** decisions, public contracts, formula provenance and operational
     instructions needed for the change; document risk, not every method by rote.
3. Prioritize correctness, security, financial/data integrity, and deployment safety.
   Cite `file:line`, failure scenario, impact, and correction for each finding. Mark
   uncertain issues as hypotheses needing verification, not proven failures. Test only
   via `/test`; record unavailable infrastructure rather than guessing outcomes.
4. Rate each dimension pass/warn/fail/not assessed. Fail means a demonstrated material
   risk requiring correction, not style disagreement, file length, or absent boilerplate.
   Overall PASS requires adequate scope/evidence; PASS WITH WARNINGS has only nonblocking
   findings; BLOCKED identifies gaps in required evidence; FAIL identifies material risks.
5. Save a concise report to `docs/reviews/phase-<slug>-review.md` (create the directory if
   needed). Use a safe filename; preserve prior reports and avoid overwriting another
   agent’s work. For re-review, reference prior findings and record new evidence.

Report: phase/date/base/scope, verdict and five-dimension scorecard, prioritized findings
with fixes, commands/results, unassessed areas and residual risks. Display the summary
and report path. Review does not authorize fixes, commits, publishing, or migrations.
