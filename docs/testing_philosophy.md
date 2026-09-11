# Testing philosophy

Same standing discipline as the sibling `emb_colonoscopy` project: a test
that gates a correctness claim must be proven to actually detect failure
before it's trusted, not just asserted to work.

## Mutation-test log

**2026-09-11 -- expulsion-probability parameter assignment
(`R/strategy_costs.R`, `compute_standalone_strategy_cost()` /
`compute_combined_strategy_cost()`).**

Added when the Masten et al. 2024 expulsion-risk finding was wired into the
cost engine. Planted defect: swapped which expulsion-probability parameter
each strategy's `compute_expected_replacement_cost()` call uses (standalone
strategy called with `"iud_expulsion_probability_combined"` and vice versa)
via a scripted `sed` substitution, so the swap is real and mechanical, not
just described.

- **Red:** `test-strategy-costs.R` failed on 3 assertions -- the
  "combined arm's higher expulsion rate produces a higher expected
  replacement cost" check (`43.3 <= 126.1`, i.e. the swap made standalone's
  replacement cost the larger one) and both independent-confirmation
  assertions (off by exactly $82.70 in each direction, the size of the
  swap's effect).
- **Reverted, confirmed green:** all tests pass again with the correct
  parameter assignment restored.

This is exactly the kind of bug a reviewer could introduce accidentally
(copy-pasting one strategy's cost function into the other and forgetting to
update which probability it reads), and the test suite catches it.

**2026-09-11 -- escalation-cost probability weighting
(`R/strategy_costs.R`, `compute_standalone_strategy_cost()`).**

Added alongside the failure-escalation cost (Saito-Tom et al. 2015) and
the societal patient-time add-on. Planted defect: hardcoded the escalation
cost to always apply (multiplied `compute_added_or_cost()` by `1` instead
of `failure_probability`) via a scripted `sed` substitution.

- **Red:** the independent-confirmation test failed on both the
  healthcare-sector and societal-total assertions, off by exactly $318 in
  each case (the size of applying the full escalation cost unconditionally
  instead of weighting it by the ~4% failure probability).
- **Reverted, confirmed green:** all tests pass again.

**2026-09-11 -- Medicaid scenario's office-visit override value
(`R/scenarios.R`, `build_scenario_definitions()`).**

Added alongside the Medicaid payer scenario. Planted defect: changed the
real Colorado Medicaid CPT 99213 rate override from `77.39` to `177.39`
via a scripted `sed` substitution.

- **Red:** both the direct assertion on the override value and the
  independent-confirmation test on the resulting standalone total failed
  (off by exactly $100 and $106 respectively, the latter reflecting the
  $100 error propagating through the expulsion/escalation-cost formulas
  that multiply it).
- **Reverted, confirmed green:** all tests pass again.
