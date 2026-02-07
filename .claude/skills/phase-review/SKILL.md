---
name: phase-review
description: >
  Run a structured post-phase code review on a Rails codebase after an implementation phase completes.
  Triggers: any request to review, audit, or validate code changes after a phase, sprint, or PR batch —
  especially when checking for DRY violations, spaghetti code, architectural coherence, test quality,
  and documentation completeness. Also triggers when a user says "review phase X", "check the code quality",
  "audit the changes", or "run the post-phase review". Produces a structured verdict with pass/fail per
  dimension and actionable fix-it items. Designed to be fast and lightweight — a quality gate, not a rewrite.
---

# Phase Review — Post-Phase Code Quality Gate

A lightweight, repeatable review skill that runs after each implementation phase to catch quality regressions before they compound. Takes 10-15 minutes per phase. Produces a structured pass/fail verdict.

## When to Use

Run this after every implementation phase completes, before starting the next phase. It catches:
- DRY violations and copy-paste drift
- Spaghetti code and tangled dependencies
- Architectural fragmentation (features that don't integrate cleanly)
- Missing or bloated documentation
- Test gaps that don't match the phase's scope

## Workflow

1. **Identify the phase** — ask what phase just completed and what files changed
2. **Run the five review dimensions** — each produces a pass/warn/fail verdict
3. **Compile the verdict** — a single summary with fix-it items
4. **Output the report** — structured markdown, saved to `reviews/phase-X-review.md`

## Step 1: Identify the Phase

Ask the user (skip if already provided):
- Which phase just completed (number and name)
- The branch or commit range (or ask them to provide a diff)

Then identify the changed files. Use `git diff --name-only` against the base branch or previous phase tag. If git isn't available, ask the user to list the key files that were added or modified.

Group the changed files into categories:
- **Models/concerns** — `app/models/`, `app/models/concerns/`
- **Services/calculators** — `app/services/`, `app/calculators/`, `lib/`
- **Controllers** — `app/controllers/`
- **Views/partials** — `app/views/`, `app/helpers/`, `app/javascript/`
- **Tests** — `spec/`, `test/`
- **Migrations** — `db/migrate/`
- **Config/docs** — `config/`, `*.md`, `doc/`

## Step 2: Run the Five Review Dimensions

Work through each dimension in order. For each, read the relevant files and produce a **pass**, **warn**, or **fail** verdict with specific evidence.

### Dimension 1: DRY & Code Reuse

**What to check:**
- Search for duplicated logic across the changed files. Use text similarity — if two methods share more than 5 consecutive lines of meaningful logic (not boilerplate), flag it.
- Check if the phase introduced logic that already exists elsewhere in the codebase. Search for method names, formula patterns, and SQL fragments.
- Check if extracted shared modules/concerns are actually reused (not just extracted for one caller).
- Check for magic numbers or hardcoded values that should be constants or configuration.

**How to check efficiently:**
```bash
# Find potential duplication in changed files
git diff --name-only main | xargs grep -n 'def \|private\|module ' | sort
# Look for repeated patterns
git diff main -- app/ lib/ | grep '^+' | sort | uniq -d
```

**Pass criteria:** No meaningful duplication. Shared logic lives in one place. Constants are named.
**Warn criteria:** Minor duplication (< 5 lines) or one instance of reimplemented existing logic.
**Fail criteria:** Significant duplication (> 10 lines copied), shared modules with a single caller, or formulas implemented in multiple places.

### Dimension 2: Code Structure & Readability (Anti-Spaghetti)

**What to check:**
- Method length: flag any method over 25 lines (excluding blank lines and comments).
- Class length: flag any class over 200 lines.
- Nesting depth: flag logic nested more than 3 levels deep.
- Dependency direction: new code should depend on abstractions, not reach into the internals of other classes. Look for long chains like `account.family.projections.first.assumptions.volatility`.
- Circular dependencies: check if file A requires/references file B and B references A.
- Single Responsibility: each class/module should have one reason to change. If a commit touches a file for two unrelated reasons, the file may need splitting.

**How to check efficiently:**
```bash
# Find long methods in changed files
git diff --name-only main -- app/ lib/ | xargs ruby -e '
  ARGV.each do |f|
    next unless File.exist?(f)
    lines = File.readlines(f)
    in_method = false; method_start = 0; method_name = ""
    lines.each_with_index do |line, i|
      if line =~ /^\s*def\s+(\w+)/
        in_method = true; method_start = i; method_name = $1
      elsif in_method && line =~ /^\s*end\b/
        len = i - method_start
        puts "#{f}:#{method_start+1} #{method_name} (#{len} lines)" if len > 25
        in_method = false
      end
    end
  end
'
```

**Pass criteria:** All methods < 25 lines, no deep nesting, clear dependency direction.
**Warn criteria:** 1-2 methods slightly over 25 lines, or one instance of moderate nesting.
**Fail criteria:** God methods (50+ lines), circular dependencies, or classes doing multiple unrelated jobs.

### Dimension 3: Architectural Coherence

**What to check:**
- Do the changes integrate cleanly with the existing app architecture, or do they create parallel/shadow systems?
- If new patterns were introduced (new base classes, new concern patterns, new service object conventions), do they align with existing patterns or conflict?
- Check that new database tables/columns have appropriate associations defined in models.
- Check that new routes follow existing naming conventions.
- Check that new services/calculators follow the existing interface patterns (e.g., if existing calculators take explicit args and return values, new ones shouldn't rely on global state).
- Check for orphaned code: files added but never referenced, methods defined but never called.

**How to check efficiently:**
```bash
# Find new files and check they're referenced somewhere
git diff --name-only --diff-filter=A main | while read f; do
  base=$(basename "$f" .rb | sed 's/_/ /g')
  count=$(grep -rl "$(echo $base | sed 's/ /./g')" app/ lib/ spec/ --include='*.rb' | wc -l)
  [ "$count" -le 1 ] && echo "ORPHAN? $f (referenced in $count files)"
done
```

Refer to `references/architecture-checklist.md` for the full checklist organized by layer.

**Pass criteria:** Changes follow existing patterns. New code is discoverable and referenced. No parallel systems.
**Warn criteria:** Minor pattern deviation that's justified and documented.
**Fail criteria:** Shadow implementations, orphaned files, broken associations, or convention-breaking patterns without justification.

### Dimension 4: Test Coverage & Quality

**What to check:**
- Every new public method should have at least one test. Every bug fix should have a regression test.
- Tests should assert on behavior/outputs, not implementation details (don't test private methods directly, don't assert on internal variable names).
- Tests should be deterministic — no random seeds without fixing, no time-dependent assertions without time control.
- Check that financial calculations have known-value assertions (not just "output is a number").
- Check that the phase's golden-master fixtures were updated if outputs changed.

**How to check efficiently:**
```bash
# Compare new app methods to new test coverage
echo "=== New methods ==="
git diff main -- app/ lib/ | grep '^+.*def ' | grep -v 'private\|protected'
echo "=== New test cases ==="
git diff main -- spec/ test/ | grep '^+.*\(it \|test \|describe \|context \)'
```

**Pass criteria:** All new public methods tested. Financial calculations use known-value assertions. Golden masters updated.
**Warn criteria:** Minor gaps (1-2 untested helpers or edge cases).
**Fail criteria:** Core logic untested, financial formulas without known-value assertions, or golden masters not updated after output changes.

### Dimension 5: Documentation Quality

**What to check:**
- New public APIs (methods, services, calculators) should have a brief comment explaining what they do, what they accept, and what they return. One to three lines is ideal.
- Complex financial formulas should have a comment citing the source or explaining the math.
- README, CHANGELOG, or phase-specific docs should be updated if user-facing behavior changed.
- Check for documentation bloat: comments that just restate the code, excessive inline comments on obvious logic, or docs that are longer than the code they describe.
- Check that migration files have a comment explaining why the change was made (not just what).

**The golden rule for documentation:** If removing the comment would make a future developer pause and wonder "why?", the comment should stay. If removing it loses nothing, it shouldn't be there.

**Pass criteria:** Public APIs documented concisely. Formulas cite sources. No bloat. Docs updated for user-facing changes.
**Warn criteria:** Minor gaps (1-2 undocumented public methods) or slight bloat.
**Fail criteria:** Complex financial logic with no explanation, or documentation that's longer than the code it describes.

## Step 3: Compile the Verdict

Produce a structured verdict in this exact format:

```markdown
# Phase Review: Phase [X] — [Name]
**Date:** [date]
**Files changed:** [count]
**Verdict:** [PASS / PASS WITH WARNINGS / FAIL — FIXES REQUIRED]

## Scorecard
| Dimension | Verdict | Key Finding |
|-----------|---------|-------------|
| DRY & Code Reuse | ✅ Pass / ⚠️ Warn / ❌ Fail | [one-line summary] |
| Code Structure | ✅ Pass / ⚠️ Warn / ❌ Fail | [one-line summary] |
| Architecture Coherence | ✅ Pass / ⚠️ Warn / ❌ Fail | [one-line summary] |
| Test Coverage | ✅ Pass / ⚠️ Warn / ❌ Fail | [one-line summary] |
| Documentation | ✅ Pass / ⚠️ Warn / ❌ Fail | [one-line summary] |

## Fix-It Items (if any)
[Numbered list of specific, actionable items. Each must name the file, the problem, and what to do about it.]

## Observations
[2-3 sentences on overall quality trends. What's improving? What's drifting?]
```

**Overall verdict logic:**
- **PASS**: All dimensions pass.
- **PASS WITH WARNINGS**: No fails, but 1+ warnings. OK to proceed to next phase, but address warnings within the next phase.
- **FAIL — FIXES REQUIRED**: Any dimension fails. Do not proceed to the next phase until fix-it items are resolved and the review is re-run.

## Step 4: Output the Report

Save the report to `reviews/phase-[X]-review.md` in the project root (create the `reviews/` directory if it doesn't exist). Also display the scorecard summary in the conversation.

If this is a re-review (fixing items from a previous fail), title it `Phase [X] — Re-review` and reference which fix-it items were addressed.

## Important Principles

- **Be fast, not exhaustive.** This is a quality gate, not a code audit. Spend 10-15 minutes, catch the big stuff, and move on. If something feels off but you can't pin it down quickly, flag it as a warning with a note to revisit.
- **Evidence over opinion.** Every warn or fail must cite a specific file and line number. "The code feels messy" is not a finding. "`simulate_modified_smith!` at line 145 is 87 lines long with 4 levels of nesting" is a finding.
- **Respect intentional tradeoffs.** If a phase deliberately chose simplicity over DRY (e.g., inlining a formula that's only used once), that's fine. Flag it only if the tradeoff isn't documented.
- **Cumulative awareness.** If you've run this on previous phases, note trends. "This is the third phase where test documentation is missing — consider adding it to the phase prompt template."
