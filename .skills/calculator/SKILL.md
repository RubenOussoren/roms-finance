---
name: calculator
description: Create or extend financial calculators with explicit inputs and tested contracts
---

# Financial calculator

Read [shared guidance](../references/operating-guidance.md), especially the canonical
financial contracts and current-state architecture, before choosing an interface.

1. Clarify inputs, units, currency, dates, rate convention, rounding, output, and
   invalid-input behavior. Read the closest calculator and its callers/tests.
2. Put deterministic math in `app/calculators/` with matching Minitest coverage in
   `test/calculators/`. Existing calculators may read models, time, or random state:
   characterize behavior before extraction and preserve compatibility wrappers. Resolve
   database-backed assumptions outside new math boundaries; do not add writes, provider
   calls, or cache side effects to new pure calculations.
3. Reuse actual financial helpers rather than duplicating formulas. Only include
   concerns after reading their implementation and verifying receiver requirements;
   including a concern alone does not establish PAG compliance or jurisdiction support.
4. Test independently derived known values, zero rates and horizons, negative returns
   where valid, boundary dates, units, rounding, and invalid inputs. Distinguish missing
   from zero and capped/unreachable results from payoff. Distinguish nominal from
   effective rates and beginning- from end-of-period cash flows; separate structural
   extraction from financial corrections.
5. Run focused tests using `/test`; review the diff and report contract changes.

Optional scaffolds: [class](templates/calculator.rb.template) and
[test](templates/calculator_test.rb.template). Replace all placeholders and adapt the
entry point/result to real callers; these are not application APIs or finance formulas.
