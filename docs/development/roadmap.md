# Development roadmap

**Proposed on:** 2026-10-04
**Planning baseline:** `8e20add4` (`8e20add4d5e653b443a4316bbf2974561bd210aa`)
**Status:** proposal for maintainer approval; documentation only, not authorization to migrate, deploy, alter privacy policy, or change financial results.

Read the [October assessment](assessment-2026-10.md) for source/line evidence, strengths, confidence and the R1–R7 risk register. This roadmap deliberately does not repeat that inventory. It defines small, independently reviewable milestones and evidence-based exit criteria. Product scope remains in [`docs/FEATURE_ROADMAP.md`](../FEATURE_ROADMAP.md); dependency migration history remains in [`docs/dependency-maintenance-2026-10.md`](../dependency-maintenance-2026-10.md).


## Foundation tranche delivered

The authorized follow-up implements a bounded first tranche: fresh isolated full
unit/browser validation and coverage measurement, demonstrated visibility/preview
fixes and request negatives, serialized simulation replacement/rollback tests,
projection replay inputs, pinned CI service majors, tested publication revision
identity, Biome ignore handling, and fail-closed production Sidekiq credentials.
See [hardening evidence](hardening-validation-2026-10.md) for tested revisions,
counts, limits and the risk disposition. This does **not** certify every milestone:
coverage CI artifacts, complete boundary inventory, full recovery/operator drills,
callback/job inventory and client-specific adapter smoke checks remain follow-ups.

## Principles and sequencing

- Retain the Rails monolith, model-owned domain behavior, calculators for math, specialized stateful simulators, and Hotwire/ViewComponents. No rewrite, microservices program, or blanket move to services.
- Prove a suspected failure before prescribing its architecture. A hypothesis can close with documented evidence that current behavior is adequate.
- Separate behavior-preserving cleanup from permission, financial-model, database and deployment changes. Each needs its own acceptance evidence and approval.
- Run validation in an isolated test environment with explicit DB/Redis/cache targets. Preserve development/production volumes and configuration; never use live provider financial mutations for routine validation.
- Do not automatically regenerate golden masters, remove skips, suppress warnings, lower gates, or enable new Rails defaults to obtain a green run.
- Milestones are ordered by risk, not calendar promises. Maintainers assign owners and effort after M0. M1 and M2 can proceed independently after M0; M3 follows supported deployment decisions; M4 uses M2's calculation contract. M5 can proceed as a bounded documentation/tooling pilot without blocking security work. M6 is the integration exit gate.

## M0 — establish a fresh, attributable validation baseline

**Purpose:** turn historical reports into current evidence; supports R6/R7 and all later milestones.
**Suggested owner:** maintainer with test/CI access.

**Deliverables**

- Record tested SHA, date, runtime/toolchain versions, isolated environment, commands, exit statuses, suite counts and skips. Keep historical maintenance numbers explicitly historical.
- Obtain current unit/integration, Chromium, lint, Zeitwerk, Brakeman and dependency-audit results using existing repository workflows. Record infrastructure blockers separately from application failures; do not invent a pass.
- Produce a line/branch coverage artifact using the existing opt-in instrumentation, with documented parallel aggregation. Map critical tenant and financial paths to tests and triage each skip/suppression with rationale and an owner or review date.

**Acceptance criteria**

1. Every result is tied to the same identified checkout, with retrievable logs; reports distinguish commands actually run from planned checks.
2. Fresh suite failures/skips and security findings have a disposition; no baseline claim depends solely on the prior dependency report.
3. Coverage has a reproducible command and artifact; no percentage is asserted until measured. An initial floor, if desired, is proposed from observed results rather than an arbitrary global target.

**Approval point:** maintainer accepts the baseline and unresolved blockers before declaring later milestones validated. Coverage-gate policy is a separate decision, not silently enabled during measurement.

## M1 — prove tenant and account-permission boundaries

**Purpose:** close or narrow R1 before extending sensitive flows.
**Suggested owner:** domain maintainer, with privacy-policy approval from the product owner.

**Deliverables**

- Inventory authenticated web/API routes, nested resources, exports/downloads, provider callbacks, background jobs and impersonation entry points. Record family source, account scope, read/write authority and legitimate bypasses.
- Define a test matrix for two families and same-family owner/admin/member users with hidden, balance-only and full permissions, including joint/default-permission cases. Compare SQL scopes with instance predicates.
- Add negative request/model/job tests where the matrix exposes missing guarantees; fix demonstrated failures in scoped PRs. Prefer existing scopes/concerns unless a concrete duplication/problem justifies a small policy abstraction.

**Acceptance criteria**

