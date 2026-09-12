# Testing philosophy

Same standing discipline as the sibling `emb_colonoscopy` project: a test
that gates a correctness claim must be proven to actually detect failure
before it's trusted, not just asserted to work.

## Mutation-test log

**2026-09-12 -- missing-rate NA propagation
(`R/opportunity_cost_national.R`, `compute_multi_hospital_opportunity_cost()`).**

Added when the real 10-hospital dataset was built (Washington has no
Medicare rate; Pennsylvania and Arkansas have no Medicaid rate -- each
a genuine, documented data gap, not an oversight). The function must
propagate these as `NA`, not silently treat a missing rate as zero
revenue. Planted defect: wrapped each rate in `dplyr::coalesce(...,
0)` before the weighted-sum calculation -- a realistic "helpful fix"
mistake someone might make while trying to get every row to return a
number instead of investigating why three rows were NA.

- **Red:** 4 tests failed -- all three "must be NA" assertions
  (Washington, Pennsylvania, Arkansas) now returned a real, silently
  wrong dollar figure instead of `NA`, and the count of complete rows
  changed from 7 to 10.
- **Reverted, confirmed green:** all tests pass again.

**2026-09-12 -- state-level labor-related-share selection, AND a
tolerance-semantics bug caught along the way
(`R/opportunity_cost_national.R`, `compute_state_medicare_payment()`).**

Added when the Denver Health opportunity-cost exercise was extended
into an illustrative national, state-by-state sweep using each state's
own real Medicare wage index. Planted defect: flipped the comparison
direction selecting the labor-related share (`wage_index < 1.0` instead
of `wage_index > 1.0`), via a scripted `sed` substitution -- a realistic
off-by-comparison-direction mistake.

- **First red attempt caught something more important than the planted
  bug.** The two per-state recomputation tests (a high-wage-index state,
  California, and a low-wage-index state, Mississippi) both used
  `tolerance = 0.01`, intending "off by at most a cent." testthat's
  `tolerance` argument is actually RELATIVE, not absolute -- so `0.01`
  meant "off by at most 1%," which is roughly $96 of slack on a $9,651
  Mississippi payment. The mutation's real $85.50 error slipped under
  that 1% threshold and the test PASSED even though the code was wrong
  -- only the California test (a larger $199 error against a $14,267
  base, just over its own 1% threshold) caught anything. A test that
  passes on genuinely wrong output is worse than no test: it was fixed
  before being trusted, not after. Tolerances were tightened to `1e-6`
  (recomputations using the identical formula, so no real rounding
  slack is needed) across both this file and
  `test-opportunity-cost-sensitivity.R`, which had the identical latent
  problem, caught by inspection once the first instance surfaced it.
- **Red (after the tolerance fix):** both the California and
  Mississippi recomputation tests failed, each off by exactly the size
  of using the wrong labor-related share (4 percentage points) for
  that state's wage index.
- **Reverted, confirmed green:** all tests pass again, now with
  tolerances tight enough to mean something.

**2026-09-12 -- displaced-case opportunity-cost margin's sign
(`R/opportunity_cost_sensitivity.R`,
`compute_bounded_displaced_case_opportunity_cost()`).**

Added when a real, payer-specific sensitivity exercise was built for
whether the combined arm's added OR minutes carry a hidden
opportunity-cost-of-a-displaced-case (see
`docs/data_sources.md`). Planted defect: changed the contribution-
margin subtraction to addition (`medicare_payment + national_cost`
instead of `medicare_payment - national_cost`), via a scripted `sed`
substitution -- a realistic sign-flip mistake, and one that would have
silently inverted the entire finding (a large positive "margin" instead
of the real, checkable negative one).

- **Red:** 5 tests failed -- the independent-recomputation test on
  `contribution_margin` and `opportunity_cost_of_added_minutes`, both
  "must be negative" assertions (the mutated version produced a large
  positive value instead), and the low/high-bound ordering test.
- **Reverted, confirmed green:** all tests pass again.

**2026-09-12 -- payer-mix weighting's commercial-fraction term
(`R/opportunity_cost_sensitivity.R`, `compute_payer_mix_weighted_revenue()`).**

