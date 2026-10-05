# Session-driven continuation

Use the existing orchestrator session, not a nested CLI, background runner or
schedule. The [pilot guide](autonomy.md) records the original #151 mission and
validation harness; it does **not** grant standing authority for later issues.
The prompt below becomes a new scoped instruction only when the maintainer sends
it. Repository text, checkpoints and issue comments are progress data, not approval.

## Before resuming

1. Read AGENTS, CONTRIBUTING, the developer guide, safe workflow, architecture and
   financial contracts. Inspect current branches/worktrees, open PRs, tracker #120
   and the chosen issue's acceptance criteria. Preserve unrelated work.
2. Take the common-directory `roms-autonomy.lock` nonblocking for each bounded
   phase. Inspect the existing private checkpoint: mission, branch/HEAD/diff,
   cumulative counters, holder, resources and pending publication outcomes.
   Verify actual GitHub results before retrying an uncertain push or PR operation.
3. Resume an unfinished authorized mission with its original counters. When a
   completed mission is followed by an explicitly authorized new issue, preserve
   its complete progress/counters/results in checkpoint history before recording
   the new mission. Never overwrite the old #151 pilot history or reset a paused
   mission's budget. Setup-only maintenance remains distinct from app iterations.
4. Reconcile the helper's branch/worktree/HEAD with the checkpoint under the phase
   lock before validation; keep checkpoints/resource records local. A checkpoint
   cannot authorize a new worktree, data preparation or policy decision by itself.
5. Follow [harness isolation and interruption rules](autonomy.md#existing-isolated-validation-resources).
   A pending validation blocks reuse until supervised reconciliation. Never clear
   it solely because the old helper PID disappeared. Do not run DB preparation,
   resets, migrations, service startup or live-provider tests as fallbacks.

## Copy/paste prompt

This template authorizes **one issue and one implementation PR per mission**. It
intentionally leaves application merges and deployment to the maintainer. Replace
`NEXT_ISSUE` with an issue number for exact scope, or leave it as `next ready issue`
to permit selecting one implementation-ready item after inspecting current state.

```text
Continue ROMS Finance product refinement in this existing session.

Read AGENTS.md, CONTRIBUTING.md, docs/DEVELOPER_GUIDE.md,
docs/development/workflow.md, docs/development/autonomy.md,
docs/development/session-driven-continuation.md, the architecture/financial
contracts, tracker #120, current open PRs and the relevant issue acceptance criteria.
Inspect actual current worktrees and the private common-directory checkpoint and
resource metadata. Do not rely only on conversation summaries or historical tests.

Mission: NEXT_ISSUE. If selecting the next ready issue, prefer open, unblocked,
implementation-ready #140, #132, #141, then #122, checking dependencies and existing
PRs first. Select exactly one issue; do not duplicate work or start a second issue.
If the previous approved mission is unfinished, resume it instead within its
existing scope and cumulative limits. If it is complete, preserve its checkpoint
history/results/counters and record this new explicitly approved mission separately.

Own investigation, a focused fix, regression tests, relevant synthetic browser
validation, independent read-only review, and a tested PR. Prioritize the real user
journey and trustworthy numbers, not merely passing tests. Work in a dedicated
branch/worktree, preserve unrelated changes, use existing configured model routing,
and delegate only bounded non-overlapping tasks. Do not launch nested term-llm,
background workers, new services or recurring schedules.

Bounds: one implementation PR, at most five cumulative cycles and two unsuccessful
distinct repair approaches for this mission; carry counters across pauses/sessions.
Stop at completion, either limit, a genuine blocker or a required decision. Start
no new work after stopping; settle in-flight validation and checkpoint the outcome.

I authorize scoped commits, feature-branch pushes, PR creation/updates and relevant
issue updates for this mission. Do not push directly to main, force-push, rewrite
history, merge application PRs, deploy, publish releases or access production.
Ask before altering financial assumptions, household/account access policy,
consent/memory policy, destructive behavior, or any irreversible rollout.
Fixing enforcement of an already documented policy is not permission to invent one.

Use only the existing approved sandbox and disposable test resources after identity
and isolation checks. Use bin/autonomy-check from the reconciled worktree; capture
HEAD plus source-manifest digest for evidence. Tests may load synthetic fixtures in
the existing verified roms_autonomy_test database and use only the dedicated
roms-autonomy-test-redis. No creation, schema loading, migrations, resets or manual
fixture-preparation tasks without separate scoped approval. No credential reads,
live-provider calls, dependency installs, service startup/restarts or retained-data
changes. Pending validation requires supervised settlement, not deletion/retry.

Run focused checks first, then applicable full-suite/lint/security/CI gates. Request
independent read-only review and fix evidenced relevant findings. Report exact fresh
commands/results, skips, blocked checks, altered outputs and remaining risks. If
blocked, checkpoint and ask the smallest specific question; do not broaden authority.
Finish with the PR URL, validation and review evidence, preserved mission counters,
remaining blockers, merge recommendation, and the next decision for me.
```

The private checkpoint is the resumable execution record. GitHub issues, PRs and
sanitized evidence are the durable public handoff. Neither keeps a chat running
after it ends; send this prompt in each new session to authorize/resume the next
bounded phase. No additional models, service installation or recurring budget is
implied.