1. Each inventoried boundary has a test or explicit rationale for non-applicability; foreign-family IDs cannot read/write/export data through covered paths.
2. Hidden and balance-only users cannot retrieve detail through alternate endpoints or perform unauthorized writes; successful owner/full-access behavior remains covered.
3. Jobs and callbacks obtain tenant authority from trusted persisted context, not an assumed request-local `Current` value; impersonation's intended privileges are documented and tested.
4. Any scope/predicate disagreement is resolved by an approved policy or documented as intentional with a regression test. The outcome is an audit conclusion, not a generic “tenant safe” stamp.

**Approval point:** approve household sharing/default-permission semantics before changing them. Escalate a reproduced privacy issue immediately; do not wait for unrelated cleanup. Any broad authorization framework or schema change requires a separate proposal.

## M2 — make simulation lifecycle a tested contract

**Purpose:** address R2 while preserving accepted financial behavior.
**Suggested owner:** financial-domain maintainer.

**Deliverables**

- Identify supported callers and choose the public rerun entry point. Document whether low-level `simulate!` is internal/append-or-conflict-skipping behavior rather than a replacement API.
- Characterize sequential reruns with unchanged and changed inputs, frozen dates, failures between scenarios/summary persistence, concurrent runs, and chart/audit helper reuse after reruns.
- Only where tests expose a gap, add the smallest lifecycle fix: explicit locking, cache invalidation or a clearer orchestration boundary. Preserve the existing transaction and unique ledger identity.

**Acceptance criteria**

1. A supported unchanged-input rerun yields one row per strategy/month/scenario, equivalent ledger values and summaries (excluding intentional timestamps), and no stale chart/audit results.
2. Changed inputs replace prior results coherently; all summaries correspond to the committed ledger.
3. Injected failures roll back to the prior complete result/status, and concurrent calls serialize safely or fail with an explicit tested contract. No silent partial run is presented as complete.
4. Baseline/prepay/Smith comparison, renewal, prepayment limits, HELOC and auto-stop cases retain known-value/invariant checks. Golden-master differences are reviewed, not automatically blessed.

**Approval point:** maintainer approves API visibility and concurrency semantics. Financial-domain/product approval is required for changed calculations or snapshot expectations; schema changes require their own migration/data-repair plan.

## M3 — reproducible CI, release identity and deployment profiles

**Purpose:** address R3/R6 with operator-ready guarantees, not just configuration cleanup.
**Suggested owner:** CI maintainer and deployment operator.

**Deliverables**

- Select supported PostgreSQL/Redis versions and an update policy; align or explicitly justify CI, sandbox and self-host differences. Propose immutable release-image references where reproducibility matters, without freezing upgrades indefinitely.
- Trace push/tag/manual publication so the tested checkout, built checkout, tags and embedded commit identity agree. Include a manual non-default-ref case in validation.
- Document separate private-local and public reverse-proxy profiles: secret generation, Sidekiq access, TLS flags/cookies, exposed ports, storage, upgrade/migration ordering and worker startup. Keep local development usable.
- Perform an isolated backup/restore and upgrade/rollback drill covering DB, stored files, required configuration/key material and image/schema compatibility. Define recovery-time and acceptable data-loss objectives with the operator.

**Acceptance criteria**

1. CI service versions are intentional and repeatable; unit/browser gates still execute. Updating service images has a documented validation path.
2. Each publish trigger has evidence that CI validates the actual built ref and image metadata describes it; no new ref bypasses established security/test gates.
3. Public deployment instructions require unique credentials and a validated HTTPS/proxy posture; `/sidekiq` access and direct-port exposure are tested. Local-only settings are clearly labeled, not advertised as public-safe defaults.
4. A dated restore drill in disposable infrastructure recovers representative records and stored files, verifies login/read access, `/up`, and worker processing, and records achieved recovery objectives. A failed drill remains an open blocker.
5. Upgrade and rollback instructions identify backup prerequisites and irreversible migration limits; destructive volume operations are explicit and never automatic validation steps.

**Approval point:** operator approves supported versions, exposure, recovery objectives and deployment-default changes before rollout. Production migrations, secret rotation and live drills require explicit environment-specific authorization. This milestone does not claim historical local probes validated a live deployment.

## M4 — replayable calculations and observable derived work

**Purpose:** address R4/R5 and improve the targeted coverage picture from M0.
**Suggested owner:** financial-domain maintainer with background-job support.

**Deliverables**

- Inventory Monte Carlo versus analytical callers and ambient date/random inputs. Decide where reproducible replay is required; document stochastic versus deterministic contracts.
- Where justified, introduce backward-compatible explicit as-of dates and injectable RNG/seed handling, with isolated tests rather than global `srand` pollution. Record inputs needed to reproduce a result.
- Trace account creation/balance update/import/sync callbacks and derived milestone jobs. Measure job counts/timing and test rollback, duplicate/retried delivery and bulk-write behavior before deciding on extraction or batching.
- Add targeted line/branch coverage for risky branches rather than maximizing test counts. Reconcile stale golden-master traceability text with current source and approved financial expectations.