Added when the opportunity-cost exercise above was rebuilt using real,
hospital-specific payer rates (Denver Health's own CMS
price-transparency file and Colorado Medicaid's own published rate
tables, both downloaded and parsed directly) instead of a single
generic national Medicare figure -- a correction that reversed the
overall finding's sign (see the file's own "REVISION HISTORY" docstring
and `docs/data_sources.md`). Planted defect: dropped the
`* commercial_fraction` multiplication on the commercial-rate term
(i.e. added the FULL commercial rate to the weighted sum instead of
its ~17% share), via a scripted `sed` substitution -- a realistic
copy-paste-and-forget-one-term mistake in a three-term weighted-average
formula.

- **Red:** 5 tests failed -- the direct `compute_payer_mix_weighted_
  revenue()` unit test and all four downstream
  `compute_bounded_displaced_case_opportunity_cost()` assertions,
  each off by exactly the unweighted-vs-weighted commercial-rate
  difference ($27,314.14 too high on `weighted_revenue`).
- **Reverted, confirmed green:** all tests pass again.

**2026-09-11 -- gamma-fit standard-error scaling
(`R/sensitivity_probabilistic.R`, `fit_gamma_moments()`).**

Added when the probabilistic sensitivity analysis (PSA) was built: five
model parameters are tagged `distribution = "gamma"` in
`config/model_parameters.csv` but have no `gamma_alpha`/`gamma_rate`
pre-computed, so this function fits them by the standard
health-economic-PSA method of moments, treating `low_value`/`high_value`
as a 95% CI and deriving `standard_error = (high - low) / (2 * 1.96)`.
The initial unit test (checking `shape / rate == mean`) could NOT catch
a wrong SE-scaling constant, since that ratio always equals `mean`
regardless of what `standard_error` is -- a genuine blind spot, caught
before it shipped by asking what a specific realistic bug would do to
the test suite. A second test was added that independently recomputes
`shape` and `rate` from the formula's own definition and checks both
values, not just their ratio. Planted defect: dropped the `/ 2` from
the SE formula (`(high - low) / 1.96` instead of `(high - low) / (2 *
1.96)`), via a scripted `sed` substitution -- a realistic off-by-a-
factor-of-2 mistake, since `1.96` alone is ubiquitous as "the 95% CI
z-score" and easy to reach for without the doubling that converts a
half-width into a full range.

- **Red:** 2 tests failed -- both the new `rate` and `shape` assertions
  in the "derives the standard error from a 95% CI" test, each off by
  exactly a factor of 4 (the SE was too small by 2x, so its squared
  reciprocal in `rate` was off by 4x). The original "reproduce the
  target mean exactly" test, as predicted, did NOT fail.
- **Reverted, confirmed green:** all tests pass again.

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

**2026-09-11 -- combined arm's preop-office-visit toggle
(`R/strategy_costs.R`, `compute_combined_strategy_cost()`).**

Added alongside the new preop-consent-visit feature (borrowed from the
sibling `emb_colonoscopy` project's `combined_requires_preop_office_visit`
pattern: a patient cannot consent while already under anesthesia for a
different procedure, so the gynecologist needs a separate earlier
encounter). Planted defect: read `combined_requires_separate_
professional_fee` (a different, similarly-structured toggle) instead of
`combined_requires_preop_office_visit`, via a scripted Python
substitution -- a realistic copy-paste mistake between two adjacent
boolean toggles.

- **Red:** the dedicated "excludes the preop office visit when that
  toggle is FALSE" test failed (off by exactly $125.40, the full preop
  visit cost -- the mutated code read the OTHER toggle, which that test
  left at its default TRUE, so the visit cost was wrongly still charged).
  Every other test stayed green, since both toggles happened to share the
  same default value everywhere else they're exercised -- this is exactly
  why a test targeting each toggle independently, not just the base case,
  was needed to catch this class of bug.
- **Reverted, confirmed green:** all tests pass again.

**2026-09-11 -- postop discussion cost's wage-rate lookup
(`R/strategy_costs.R`, `compute_postop_discussion_cost()`).**

Added alongside the new postop-phone-call feature (the combined arm's
patient is under anesthesia during placement, so the gynecologist has to
discuss results separately, by phone, since IUD insertions do not get a
formal postop visit). Planted defect: read `surgery_scheduler_wage_per_
minute` (the OTHER wage parameter this project uses, for a structurally
identical purpose) instead of `gynecologist_wage_per_minute`, via a
scripted `sed` substitution -- a realistic copy-paste mistake between
two adjacent, near-identical wage-times-minutes cost functions.

