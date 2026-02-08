---
name: lint
description: Run all linters (Ruby, ERB, JavaScript/TypeScript)
---

# Run All Linters

Run all code linters with auto-fix enabled.

## Commands

### Ruby (Rubocop)
```bash
bin/rubocop -f github -a
```

### ERB Templates
```bash
bundle exec erb_lint ./app/**/*.erb -a
```

### JavaScript/TypeScript (Biome)
```bash
npm run lint:fix
```

## Instructions

1. Run all three linters
2. Report results for each:
   - Rubocop: Number of files inspected, offenses found/corrected
   - ERB Lint: Number of files linted, issues found/corrected
   - Biome: Lint status and any issues
3. If auto-fix makes changes, report what was modified
4. Provide summary of any remaining issues that need manual attention

## Additional Commands

For style checking only (no fixes):
- `npm run lint` - Check JS/TS without fixing
- `npm run style:check` - Check code style only
- `bin/rubocop` - Check Ruby without auto-correct

## Important Notes

- This runs linters only. It is a subset of `/pre-pr`, which also runs tests and security analysis.
- Auto-fix is enabled by default (-a flag)
- Some issues may require manual intervention
- Run `/pre-pr` for the complete CI workflow including tests and security
