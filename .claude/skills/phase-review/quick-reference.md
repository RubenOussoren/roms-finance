# Phase Review — Quick Reference

## The Five Dimensions

| # | Dimension | Core Question | Red Flag |
|---|-----------|--------------|----------|
| 1 | DRY & Code Reuse | Is any logic written twice? | Same formula in two files |
| 2 | Code Structure | Can I follow the logic in one read? | Method > 25 lines, nesting > 3 deep |
| 3 | Architecture Coherence | Does this fit the app, or fight it? | Parallel system, orphaned file |
| 4 | Test Coverage | Would this catch a regression? | Financial math without known-value test |
| 5 | Documentation | Would a new dev understand why? | Complex formula with no comment |

## Verdict Rules

- **PASS** = all five dimensions pass
- **PASS WITH WARNINGS** = no fails, 1+ warns → proceed but fix in next phase
- **FAIL** = any dimension fails → fix before next phase

## Evidence Standards

Every warn or fail must include:
1. **File path** and line number
2. **What's wrong** (specific, not vague)
3. **What to do** (actionable fix)

Bad: "The code is messy"
Good: "`app/services/smith_simulator.rb:145` — `simulate_modified_smith!` is 87 lines with 4 nesting levels. Extract monthly cycle steps into private methods."

## Time Budget

Target 10-15 minutes total:
- 2 min: identify changed files
- 2 min each dimension: 10 min
- 3 min: compile verdict and fix-its
