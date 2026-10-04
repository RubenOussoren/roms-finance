# Bounded autonomy pilot

## Durable user-approved mission

This is the scoped operating policy for the ROMS Finance autonomy pilot, not a
standing permission for arbitrary automation. It supplements [AGENTS](../../AGENTS.md),
[contribution guidance](../../CONTRIBUTING.md), the
[developer guide](../DEVELOPER_GUIDE.md) and [safe workflow](workflow.md).
If scope or financial/access semantics are unclear, stop and ask.

- Roadmap PR **#155 is merged**; backlog **#120 remains open**. Implement only its authorized child #151.
- Implement **pilot #151 only**, with **at most one implementation PR**, **five
  cumulative iterations**, and **two unsuccessful distinct repair approaches**.
  These limits span process restarts, worktrees and resumed sessions. On reaching
  a limit, checkpoint and stop; only explicit approval can expand the budget.
- Scoped commits, feature-branch pushes, creation/updates of that one pilot PR,
  and relevant issue updates are approved. Inspect the diff and stage only pilot
  changes. Never include unrelated work. Record remote identifiers so a retry
  updates the existing PR instead of creating another. Publication permission is
  not permission to merge or waive review/CI.
- **No merge, deploy, production operation, release, protected-branch push, force
  push or history rewriting. No recurring schedule until separately approved.**
  Do not install services, enable timers/cron, or register recurring CLI jobs.
- Ask before changing financial assumptions, household/account access policy,
  consent/memory behavior, or destructive behavior. Existing authorization is not
  a waiver for a newly discovered policy-sensitive issue. Do not persist personal
  household information in model memory or mine memories without consent.
- Use default configured model/provider routing. Do not supply model overrides
  in CLI flags, project config, agent preferences or subagent calls; omit `model`
  or pass `null` where a schema requires it.

The setup PR contains this document, `.term-llm/`, and `bin/` runners.
The parent orchestrator owns integration, resource preparation, review and publication.
The runner contract below must be implemented and inspected before the pilot runs;
this document or an agent prompt is **not** a substitute for enforced guards.
No service installation is part of this setup.

## Sandbox and resource boundary

Only the approved local sandbox may use **`sudo -n docker compose`** access.
Noninteractive failure is a blocker, not a reason to prompt for sudo credentials,
change permissions, add groups, alter a Docker socket, or install/restart services.
Inspect the runner/Compose inputs first; do not reuse production Compose.

| Resource | Required target / guard |
| --- | --- |
| Database | Disposable local **`roms_autonomy_test`** only; verify every Rails connection and effective `DATABASE_URL`/`POSTGRES_DB` precedence |
| Redis | Dedicated container **`roms-autonomy-test-redis`** only; verify container identity, ownership, endpoint and all cache/queue/cable URLs |
| App/browser | Branch-matched local sandbox test app; dummy fixtures; no customer accounts or data |
| Provider/network | Stubbed/replayed fixtures, live provider/AI/payment/email calls blocked; browser egress confined to verified local test app |

Resource names alone do not prove ownership. Check labels/project identity,
container IDs, ports, networks/volumes and runner records before use. A preexisting
DB/container/port/volume with unknown or conflicting ownership is a **collision:
stop**. Never adopt, remove, flush, reset or rename a colliding resource. A Redis
DB number on development/shared Redis is not isolation from `FLUSHALL`.
Missing infrastructure is not authorization to repair someone else's environment.
Only the parent orchestrator's explicitly authorized disposable preparation may
create/prepare these targets. Newly destructive actions still require approval.

Follow the test preflight in `.skills/references/operating-guidance.md`: explicit
`RAILS_ENV=test`, initially disabled parallelization, consistent connection
settings, no workers/live queues, no real provider credentials or environment-file
reloads that restore them. Do not read global credentials, local secret/env files
or print credential-bearing URLs. Checkpoint only redacted target identifiers.
No `bin/setup`, demo reloads, development migrations/resets, or blanket test
fallbacks. No network or service start was authorized merely by writing this guide.

## Single-run lock across worktrees

A worktree-local lock is insufficient: multiple worktrees share remote publication
and dedicated resources. The runner must resolve the **current Git common
repository directory** on each invocation and use one persistent lock there:

```sh
# Contract fragment, not a complete launcher. Run from the selected worktree.
common_dir=$(git rev-parse --path-format=absolute --git-common-dir) || exit 1
exec 9>"$common_dir/roms-autonomy.lock"
flock -n 9 || { printf '%s\n' 'Another autonomy run holds the lock'; exit 1; }
# Keep FD 9 held through verification, preparation, tests, publication and checkpoint.
```

Use a common-repository checkpoint (recommended
`$common_dir/roms-autonomy-checkpoint.json`), not a tracked JSON file or separate
per-worktree budgets. Keep the lock inode stable: do not unlink/recreate the lock
file to bypass a holder. Write holder metadata separately under the lock: PID,
process start identity (protect against PID reuse), hostname, worktree and run ID.
A holder collision stops the new process before any mutation or resource startup.

