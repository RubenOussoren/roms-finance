---
name: setup
description: Inspect and safely prepare a platform-appropriate development environment
---

# Development setup

Read [shared guidance](../references/operating-guidance.md) and
`docs/development/workflow.md`. `/setup check` is inspection only; default setup begins
with inspection and a proposed plan, not a bootstrap script.

1. Inspect `.ruby-version`, Gemfile/lockfile, package metadata/lockfile, runtime pins in
   current CI/container configuration, and available tools. Use `ruby --version`,
   `node --version`, `bundle check`, and `npm ls --depth=0` as applicable. Derive supported
   versions from the repository; do not prescribe an old Node version or macOS tooling.
2. Inspect environment loading and database/Redis configuration without exposing secrets.
   Check approved endpoints with `pg_isready` and Redis `PING`; no automatic service start.
   Offer OS-appropriate or documented container commands for missing prerequisites.
3. Never overwrite `.env.local`. Copy an example only if absent and needed; ensure local
   credentials and endpoints, not production/provider secrets. Dependency installs use
   lockfiles (e.g. `bundle install`, `npm ci`) and must not silently update them.
4. Read setup scripts before proposing execution. `bin/setup` can prepare/migrate/seed,
   clear logs/tempfiles and restart; `bin/setup-complete` can start services, mutate data,
   and create users. Do not run either automatically or as a fallback after failure.
5. Separate dependency/asset work from data operations. Use `/db` for explicitly approved
   database setup or seeds and `/migration` for schema safety. Demo tasks require the same
   destructive-data safeguards, not a presumed clean database. Do not invent test users
   or print fixed/shared passwords.
6. Build required assets using verified repository tasks; use `/test` for validation only
   after isolated DB/Redis and provider guards are confirmed. Do not start the app/workers.

Report ready/not ready per check, redacted targets, proposed actions requiring approval,
and blockers. A failed prerequisite is not permission to reset or migrate anything.
