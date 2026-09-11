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

**2026-09-10 -- Medicaid scenario's insertion-fee override value, after
replacing the national estimate with a real Colorado rate
(`R/scenarios.R`, `build_scenario_definitions()`).**

Added when the previously-unfound Colorado CPT 58300 Medicaid rate ($58.65)
was located by parsing every worksheet of Colorado HCPF's own physician
fee-schedule workbook directly, replacing the national 2015 estimate
($103, inflation-adjusted) this scenario had used before. Planted defect:
changed the override from `58.65` to `158.65` via a scripted `sed`
substitution.

- **Red:** both the direct assertion on the override value and the
  independent-confirmation test on the resulting standalone total failed
  (off by exactly $100 and $106 respectively, the same propagation pattern
  as the CPT 99213 mutation test above, since this fee flows through the
  same expulsion/escalation-cost formulas).
- **Reverted, confirmed green:** all tests pass again.

**2026-09-10 -- cancer-prevention module's absolute-risk-reduction formula
(`R/cancer_prevention.R`, `compute_iud_absolute_risk_reduction()`).**

Added alongside the new `R/cancer_prevention.R` module. Planted defect:
changed `post_surgery_baseline_risk * (1 - iud_incidence_ratio)` to
`post_surgery_baseline_risk * iud_incidence_ratio` (forgetting to convert
the incidence ratio to a risk *reduction*) via a scripted `sed`
substitution.

- **First attempt found a real blind spot, not a passing test:** the
  initial unit test for this function used `iud_incidence_ratio = 0.50`,
  this project's actual base-case value. 0.50 is a fixed point of
  `x -> 1 - x`, so the buggy and correct formulas produce IDENTICAL
  output at that one value (`0.5 == 1 - 0.5`) -- the mutation was
  invisible, and every downstream test that also happened to use the
  0.50 base case (the full `compute_cancer_prevention_summary()` checks,
  the independent-confirmation test) shared the same blind spot. This is
  exactly the failure mode mutation testing exists to catch: a suite that
  looks thorough but tests only at a value where a real bug is
  numerically silent.
- **Fixed the test, not the code:** rewrote the unit test to use
  deliberately asymmetric inputs (`0.02, 0.3`, expecting `0.02 * 0.7`),
  which cannot coincide under the buggy formula.
- **Red (second attempt):** the corrected unit test failed as expected
  (`0.006` vs `0.014`).
- **Reverted, confirmed green:** all tests pass again.

**2026-09-10 -- perforation cost wired into the cost engine
(`R/strategy_costs.R`, `compute_expected_perforation_cost()`).**

Added when `iud_perforation_risk_baseline` (previously a documented but
completely unused reference row) got a real cost consequence for the
first time, applied identically to both arms. Planted defect: dropped the
probability weighting entirely, returning the raw inflation-adjusted
management cost regardless of perforation probability, via a scripted
`sed` substitution.

- **Red:** 5 tests failed -- the new unit test on
  `compute_expected_perforation_cost()` directly (off by exactly the
  un-weighted cost, approximately $27,614), both `INDEPENDENT
  CONFIRMATION` tests (base case and Medicaid scenario), and the two
  tests asserting `expected_total_cost` sums correctly.
- **Reverted, confirmed green:** all tests pass again.

**2026-09-10 -- one-way sensitivity analysis's low/high override
assignment (`R/sensitivity_deterministic.R`, `run_one_way_sensitivity()`).**

Added alongside the new deterministic sensitivity analysis. Planted
defect: swapped which value (`low_value` vs. `high_value`) gets assigned
to `low_parameters` vs. `high_parameters` via a scripted Python
substitution (a realistic copy-paste mistake between two adjacent,
near-identical override calls).

- **Red:** the `INDEPENDENT CONFIRMATION` test for
  `combined_arm_added_minutes` failed on both `gap_at_low` and
  `gap_at_high` (each off by exactly $318, the size of the swap's
  effect, with the sign flipped between the two assertions -- exactly
  what a low/high swap should produce).
- **Reverted, confirmed green:** all tests pass again.

**2026-09-10 -- scheduling-coordination cost's minutes lookup
(`R/strategy_costs.R`, `compute_scheduling_coordination_cost()`).**

Added alongside the new scheduling-coordination-cost feature (the
gynecologist, not the bariatric surgeon, places the device, so combining
the two procedures requires coordinating two surgeons' OR time). Planted
defect: read `combined_arm_added_minutes` (the clinical OR-time
parameter) instead of `combined_arm_scheduling_coordination_minutes` (the
administrative-coordination parameter) via a scripted `sed`
substitution -- a realistic copy-paste mistake between two
similarly-named `combined_arm_*_minutes` parameters.

- **Red:** 2 tests failed -- the new unit test on
  `compute_scheduling_coordination_cost()` directly (off by exactly $19,
  the difference between 10 minutes at the wrong parameter's value and
  60 minutes at the right one, times the scheduler wage) and the base-case
  `INDEPENDENT CONFIRMATION` test on `expected_total_cost`.
- **Reverted, confirmed green:** all tests pass again.

**2026-09-11 -- combined arm's facility-setting professional fee
(`R/strategy_costs.R`, `compute_combined_strategy_cost()`).**

Added when a real CMS RVU differential (CPT 58300's non-facility total
RVU 3.16 vs. facility total RVU 1.31) showed the combined arm's own
insertion should use a lower, facility-equivalent professional fee
rather than the full office rate standalone uses -- the office rate
bundles overhead the OR/facility already bills separately. Planted
defect: reverted to using the full, unmultiplied
`iud_insertion_professional_fee` for the combined arm (the pre-fix
behavior) via a scripted Python substitution.

- **Red:** 5 tests failed -- both direct assertions on the combined
  arm's `professional_fee` value (base case and Medicaid scenario), the
  new "lower than standalone" comparison test (failed outright: the two
  fees were equal, not lower), and the base-case `INDEPENDENT
  CONFIRMATION` test (off by exactly $68, the size of the missing ratio's
  effect).
- **Reverted, confirmed green:** all tests pass again.