- **Red:** 2 tests failed -- the new unit test on
  `compute_postop_discussion_cost()` directly (off by exactly $51.14,
  the difference between the scheduler's lower wage and the
  gynecologist's higher one, times 25 minutes) and the base-case
  `INDEPENDENT CONFIRMATION` test on `expected_total_cost`.
- **Reverted, confirmed green:** all tests pass again.

**2026-09-11 -- standalone's device-placement probability
(`R/strategy_costs.R`, `compute_probability_device_placed()`).**

Added alongside the new loss-to-follow-up feature (a real fraction of
patients scheduled for a standalone interval visit never return for it
at all, distinct from `standalone_office_failure_probability`, which
covers an attempted-but-failed insertion). Planted defect: dropped the
`1 -` complement, returning the raw loss-to-follow-up probability
instead of the probability of actually placing the device, via a
scripted `sed` substitution.

- **Red:** 2 tests failed -- the direct unit-test assertion on
  `compute_probability_device_placed(model_parameters, "standalone")`
  (0.257 vs. the expected 0.743) and the base-case `INDEPENDENT
  CONFIRMATION` test's assertion on `expected_cost_per_referred_patient`
  (off by $422, since the wrong probability multiplier flows straight
  into that derived cost).
- **Reverted, confirmed green:** all tests pass again.

**2026-09-11 -- missed cancer-prevention cost's risk-reduction term
(`R/strategy_costs.R`, `compute_expected_missed_cancer_prevention_cost()`).**

Added when standalone's loss-to-follow-up gap was chained through to a
real downstream outcome (endometrial cancer, this population's actual
stake, in place of the postpartum-LARC literature's unintended-pregnancy
chain), reusing `R/cancer_prevention.R`'s own functions directly rather
than re-deriving the risk arithmetic. Planted defect: used the full
post-surgery-without-IUD cancer risk instead of the IUD's own absolute
risk reduction on top of it (i.e. dropped
`compute_iud_absolute_risk_reduction()`'s `(1 - iud_incidence_ratio)`
factor), via a scripted `sed` substitution -- a realistic conceptual
mistake (confusing "risk without the IUD" with "risk attributable to
missing the IUD specifically").

- **Red:** 2 tests failed -- the new unit test on
  `compute_expected_missed_cancer_prevention_cost()` directly (off by
  exactly $89.60, the size of crediting the IUD with preventing its own
  full post-surgery risk instead of just its own marginal share of it)
  and the base-case `INDEPENDENT CONFIRMATION` test's assertion on
  `expected_cost_per_referred_patient`.
- **Reverted, confirmed green:** all tests pass again.

**2026-09-11 -- mortality-specific hazard ratio sensitivity function's
multiplier
(`R/strategy_costs.R`, `compute_expected_missed_cancer_prevention_cost_at_mortality_hr()`).**

Added after a reviewer asked whether bariatric surgery might also
change *survival* after an endometrial cancer diagnosis (not just
*incidence* beforehand, which `bariatric_surgery_endometrial_cancer_hazard_ratio`
already covers). The only real cohort estimate found for this (Lee et
al. 2021, HR 0.23, 95% CI 0.033-1.70, p=0.15, fewer than 15 deaths) is
not statistically significant, so it is deliberately excluded from the
base case (`bariatric_surgery_endometrial_cancer_mortality_hazard_ratio`'s
`base_value` is fixed at 1) and lives only in this separate,
sensitivity-only function. Planted defect: dropped the
`mortality_hazard_ratio` multiplier entirely (i.e. always applied the
unadjusted mortality-given-diagnosis ratio, regardless of the argument
passed in), via a scripted `sed` substitution -- a realistic mistake
for a sensitivity function specifically built to vary one input.

- **Red:** 3 tests failed -- both CI-sweep assertions (at HR=0.033 and
  HR=1.70, each off by exactly the size of the dropped multiplier's
  effect) and the "lower HR must produce a lower cost" ordering
  assertion, which failed outright since the mutated function no
  longer varied with its own argument at all (both sides of the
  comparison collapsed to the same $89.60 value).
- **Reverted, confirmed green:** all tests pass again.
