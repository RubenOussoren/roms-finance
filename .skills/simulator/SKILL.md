---
name: simulator
description: Create or extend stateful financial simulations using existing interfaces
---

# Financial simulator

Read [shared guidance](../references/operating-guidance.md) and the canonical
architecture/financial contracts. Inspect the closest simulator, its callers, and tests.

1. Define scenario inputs, date progression, rate/renewal conventions, state transitions,
   cash-flow timing, rounding, termination, and output/persistence contract.
2. Use `app/services/` for multi-step simulation and `app/calculators/` for isolated math.
   For debt scenarios, inspect `AbstractDebtSimulator` and existing subclasses before
   reusing their `simulate!` contract; do not assume the generic scaffold fits them.
3. Reuse implemented financial helpers and jurisdiction/assumption resolution. Keep
   simulation state distinct from persistence; document any writes or job side effects.
   Preserve characterized behavior during extraction. Bulk writes bypass validations and
   callbacks: validate generated rows, authorized family ownership, atomic replacement,
   summary/audit effects, retries and concurrent-run safety explicitly. Never infer
   deductibility from a rate alone or label an outcome compliant by default.
4. Compare equivalent baseline/scenario inputs where relevant. Test per-period and final
   balances, principal/interest/tax/cash-flow reconciliation, renewal and payoff edges,
   empty horizons, and adverse outcomes. An “optimized” strategy can lose.
5. Control time and random seeds. Check reproducibility, runtime, and retained output
   size against the actual use case; do not impose arbitrary percentile-only storage.
6. Run focused isolated tests with `/test`; report changed assumptions and limitations.

Optional generic scaffolds: [class](templates/simulator.rb.template) and
[test](templates/simulator_test.rb.template). Adapt to the verified interface; do not
copy into debt subclasses or assume jurisdiction/PAG methods exist.
