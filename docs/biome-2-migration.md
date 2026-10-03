# Biome 2 migration

## Dependency and configuration

Upgrade `@biomejs/biome` from locked 1.9.3 to **2.5.15**, pinned exactly in
`package.json`. The lockfile was updated with
`npm install --save-dev --save-exact --package-lock-only @biomejs/biome@2.5.15`,
not regenerated. Only the root Biome requirement and Biome/platform-package
entries changed; Playwright, playwright-core, and fsevents entries are identical
to the baseline. Registry-provided metadata changes are confined to Biome entries.

Previewed `biome migrate`, applied `biome migrate --write`, and reviewed the
result deliberately:

- Update the schema to 2.5.15.
- Replace `files.include` with `files.includes`, remove the empty `files.ignore`,
  and normalize the glob to `app/javascript/**/*.js`.
- Move import organization to `assist.actions.source.organizeImports: "on"`.
- Replace `rules.recommended: true` with `rules.preset: "recommended"`.
- Preserve VCS settings, EditorConfig support, double quotes, and the existing
  `complexity.noForEach: "off"` exception. No rules were weakened or new
  suppressions introduced. Existing npm scripts are unchanged.

## Diagnostics versus baseline

Biome 1.9.3 `npm run lint` passed with no diagnostics. The first Biome 2 run
reported 1 error, 11 warnings, and 1 informational diagnostic. Targeted manual
changes resolve them without a bulk formatter or lint auto-fix:

- Use a block body for the bulk-select `forEach` callback so it does not return
  a value.
- Mark intentionally unused callback parameters with underscores and remove
  unused destructured values, the unused catch binding, and an unused Sankey
  import.
- Use optional chaining for the chat command guard.
- Parse the auto-submit debounce timeout explicitly as base-10 milliseconds.
  Decimal timeout behavior is unchanged; hexadecimal-prefixed strings are no
  longer implicitly interpreted as hexadecimal.

`npm run style:check -- --max-diagnostics=none` failed on the baseline with
22 formatting errors. Biome 2 initially reported those same 22 files plus three
new import-assist errors in `controllers/index.js` and the two D3 default-export
shims. Manually order/group the controller imports and separate the shim imports
from their exports. The final style check has **22 formatting errors in exactly
the same files as the baseline**, with no remaining import-assist or lint
errors. Pre-existing formatting debt is deliberately not rewritten in this
migration; full style-check success remains a separate cleanup task.

## Verification

All commands ran with host Node **v20.19.2** and npm **9.2.0**, inside the isolated
`tmp/maintenance-biome` worktree; no containers were used. npm's download cache
and comparison logs were kept under that worktree's ignored `tmp/` directory.
A temporary baseline snapshot was removed before final verification because
Biome 2 discovers nested configuration files even outside the selected glob.

- Baseline `npm ci` and `npm run lint`: pass, 54 checked files.
- Final `npm ci`: pass, 0 reported vulnerabilities.
- Final `npm run lint`: pass, no diagnostics.
- Final `npm run lint -- --error-on-warnings --max-diagnostics=none`: pass.
- Verbose baseline/final lint file lists: identical 53 application JavaScript
  files plus the configuration file (54 total).
- `biome migrate`: reports the configuration is up to date.
- `npm run style:check -- --max-diagnostics=none`: baseline formatting debt
  only, as described above.
- Programmatic lockfile comparison: all non-Biome package entries unchanged.
- `git diff --check`: pass.

No Rails or browser tests were run: this is a development-tool/configuration
migration with narrowly scoped diagnostic fixes. No database, Redis, deployment,
or environment-variable changes are required.
