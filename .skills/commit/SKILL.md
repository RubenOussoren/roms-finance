---
name: commit
description: Prepare and create a scoped git commit only with explicit user authorization
---

# Scoped commit

Read [shared guidance](../references/operating-guidance.md), `AGENTS.md`, and
`CONTRIBUTING.md` for current workflow and message conventions.

1. Inspect `git status --short`, `git diff`, `git diff --cached`, and recent commit style.
   Identify task-owned changes versus other agents/users; never sweep unrelated work
   into the commit or unstage their files automatically.
2. Summarize the exact file scope, verification, and proposed concise imperative message.
   Creating a commit requires explicit user authorization; a request to implement/test
   or “prepare a commit” is not authorization to commit. Ask if scope is ambiguous.
3. Once authorized, stage only explicit approved paths (not `git add .`/`-A`), inspect the
   staged diff again, and commit. If unrelated staged content remains, stop and ask.
   Use repository attribution rules if present; do not invent a model identity/trailer.
4. Verify with `git show --stat --oneline HEAD` and `git status --short`; report hash,
   included scope, and remaining changes.

Never alter git configuration, skip hooks, force/reset/clean, or amend without specific
approval. Exclude secrets and credentials. A commit does not authorize a push or PR;
never push directly to `main` (or another protected base branch).
