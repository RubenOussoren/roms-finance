# Product refinement roadmap — October 2026

**Date:** 2026-10-04\
**Evidence baseline:** `9477538732da1acf7d52720f358ea27b66777134`\
**Status:** published planning backlog; no application fixes or deployment in this change\
**GitHub tracker:** [#120](https://github.com/RubenOussoren/roms-finance/issues/120)

## Goal

Make ROMS Finance easier to use and its numbers easier to trust. Assess whether a
person can complete a financial task and understand the result—not just whether
an endpoint succeeds or the existing suite passes.

This initial audit produces **34 bounded work items: 22 source-confirmed bug
reports, 7 enhancement proposals and 5 discovery tasks**. “Source-confirmed” means
a demonstrated code/contract inconsistency, **not** a reproduced production or
browser incident. Priority and relative size are provisional. GitHub issues own
implementation progress; the [evidence register](refinement-backlog-2026-10.md)
preserves this point-in-time assessment and detailed acceptance criteria.

## Scope and limits

Four read-only investigations traced equity compensation, projections,
AI/chat, and selected manual-entry/import/milestone paths. The orchestrator
checked the key findings directly, including grant date/strike-currency behavior,
projection regeneration, chart scoping, consent/memory context and import UI.
A bounded independent fact check found no material factual correction in its
inspected equity/consent/memory/import items; its output was incomplete and is
**not** blanket independent verification of every finding.

No Rails boot, financial provider request, database query/mutation, service
startup, production inspection, browser walkthrough or application test was
performed. No passing historical suite result is promoted to current evidence.
No customer records, credentials or production screenshots were used.

Navigation/onboarding, bank/brokerage connections, transfers, budgets and debt
strategy setup have **not** received an exhaustive UX audit. The first
[walkthrough task #121](https://github.com/RubenOussoren/roms-finance/issues/121)
covers those gaps with the [synthetic sandbox playbook](refinement-sandbox-playbook.md).
Discovery issues can close as tested-adequate; they are not presumed bugs.

## What we found

| Area | User-facing problem | Highest-value next direction |
| --- | --- | --- |
| Equity compensation | Grant entry is dense; vested-to-date, still-held equity, sale proceeds and cash transfers are different concepts. Empty-grant cleanup, vesting boundaries, option FX and automatic-sale availability have code-level inconsistencies. | Establish reconciliation/date/currency contracts; fix bounded defects; then guide statement entry and offer a reviewed one-off RSU sale. |
| Projections | History and forward bands already share a chart, but the family outlook starts at month 1. Some summaries use an unscoped current total; native-currency forecasts can be summed under a reporting-currency label. | Fix scope/currency/actual timing; make the current origin understandable; preserve forecasts before adding historical performance monitoring. |
| AI | The assistant has providers, tools, streaming and memory, but tool authorization, numeric/currency handling, schemas, recovery and consent need attention. | Make existing answers trustworthy and recoverable before expanding models or autonomy. Add evidence/freshness receipts and evaluate three real financial journeys. |
| Everyday workflows | Manual account choices disagree with write permissions; failed forms can lose intent; import reversal wording omits account destruction; milestone refreshes rewrite achievement dates. | Align choices and server checks, retain form state, explain destructive effects and establish goal-history semantics. |

## The confidence-band distinction

The requested experience needs **two separately named modes**:

1. **Actual history + current outlook** — actual past balances, a clearly scoped
   current anchor, then uncertainty generated from today's approved inputs.
   [#133](https://github.com/RubenOussoren/roms-finance/issues/133) improves this
   existing chart; it does not manufacture historical bands.
2. **Actuals versus a prior forecast** — select a run that was genuinely issued
   earlier and overlay subsequent observations inside/outside its retained bands.
   [#134](https://github.com/RubenOussoren/roms-finance/issues/134) establishes
   reproducible vintages; [#135](https://github.com/RubenOussoren/roms-finance/issues/135)
   adds the monitoring experience.

Current `Account::Projection.generate_for_account` deletes current/future rows
before regenerating them, uses account/target-date uniqueness, and does not write
percentile data in that path. Existing projection storage is therefore **not a
preserved archive of earlier issued bands**. Other consumers must be characterized
before changing persistence. Retrospective simulations remain separately labeled
backtests; recalculating history from today's inputs must never masquerade as an
ex-ante forecast. Before the earliest retained run, say “No prior forecast.”

## Priorities and sizing

- **P1:** early attention for trust/correctness, destructive-effect discovery,
  privacy-policy decisions or a prerequisite for credible new capabilities.
  These are not claims of an observed incident or equal severity across items.
- **P2:** the next usability/refinement/capability tranche, after its trust gates.
- **S / M:** relative size hints for bounded work, **not** calendar or sprint
  commitments. Split M-sized items into independent PRs when useful.
- **Owner / milestone:** unassigned until maintainer triage. Suggested roles are
  product/financial-domain maintainer, application engineer and a sandbox tester.
- Issue number is not implementation order. Dependencies and evidence determine
  sequencing. Walkthrough discovery runs in parallel; it must not delay a
  demonstrable access-control or arithmetic fix.

## Phase 0 — Observe and decide

**Deliver:** a reproducible synthetic task baseline and the minimum policy/domain
contracts required for implementation.

- [#121](https://github.com/RubenOussoren/roms-finance/issues/121): end-user
  walkthroughs, number comprehension, recovery, mobile/keyboard, remaining journeys.
- [#128](https://github.com/RubenOussoren/roms-finance/issues/128): equity
  sale/transfer/materialization/undo and refresh characterization.
- [#148](https://github.com/RubenOussoren/roms-finance/issues/148): private versus
  household memory, extraction provenance and deletion/expiry policy.
- [#153](https://github.com/RubenOussoren/roms-finance/issues/153): import
  reversal/deletion effects, warnings and state guards.

**Exit evidence:** tested revision/fixtures, observable task outcomes, sanitized
screenshots and documented contracts. Adequate behavior is a valid discovery
outcome. Missing infrastructure is a blocker, not permission to reset retained data.

## Phase 1 — Establish trust

Run independent lanes in parallel. This is a risk-ordered backlog, not one giant PR.

| Lane | Work items | Exit evidence |
| --- | --- | --- |
| Authorization | [#140](https://github.com/RubenOussoren/roms-finance/issues/140) assistant debt/connectivity; [#132](https://github.com/RubenOussoren/roms-finance/issues/132) scoped chart growth; [#151](https://github.com/RubenOussoren/roms-finance/issues/151) writable account picker | Hidden/balance-only and cross-family negatives at the actual output/dispatch boundary; exact authorized totals. |
| Equity correctness | [#122](https://github.com/RubenOussoren/roms-finance/issues/122) empty cleanup; [#123](https://github.com/RubenOussoren/roms-finance/issues/123) schedule boundaries; [#129](https://github.com/RubenOussoren/roms-finance/issues/129) missing data; [#124](https://github.com/RubenOussoren/roms-finance/issues/124) option FX; [#125](https://github.com/RubenOussoren/roms-finance/issues/125) sale availability | Known-value date/currency/quantity expectations plus materialized account/history reconciliation. |
| Projection correctness | [#130](https://github.com/RubenOussoren/roms-finance/issues/130) reporting currency; [#131](https://github.com/RubenOussoren/roms-finance/issues/131) matured target actuals; [#134](https://github.com/RubenOussoren/roms-finance/issues/134) forecast vintages | Consistent currency, dated actuals, preserved reproducible forecasts; approved schema/retention rollout if needed. |
| AI correctness/recovery | [#141](https://github.com/RubenOussoren/roms-finance/issues/141) category numeric filtering; [#142](https://github.com/RubenOussoren/roms-finance/issues/142) currency aggregates; [#143](https://github.com/RubenOussoren/roms-finance/issues/143) tax classification; [#144](https://github.com/RubenOussoren/roms-finance/issues/144) typed tools; [#145](https://github.com/RubenOussoren/roms-finance/issues/145) retry; [#147](https://github.com/RubenOussoren/roms-finance/issues/147) truthful consent/dispatch verification | Stubbed end-to-end provider payloads, independently expected numbers, recoverable attempts and accurate disclosure. |

**Recommended first implementation batch:** #140, #132, #151, #141 and #122.
They address direct boundaries with small scopes and can be developed separately.
Prepare #123/#124/#129 and #131 next; seek financial convention decisions where
required. The broad walkthrough is not a prerequisite for correcting the known
schedule inconsistency. Review disclosure/tax risks early rather than waiting for
AI feature expansion.

## Phase 2 — Simplify everyday work

- Equity: [#126](https://github.com/RubenOussoren/roms-finance/issues/126) guided
  statement entry and schedule preview; [#127](https://github.com/RubenOussoren/roms-finance/issues/127)
  one-off reviewed RSU sale and clear vested/sold/held/cash labels. Options get a
  deliberate later exercise/settlement slice, not an assumed RSU-equivalent flow.
- Projections: [#133](https://github.com/RubenOussoren/roms-finance/issues/133)
  current-origin clarity; [#136](https://github.com/RubenOussoren/roms-finance/issues/136)
  contributions independent of defaults; [#137](https://github.com/RubenOussoren/roms-finance/issues/137)
  context retention; [#138](https://github.com/RubenOussoren/roms-finance/issues/138)
  bounded horizons; [#139](https://github.com/RubenOussoren/roms-finance/issues/139)
  method/assumption/source explanation.
- AI: [#146](https://github.com/RubenOussoren/roms-finance/issues/146) effective
  model/configuration consistency; [#149](https://github.com/RubenOussoren/roms-finance/issues/149)
  source/scope/freshness receipts and honest uncertainty.
- Everyday work: [#152](https://github.com/RubenOussoren/roms-finance/issues/152)
  failed-form state; [#154](https://github.com/RubenOussoren/roms-finance/issues/154)
  milestone achievement transitions.

**Exit evidence:** before/after synthetic task completion and comprehension,
controller/component regression coverage plus real system-flow screenshots.
Measure against the phase-0 baseline; do not declare success from test counts alone.

## Phase 3 — Extend only on a trusted foundation

- [#135](https://github.com/RubenOussoren/roms-finance/issues/135): realized
  actuals against a selected prior run, with dates/completeness and honest coverage.
- [#150](https://github.com/RubenOussoren/roms-finance/issues/150): evaluate
  “Why did spending rise?”, “What is my financial position?” and “What if I pay
  extra on this loan?”, including contextual follow-ups and authorized review links.

**Exit evidence:** run-preservation/eligible-target tests and a deterministic
assistant evaluation with independently expected answers, privacy, tool
compatibility and recovery. Compare model quality/cost/latency only where measured.
A “2026” model label, RAG or agent framework is not itself an improvement outcome.

## Shared delivery gates

1. Read existing Rails/Hotwire patterns and link each PR to a bounded issue.
2. Financial input/date/currency corrections need independent expected values,
   documented conventions and explicit review of altered outputs.
3. Use isolated disposable test DB/Redis and blocked live providers. Preparing
   services/schema/fixtures requires the appropriate scoped approval.
4. Authorization evidence includes two families, hidden/balance-only/full,
   ownership versus permission and background context where applicable.
5. UI evidence includes task completion, error recovery, mobile/keyboard and an
   accessible non-chart alternative. Reports/AI evidence includes outbound payloads.
6. Policy, migrations/backfills, destructive data operations and production rollout
   remain separately reviewed; this planning publication authorizes none of them.
7. Record exact commands, outcomes, SHA, screenshots and limitations. Do not
   regenerate snapshots or skip checks simply to get green CI.

## Relationship to other roadmaps

- [Engineering foundation](../development/roadmap.md) and
  [#118](https://github.com/RubenOussoren/roms-finance/issues/118) retain operational,
  architecture-boundary and infrastructure validation work. Product findings link
  to that work without claiming it complete.
- The [earlier feature roadmap](../FEATURE_ROADMAP.md) remains a historical feature
  proposal; this audit takes precedence for the initial refinement tranche, not
  for all future feature prioritization.
- The [March AI plan](../AI_UPGRADE_2026.md) is implementation history, not proof of
  current usability, privacy completeness or external model availability.
- The [April equity withdrawal plan](../plans/2026-04-11-equity-compensation-withdrawal-tracking-design.md)
  is superseded as a balance formula. Current equity uses opening balance plus
  sale-aware remaining value. Do not additionally subtract cash outflows without
  reconciliation evidence: sold units and transferred proceeds can describe the
  same economic event.

## Validation of this planning change

Source paths/ranges and all issue IDs/dependencies are mechanically checked:
34 child IDs, an acyclic phase-consistent dependency graph, 116 pinned source
ranges, 7 planning/context documents and 33 local link destinations. All 35
published GitHub issue records were verified by number/title/marker/labels/content.
Independent decimal arithmetic checks support the worked examples; they do **not**
execute the application or establish its outputs. Pinned evidence destinations
are checked separately from the canonical foundation checker. `git diff --check`
applies to the docs patch.
Local Ruby is unavailable, so `ruby bin/check-development-docs` cannot run here;
that remains an explicitly blocked local check, not a pass. Application compilation,
Rails tests and browser/system tests are intentionally unrun for this docs-only
change. Required remote CI status is reported on the PR, not assumed.