A leftover file is not a held `flock`; check lock acquisition and PID/start identity,
not age. **Never delete a stale lock/holder record without checking the recorded
PID and its process identity.** An unknown remote host, PID namespace mismatch or
unverifiable process identity is a blocker requiring operator reconciliation.
Even when a PID is dead, acquire the lock before any recovery; do not erase the
checkpoint/budgets. Ensure child processes cannot outlive the lock unnoticed.

## Checkpoint JSON and budgets

Runner state is explicit JSON, atomically replaced via a temporary file in the
same common directory followed by rename. Persist before/after consequential
steps, including starting an iteration, declaring a failed repair, and external
publication. Invalid/missing/unrecognized state on **resume** stops rather than
silently creating fresh counters. A new mission requires explicit initialization.
This is the recommended data contract; the integrating runner may use equivalent
field names, but must retain all identities, cumulative counters and evidence:

```json
{
  "schema_version": 1,
  "mission_issue": 151,
  "run_id": "operator-assigned-unique-run",
  "status": "stopped",
  "worktree": "verified-path-at-runtime",
  "branch": "automation/issue-151",
  "head_sha": "full-verified-commit-sha",
  "limits": { "iterations": 5, "unsuccessful_repair_approaches": 2, "implementation_prs": 1 },
  "counters": { "iterations_started": 0, "unsuccessful_repair_approaches": 0, "implementation_prs_created": 0 },
  "active_iteration": null,
  "repair_approaches": [],
  "implementation_pr": null,
  "resources": {
    "database": "roms_autonomy_test",
    "redis_container": "roms-autonomy-test-redis",
    "compose_project": "verified-sandbox-project",
    "ownership_verified": false
  },
  "lock_holder": { "pid": null, "process_start_identity": null, "hostname": null },
  "pending_external_action": null,
  "checks": [],
  "stop_reason": "not-started",
  "updated_at": "UTC timestamp"
}
```

- Increment `iterations_started` **before** spawning an iteration. An interrupted
  iteration remains charged; restarting the process is not a free retry. An
  iteration is one top-level pilot work cycle, not each tool call or agent turn.
- Record each distinct repair approach with its problem, hypothesis, changes and
  check outcome. Charge an unsuccessful approach as soon as failure is known.
  Rephrasing the same strategy does not erase its failure; do not repeat it to
  evade the two-failure stop. Unknown/in-flight outcomes need reconciliation, not
  an assumed success. After the second unsuccessful approach, stop.
- Reserve/check the one-PR budget before creation; retain PR URL/number and branch
  after creation. Record a pending external action before commit/push/PR/issue
  mutation. Reconcile Git/remote state after a crash before retrying; an uncertain
  create outcome must never cause a second PR. Do not recreate a closed pilot PR
  as a new one without approval.
- Persist exact check commands, tested SHA, exit status and redacted results;
  record blocked/skipped checks honestly. Do not store secrets, raw household
  records, cookies, credential URLs or full environment dumps.

## Resume and graceful stop

Under the common lock, resume must validate: schema/mission/budgets; repository
identity; recorded worktree, feature branch and current HEAD SHA; dirty/untracked
files and their ownership; pending external actions and remote PR/branch status;
resource identities/ownership/ports; and provider/browser isolation. Unexpected
branch/SHA changes, resource replacements, dirty unrelated work, or uncertainty
stop for reconciliation. Do not automatically switch/reset branches, overwrite a
checkpoint, adopt resources, or replay a publication step to make state match.
A known in-flight change may be reconciled with evidence; never silently accept
an arbitrary mismatch. Recalculate remaining iterations from persisted totals.

On **TERM**, the parent must stop launching iterations/repairs/publications,
forward TERM to the managed child/process group, **wait** for in-flight children
and publication outcomes to settle, then atomically checkpoint counters, branch/
SHA, pending actions and `status: stopped` / stop reason before releasing the
lock. A signal request is not proof of completion. If a child fails to stop, retain
control/lock and report the blocker; do not launch a replacement or kill/delete
resources blindly. After an uncheckpointed crash, reconcile reality under the
lock before resuming. Never remove a lock while a child might still be active.

## Branch-aware validation and browser use

The orchestrator is implementing **`bin/autonomy-check`**. Inspect that file and
its supported arguments before using it; if absent or not integrated, validation
is blocked. From the locked, recorded worktree/branch, the intended entrypoint is:

```sh
# Inspect first; this helper may perform sandbox test preparation.
sed -n '1,240p' bin/autonomy-check
bin/autonomy-check
```

Use focused tests through the helper's documented interface where available,
then the applicable gates. The helper must verify the source mounted/built in the
sandbox is the **current worktree and tested SHA**, not an old image, `main`, or a
neighboring branch. It must reject branch/SHA/resource collisions before Rails or
a browser boots. Do not bypass it with raw Compose Rails commands or a browser
against an existing development server when it fails.

