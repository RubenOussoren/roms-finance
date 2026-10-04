---
name: pr
description: Draft or create a pull request with authorized feature-branch publication
---

# Pull request

Read [shared guidance](../references/operating-guidance.md), `CONTRIBUTING.md`, and the
canonical development workflow. Preparation is read-only; publishing requires explicit
user authorization for both the feature-branch push and PR creation.

1. Inspect status, current branch/tracking, repository/remote, and intended base (normally
   `main` per repository guidance). Review all commits and the merge-base diff, not just
   the latest commit. Do not checkout/reset/stash away another agent’s work.
2. Run or gather `/pre-pr` evidence; disclose failures and blockers. Draft a title/body
   covering behavior, issue links, actual checks, migration/rollout/env/provider changes,
   and screenshots where relevant. Do not mark unrun tests complete.
3. Confirm repository, head branch, base, draft/ready state, and body with the user when
   not already authorized. No automatic commit or release-note update. If publication
   is needed, get authorization naming remote and branch; never push directly to `main`
   or another protected base branch, force-push, or silently change the base.
4. Push only the approved feature branch, then use `gh pr create` with explicit base/head
   and approved title/body/draft option. If an existing PR exists, report it rather than
   creating duplicates or editing it without approval.
5. Return the verified PR URL and check status. Local success does not imply GitHub
   checks passed; report pending checks and next steps.
