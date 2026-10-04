---
name: test
description: Run targeted or full Minitest checks using isolated offline test infrastructure
---

# Run tests

Read [shared guidance](../references/operating-guidance.md) and
`docs/development/workflow.md`. Complete the shared test preflight before booting Rails:
explicit `RAILS_ENV=test`, dedicated DB and Redis, no live provider credentials/calls.

1. Select the smallest useful scope: `bin/rails test test/models/account_test.rb:42`,
   a test file, or `bin/rails test` for the full unit/integration suite. Set approved
   isolation variables in the process environment; do not pass arbitrary user text to
   a shell. Disable parallelization initially to avoid unexpected worker databases.
2. Use fixtures, existing VCR replay, and mocks. Inspect provider tests for recording
   options; enforce network blocking, not just sandbox flags. No new live recordings.
3. If the schema is missing/stale, stop and propose the exact isolated DB operation
   through `/db` and `/migration`. No automatic `db:prepare`, reset, schema load, or
   `test:db`; fixture loading and Rails schema maintenance can themselves overwrite data.
4. Use `bin/rails test:system` only for UI flows needing a browser. Verify the configured
   driver and local app endpoint. Missing browser tooling is a blocker, not permission
   to install software or connect to a deployed app. Specific system files can be run
   with `bin/rails test test/system/<file>_test.rb` after driver setup is verified.
5. Report command, redacted isolation targets, exit status, tests/assertions/failures/errors,
   relevant failure details, and skips. Separate infrastructure failures from regressions.
   Do not claim full-suite success after a focused run or conceal status behind a pipe.
