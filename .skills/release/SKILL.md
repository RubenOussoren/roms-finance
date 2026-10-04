---
name: release
description: Inspect releases or update drafts and publish only with scoped user approval
---

# Release management

Read [shared guidance](../references/operating-guidance.md), `CONTRIBUTING.md`, and the
canonical workflow. Default `/release` or `/release status` is read-only.

## Status

Use `gh release list` and `gh release view` with explicit repository/tag as needed.
Identify the latest published release and draft(s); inspect tags/commit ranges safely.
Do not assume `HEAD` is the release target or interpolate an unverified tag into a shell.
Report target, existing notes, missing refs, and ambiguities; multiple drafts need selection.

## Draft notes

Read the selected draft and relevant diff/PRs. Propose a concise source-backed note and
version/target if creating a draft. Preserve existing notes. Obtain explicit authorization
for the exact repository, tag, target commit, draft creation or edit, and resulting notes
before `gh release create --draft` or `gh release edit`. Use a temporary notes file if
needed, protecting existing files. Never infer a version bump or create a tag implicitly:
verify an existing tag (`--verify-tag` for create), or seek separate tag creation approval.

## Publish

Verify the intended tag/commit, finalized notes, required checks, migration/rollout and
recovery readiness. Use existing test evidence or `/test`; do not append fabricated or
hardcoded suite counts. Show the full release and remaining risks, then require explicit
approval to publish that repository/tag before `gh release edit <tag> --draft=false`.
Report the verified URL and final state.

Approval to edit notes is not approval to publish, tag, push, deploy, or run migrations.
No direct `main` push, automatic release changes after a PR, or deletion of releases/tags.
