---
name: review
description: Review scoped changes for evidenced correctness security and convention risks
---

# Focused code review

Read [shared guidance](../references/operating-guidance.md), canonical architecture and
financial contracts. Run on a user-requested scope (default staged diff); do not review
or delegate a reviewer automatically after implementation.

1. Confirm paths/base/commit range and read changed code with callers and tests.
2. Prioritize security, family/tenant isolation, authorization via request context,
   data integrity, financial units/rounding/date semantics, provider errors, and job
   idempotency. Then assess queries/N+1, dependency direction, duplication, and UI
   conventions (Hotwire, design tokens, actual helpers, accessibility).
3. Evaluate behavior and architectural intent rather than rigid file sizes or concern
   requirements. Search for existing utilities before proposing abstractions; models,
   services, and calculators follow their actual responsibilities and contracts.
4. Check regression tests and documentation for changed behavior. Any test execution
   uses `/test` isolation. Do not edit code, refresh fixtures, or run migrations as review.
5. Report severity, `file:line`, evidence, impact, and actionable fix, followed by
   verification limits and residual risks. Distinguish findings from hypotheses.

Use `/phase-review` for the broader five-dimension report. Spawn a reviewer subagent
only if the user explicitly requests review/audit, a second opinion, or that subagent.
