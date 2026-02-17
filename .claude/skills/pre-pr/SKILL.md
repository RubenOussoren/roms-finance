---
name: pre-pr
description: Run all pre-pull request checks (tests, linters, security analysis, dependency audits)
---

# Pre-Pull Request Checks

Run the complete CI workflow before opening a pull request. This skill runs all required checks as defined in CLAUDE.md.

## Workflow

Execute the following checks in order:

### 1. Run Tests (Required)
```bash
bin/rails test
```

### 2. Run Ruby Linting (Required)
```bash
bin/rubocop -f github -a
```

### 3. Run ERB Linting (Required)
```bash
bundle exec erb_lint ./app/**/*.erb -a
```

### 4. Run Security Analysis (Required)
```bash
bin/brakeman --no-pager
```

### 5. Run JS Dependency Audit (Required)
```bash
bin/importmap audit
```

### 6. Run JS/TS Linting (Required)
```bash
npm run lint
```

## Instructions

1. Run all six checks above sequentially
2. Report the status of each check (pass/fail)
3. If any check fails, report which check failed and show the relevant error output
4. Only report "Ready for PR" if ALL checks pass
5. Provide a summary at the end showing:
   - Tests: ✅/❌ (number of tests, assertions)
   - Rubocop: ✅/❌ (number of offenses)
   - ERB Lint: ✅/❌ (number of issues)
   - Brakeman: ✅/❌ (number of warnings)
   - Importmap Audit: ✅/❌ (any vulnerable packages)
   - JS/TS Lint: ✅/❌ (any issues)

## Important Notes

- Expected test count: ~1363+ tests. A significant drop may indicate missing test files.
- Do NOT proceed with PR creation if any check fails
- Auto-fix is enabled for rubocop and erb_lint (-a flag)
- If auto-fix makes changes, report what was fixed
- Brakeman warnings should be reviewed even if they don't fail the check