Browser/system checks may only reach the helper's verified sandbox app origin.
Use dummy fixtures and the locked browser toolchain; block other egress, prevent
live external providers, and keep cookies/screenshots/logs free of household data.
The helper should record worktree/branch/SHA, sandbox identity and browser outcome
in checkpoint evidence. Missing Chromium/assets/isolation is a blocker, not a
reason to install services, relax guards, or claim UI validation passed.

## CLI integration and handoff

[Project-local agent instructions](../../.term-llm/README.md) describe the inspected
CLI schema and explicit-path invocation. The installed CLI supports `agent.yaml`
plus `system.md`, but does not auto-discover `.term-llm/` as project configuration.
Do not invent daemon/job/config keys or install a scheduler. The CLI's `loop --max`
is only a per-invocation limit; the runner must enforce cumulative checkpoint
budgets and repair/PR limits. Prompt instructions alone are not hard enforcement.

Every stop/handoff reports files, branch/SHA, exact commands/results, counters,
PR/issue references, remaining risks, and approvals needed. Successful tests do
not authorize merge/deploy. Docs/config checks do not establish live runner,
lock, TERM, database, Redis or browser behavior; those need parent integration
verification with disposable resources and explicit approval.

## Integrated one-off commands and actual enforcement boundary

The implemented entrypoints are `bin/autonomy-check` and `bin/autonomy-run`.
No persistent Web/Hub service is required or installed. Existing service state is
not altered. Python 3 and Linux subreaper support are runner prerequisites.
The runner uses one CLI iteration per invocation (`--max 1`), not a five-iteration
unattended loop. The human/parent supervisor owns repair classification and all
publication. Within-iteration repair limits are supervised policy, not a hostile
agent security boundary. The CLI uses guardian approvals (`--approval auto`),
never `yolo`; no model/provider override is supplied.

Before initialization, the supervisor creates a clean `automation/issue-151`
worktree containing this setup, and records the new resource identity in the
Git common directory's `roms-autonomy-resources.json`: `redis_id`, `redis_name`,
`owner`, `database`, `setup_worktree`. The checker validates Redis ID, labels,
project, network and absence of published ports, plus the database ownership
comment. A missing record or mismatch stops; it never creates/adopts resources.
This is a local supervised pilot, not an unattended bootstrap installer.

```sh
# From the recorded setup or pilot worktree; no development server is used.
bin/autonomy-check preflight
bin/autonomy-check assets:precompile
bin/autonomy-check test test/controllers/transactions_controller_test.rb
bin/autonomy-check test test/system/transaction_account_choices_test.rb
bin/autonomy-check zeitwerk:check
bin/autonomy-check docs
bin/autonomy-check rubocop
bin/autonomy-check brakeman
bin/autonomy-check js-lint
python3 test/tooling/autonomy_runner_test.py

# First pilot invocation only, after clean committed worktree verification:
bin/autonomy-run init
bin/autonomy-run run
```

Schema/fixture commands are separate, never implicit test fallbacks. The original
approval is for this newly created disposable database only:
`AUTONOMY_PREPARE_APPROVED=bootstrap-2026-10 bin/autonomy-check db:schema:load`
and the equivalent `db:fixtures:load`. Do not replay schema loading to repair a
failure or run migrations/seeds/resets. Tests replace synthetic fixtures in this
approved disposable database. A separate common test lock serializes all checker
invocations; the orchestrator lock spans each managed pilot iteration.

The checker starts only ephemeral `compose run --rm --no-deps` test processes,
without host ports, binds the actual worktree, and clears the application process
environment with `env -i`. Locked dependencies/browser binaries are reused
read-only from the existing sandbox; assets are built in the selected worktree.
Rails credentials are overridden with an empty in-memory object; dotenv files
are disabled before application boot. WebMock blocks external Ruby HTTP and VCR
cannot record. Playwright routes permit only the current Capybara test server
origin; this is not a general-purpose network namespace/firewall sandbox.

Stop by sending TERM to the PID in checkpoint `holder.pid` after verifying
hostname and `/proc/<pid>/stat` start identity. The runner forwards TERM, adopts
and reaps orphaned descendants, and holds its lock until the managed process group
settles. It does not force-kill or delete resources. A nonzero/interrupted/missing
outcome requires explicit supervised reconciliation. There is no background
schedule to disable. Do not terminate the existing development app, Redis or DB.

On resume, inspect the checkpoint under the common lock. Reconcile dirty scoped
changes, run outcomes, changed SHA and pending remote actions; preserve counters.
Only the supervisor may update reconciled identity/status or append publication
results. Archive the consumed `tmp/autonomy-result.json` with iteration evidence
before another run; do not discard an unknown outcome. `run` refuses a stale result,
identity mismatch, exhausted budget, existing pilot PR or unreconciled action.
Stopping after publication is final for this pilot; another issue needs approval.