**Acceptance criteria**

1. Replay-required computations produce the same financial values for the same explicit inputs/date/seed; tests do not depend on unrelated random draw order. Stochastic tests use justified distribution/tolerance checks.
2. Analytical projection behavior remains deterministic for an explicit as-of date, and no default user-facing financial result changes without review.
3. Callback/job tests establish commit/rollback and retry behavior; enqueue measurements determine whether duplicate work is material. A “no extraction needed” conclusion with evidence is acceptable.
4. Coverage improvements and any remaining critical gaps are recorded against the measured M0 baseline; no blanket promise of 100% coverage or universal calculator performance is made.

**Approval point:** approve replay semantics and any financial output change before implementation; approve callback/orchestration refactors only with demonstrated benefit. No mandate to replace callbacks with a massive service layer.

## M5 — one AI guide, tool adapters and canonical skills

**Implementation update (2026-10-04):** the development-foundation branch implements
this pilot: canonical `AGENTS.md`, `.skills/`, relative Claude adapters, thin Cursor
routes, shared references and a CI drift checker. See the
[developer guide](../DEVELOPER_GUIDE.md) and
[validation record](foundation-validation-2026-10.md). Local automated path/metadata
checks are complete; client discovery, cross-platform checkout and remote CI evidence
remain open. Other milestones have targeted improvements recorded above, not blanket completion.

**Purpose:** reduce documentation drift while preserving ROMS workflows.
**Suggested owner:** developer-experience maintainer.

**Design inspiration:** the assessment cites Discourse's shared `AI-AGENTS.md`, root adapters and canonical `.skills/` at pinned revision [`67bc74d0d83f8037ec538c1299b8d8cb59211319`](https://github.com/discourse/discourse/tree/67bc74d0d83f8037ec538c1299b8d8cb59211319). Adopt the authority/discovery pattern, not its framework-specific conventions.

**Deliverables**

- Propose one canonical shared AI guide (for example `AI-AGENTS.md`), concise `AGENTS.md`/`CLAUDE.md` adapters and canonical `.skills/` definitions with tool-specific discovery adapters. Keep contextual Cursor metadata as needed, without duplicating normative policy.
- Inventory root guides, Cursor rules, skills and the developer guide; reconcile command lists, review-output paths and calculator determinism wording. Separate human setup/history from agent instructions; retain financial/privacy and safe-environment constraints.
- Pilot symlinks or forwarding files on supported platforms/tools. Choose a single approach based on actual discovery/loading behavior, especially Windows checkouts and packaging, not upstream similarity alone.

**Acceptance criteria**

1. Every supported adapter loads the same authoritative rules and discovers representative calculator, simulator and test skills; checked-in adapters do not introduce competing guidance.
2. Each skill has one canonical definition; adapter targets resolve in a clean checkout. No lost commands, resources, triggers or contextual rule metadata.
3. A maintainer can find human onboarding, architecture/testing references and tool-specific instructions without cycling through duplicated guides. Drift checks or a documented synchronization check cover adapters.
4. Rails/Minitest/Hotwire/model-oriented conventions are preserved. No Discourse RSpec, Ember/Glimmer, Guardian or universal `Service::Base` rule is imported.

**Approval point:** maintainer reviews the pilot's canonical layout and supported-tool
matrix before merge. Validate adapter portability/discovery before claiming a client
supported; choose forwarding files instead if symlinks are unsuitable. The pilot uses
`AGENTS.md` as current authority; it does not require renaming it to Discourse's filename.

## M6 — evidence-backed closeout and next tranche

**Purpose:** integrate completed milestones and decide what is actually still risky.
**Suggested owner:** maintainer; specialist/operator sign-off for their respective boundaries.

**Acceptance criteria**

1. Refresh full isolated validation and CI on the integrated SHA; retain logs/coverage and distinguish fresh results from historical reports. Complete the applicable release/profile smoke checks, not an unauthorized live deployment.
2. Record each R1–R7 outcome as confirmed-and-fixed, tested-adequate, mitigated-with-follow-up, or still unverified, with an owner and evidence link. Do not close a hypothesis merely because unrelated tests pass.
3. Any changed financial result, privacy policy, schema or operational default has its required approval and documentation. Known blockers are explicit; no gate is waived implicitly.
4. Update assessment confidence in a dated follow-up rather than rewriting this baseline's historical observations. Reprioritize the next small tranche against the product roadmap and measured remaining gaps.

**Approval point:** maintainer accepts the integrated evidence and next priorities. A separate review/PR/deployment decision is still required; milestone completion does not authorize publishing or production actions.
