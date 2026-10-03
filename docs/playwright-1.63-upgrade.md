# Coordinated Playwright 1.63 toolchain

The npm `@playwright/test`, `playwright`, and `playwright-core` packages and Ruby
`playwright-ruby-client` are locked to **1.63.0**. The Ruby client's
`Playwright::COMPATIBLE_PLAYWRIGHT_VERSION` reports 1.63.0. Chromium build **1243**
(Chrome for Testing 153.0.8010.12) was provisioned with that actual locked CLI in
the isolated validation container.

The app uses Capybara's Playwright driver with Chromium; it does not directly use
npm's JavaScript test runner APIs. The driver's Ruby dependency allows the updated
client. Browser/driver compatibility was established by all 72 existing system
tests, not inferred from permissive dependency constraints or an old green check.

Previously CI installed a different Ruby-compatible npm CLI using `--no-save`,
masking drift from the lockfile used by README local commands. CI now uses Node 22,
`npm ci`, `bundle exec ruby bin/verify-playwright`, and the **installed** CLI via
`npx --no-install`. The version check requires all three installed npm package
versions to equal the Ruby compatibility constant. A deliberately mismatched
isolated package was rejected, then restored; the matching candidate passed.
Do not restore the unlocked install workaround to bypass this gate.

Follow the [README sandbox verification](../README.md#sandbox-verification) to
install browser OS dependencies and the matching Chromium after container
recreation. Update Ruby/npm together, reinstall with `npm ci`, and reprovision
Chromium when updating Playwright. No new environment variable or database
migration is required.

## Validation

All local Rails test invocations explicitly used
`RAILS_ENV=test POSTGRES_DB=roms_test REDIS_URL=redis://redis:6379/2` in the isolated
validation project, never the live sandbox:

- 1,987 unit/integration tests, 9,464 assertions, zero failures/errors,
  16 unchanged skips.
- All 72 Chromium system tests, 253 assertions, zero failures/errors/skips,
  using Ruby/npm 1.63.0 and its downloaded browser, without `--no-save` installs.
- Ruby/JavaScript lint, Brakeman, refreshed Ruby/importmap/npm audits, Zeitwerk,
  and workflow validation passed.
- Fresh GitHub CI on current main must pass, replacing #99's cancelled test check.
