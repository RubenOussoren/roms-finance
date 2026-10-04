Execute only the approved issue #151 pilot described in docs/development/autonomy.md.
First read AGENTS.md, CONTRIBUTING.md and docs/DEVELOPER_GUIDE.md. Verify the parent
runner holds the shared-repository flock and has reconciled checkpoint counters,
branch/SHA, worktree and resource ownership. Without those gates, stop and report
blocked. Read the checkpoint provided by the runner; never initialize a fresh
budget on resume. Roadmap PR #155 is merged; backlog #120 remains open.

Implement the smallest scoped change, verify via the inspected branch-aware
bin/autonomy-check, and use only the approved scoped publication actions. Maximum:
one implementation PR, five cumulative iterations, two unsuccessful repair
approaches. Ask for policy-sensitive changes. No recurring jobs, service install,
merge, deploy or production. Use existing configured routing, no model overrides.
Checkpoint outcomes and pending external mutations, stop on TERM or a limit,
and provide exact evidence and remaining approvals. Never mark readiness on a
missing test result or bypassed isolation gate.
