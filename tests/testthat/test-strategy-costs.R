test_that("compute_probability_device_placed is 1 for combined, regardless of parameters", {
  model_parameters <- test_model_parameters()
  expect_equal(compute_probability_device_placed(model_parameters, "combined"), 1)
})

test_that("compute_probability_device_placed is 1 minus the loss-to-follow-up probability for standalone", {
  model_parameters <- test_model_parameters()
  expect_equal(compute_probability_device_placed(model_parameters, "standalone"), 1 - 0.257)
})

test_that("compute_expected_missed_cancer_prevention_cost multiplies loss-to-follow-up, the IUD's absolute risk reduction, and the treatment cost", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  reference_year <- get_parameter_value(model_parameters, "reference_dollar_year")

  loss_to_follow_up_probability <- 0.257
  post_surgery_no_iud_risk <- 0.03 * 0.50
  iud_absolute_risk_reduction <- post_surgery_no_iud_risk * (1 - 0.50)
  treatment_cost <- adjust_for_inflation(34982.33, 2015, reference_year, price_index_table)
  expected <- loss_to_follow_up_probability * iud_absolute_risk_reduction * treatment_cost

  expect_equal(
    compute_expected_missed_cancer_prevention_cost(model_parameters, cancer_prevention_parameters, price_index_table),
    expected
  )
})

test_that("only the standalone arm carries a missed-cancer-prevention cost, never the combined arm", {
  # Combined placement is guaranteed (probability_device_placed = 1), so
  # there is no lost-to-follow-up population to apply this cost to.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  standalone_cost <- compute_standalone_strategy_cost(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)
  combined_cost <- compute_combined_strategy_cost(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)

  expect_gt(standalone_cost$expected_missed_cancer_prevention_cost, 0)
  expect_equal(combined_cost$expected_missed_cancer_prevention_cost, 0)
})

test_that("standalone's probability_device_placed is below 1; combined's is exactly 1", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  standalone_cost <- compute_standalone_strategy_cost(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)
  combined_cost <- compute_combined_strategy_cost(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)

  expect_lt(standalone_cost$probability_device_placed, 1)
  expect_equal(combined_cost$probability_device_placed, 1)
})

test_that("expected_cost_per_referred_patient is expected_total_cost times probability_device_placed, plus the missed-cancer-prevention cost", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  standalone_cost <- compute_standalone_strategy_cost(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)
  combined_cost <- compute_combined_strategy_cost(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)

  expect_equal(
    standalone_cost$expected_cost_per_referred_patient,
    standalone_cost$expected_total_cost * standalone_cost$probability_device_placed +
      standalone_cost$expected_missed_cancer_prevention_cost
  )
  # combined's probability is 1 and it never has a missed-cancer-prevention
  # cost, so this equals expected_total_cost exactly.
  expect_equal(combined_cost$expected_cost_per_referred_patient, combined_cost$expected_total_cost)
})

test_that("compute_standalone_strategy_cost sums device + professional fee + office visit + expected replacement + expected escalation", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  standalone_cost <- compute_standalone_strategy_cost(
    model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
  )

  expect_equal(standalone_cost$device_cost, 568.50)
  expect_equal(standalone_cost$professional_fee, 116.08)
  expect_equal(standalone_cost$office_visit_cost, 88.76)
  expect_equal(standalone_cost$expected_replacement_cost, 0.056 * (568.50 + 116.08 + 88.76))
  expect_gt(standalone_cost$expected_escalation_cost, 0)
  expect_gt(standalone_cost$expected_perforation_cost, 0)
  expect_equal(
    standalone_cost$expected_total_cost,
    568.50 + 116.08 + 88.76 +
      0.056 * (568.50 + 116.08 + 88.76) +
      standalone_cost$expected_escalation_cost +
      standalone_cost$expected_perforation_cost
  )
})

test_that("compute_combined_strategy_cost excludes the professional fee when the toggle is FALSE", {
  # Explicitly overrides to FALSE rather than relying on the CSV's current
  # default (TRUE as of 2026-09-10: the gynecologist, not the bariatric
  # surgeon, places the device), so this test exercises the toggle's
  # FALSE branch regardless of what the base case currently defaults to.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  toggled_parameters <- override_model_parameters(
    model_parameters,
    list(combined_requires_separate_professional_fee = FALSE)
  )
  combined_cost <- compute_combined_strategy_cost(
    toggled_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
  )

  expect_equal(combined_cost$professional_fee, 0)
  expect_equal(combined_cost$disposable_supply_cost, 0)
  expect_gt(combined_cost$added_or_cost, 10 * (20.90 + 3.42)) # inflation-adjusted, so strictly bigger than nominal 2014 dollars
  expect_equal(combined_cost$expected_replacement_cost, 0.163 * (568.50 + 116.08 + 88.76))
  expect_gt(combined_cost$expected_perforation_cost, 0)
  expect_gt(combined_cost$scheduling_coordination_cost, 0)
  expect_gt(combined_cost$postop_discussion_cost, 0)
  expect_equal(
    combined_cost$expected_total_cost,
    568.50 + combined_cost$office_visit_cost + combined_cost$added_or_cost +
      0.163 * (568.50 + 116.08 + 88.76) +
      combined_cost$expected_perforation_cost + combined_cost$scheduling_coordination_cost +
      combined_cost$postop_discussion_cost
  )
})

test_that("compute_combined_strategy_cost includes the professional fee when the toggle is TRUE", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  toggled_parameters <- override_model_parameters(
    model_parameters,
    list(combined_requires_separate_professional_fee = TRUE)
  )
  combined_cost <- compute_combined_strategy_cost(
    toggled_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
  )

  # The combined arm's own insertion uses the FACILITY-setting fee (a
  # real CMS RVU differential, since the OR bills its own overhead
  # separately), not the full office rate standalone uses.
  expect_equal(combined_cost$professional_fee, 116.08 * 0.4146)
  expect_equal(combined_cost$disposable_supply_cost, 37.39)
})

test_that("compute_combined_strategy_cost excludes the preop office visit when that toggle is FALSE", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  toggled_parameters <- override_model_parameters(
    model_parameters,
    list(combined_requires_preop_office_visit = FALSE)
  )
  combined_cost <- compute_combined_strategy_cost(
    toggled_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
  )

  expect_equal(combined_cost$office_visit_cost, 0)
})

test_that("compute_combined_strategy_cost includes the preop office visit when that toggle is TRUE (the default)", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  combined_cost <- compute_combined_strategy_cost(
    model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
  )

  expect_equal(combined_cost$office_visit_cost, 125.40)
})

test_that("combined arm's own insertion fee is lower than standalone's, reflecting the real facility/office RVU differential", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  standalone_cost <- compute_standalone_strategy_cost(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)
  combined_cost <- compute_combined_strategy_cost(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)

  expect_lt(combined_cost$professional_fee, standalone_cost$professional_fee)
  expect_equal(combined_cost$professional_fee, standalone_cost$professional_fee * 0.4146)
})

test_that("only the combined arm carries the disposable-supply cost, never the standalone arm", {
  # The supply items (pelvic exam pack, povidone, etc.) are already
  # bundled into the office-rate professional fee standalone uses; adding
  # them there too would double-count. They are excluded from the
  # facility-rate fee combined uses, so must be added back for combined
  # specifically.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  standalone_cost <- compute_standalone_strategy_cost(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)
  combined_cost <- compute_combined_strategy_cost(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)

  expect_equal(standalone_cost$disposable_supply_cost, 0)
  expect_equal(combined_cost$disposable_supply_cost, 37.39)
})

test_that("compute_postop_discussion_cost is discussion minutes times inflation-adjusted gynecologist wage", {
  model_parameters <- test_model_parameters()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  reference_year <- get_parameter_value(model_parameters, "reference_dollar_year")

  expected <- 25 * adjust_for_inflation(2.347, 2025, reference_year, all_items_price_index_table)

  expect_equal(
    compute_postop_discussion_cost(model_parameters, all_items_price_index_table),
    expected
  )
})

test_that("only the combined arm carries the postop-discussion cost, never the standalone arm", {
  # Standalone's own office visit already includes this discussion live,
  # in the same encounter as the insertion itself.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  standalone_cost <- compute_standalone_strategy_cost(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)
  combined_cost <- compute_combined_strategy_cost(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)

  expect_equal(standalone_cost$postop_discussion_cost, 0)
  expect_gt(combined_cost$postop_discussion_cost, 0)
})

test_that("compute_expected_perforation_cost is perforation probability times inflation-adjusted management cost", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  reference_year <- get_parameter_value(model_parameters, "reference_dollar_year")

  expected <- 0.0014 * adjust_for_inflation(20805.84, 2015, reference_year, price_index_table)

  expect_equal(compute_expected_perforation_cost(model_parameters, price_index_table), expected)
})

test_that("both arms carry the identical expected perforation cost, since no setting differential is modeled", {
  # Directly encodes the current, deliberate modeling decision: perforation
  # risk and its management cost do not vary by insertion setting (see
  # iud_perforation_risk_baseline's notes). If a future version adds a
  # setting-based differential, this test should change along with it,
  # not silently start failing.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  standalone_cost <- compute_standalone_strategy_cost(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)
  combined_cost <- compute_combined_strategy_cost(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)

  expect_equal(standalone_cost$expected_perforation_cost, combined_cost$expected_perforation_cost)
})

test_that("compute_scheduling_coordination_cost is coordination minutes times inflation-adjusted scheduler wage", {
  model_parameters <- test_model_parameters()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  reference_year <- get_parameter_value(model_parameters, "reference_dollar_year")

  expected <- 60 * adjust_for_inflation(0.368, 2025, reference_year, all_items_price_index_table)

  expect_equal(
    compute_scheduling_coordination_cost(model_parameters, all_items_price_index_table),
    expected
  )
})

test_that("only the combined arm carries a scheduling-coordination cost", {
  # The standalone arm is a single physician's own routine office visit;
  # only the combined arm needs two surgeons' OR time coordinated.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  standalone_cost <- compute_standalone_strategy_cost(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)
  combined_cost <- compute_combined_strategy_cost(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)

  expect_equal(standalone_cost$scheduling_coordination_cost, 0)
  expect_gt(combined_cost$scheduling_coordination_cost, 0)
})

test_that("combined arm's higher expulsion rate produces a higher expected replacement cost", {
  # Directly encodes the Masten et al. 2024 finding this parameterization is
  # built on: combined placement carries higher expulsion risk, so its
  # expected replacement cost should exceed the standalone arm's, even
  # though both arms replace an expelled device via the same formula.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  standalone_cost <- compute_standalone_strategy_cost(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)
  combined_cost <- compute_combined_strategy_cost(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)

  expect_gt(combined_cost$expected_replacement_cost, standalone_cost$expected_replacement_cost)
})

test_that("only the standalone arm carries a societal patient-time add-on", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  strategy_costs <- compute_strategy_costs(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)

  standalone_row <- strategy_costs[strategy_costs$strategy == "standalone", ]
  combined_row <- strategy_costs[strategy_costs$strategy == "combined", ]

  expect_gt(standalone_row$societal_addon, 0)
  expect_equal(combined_row$societal_addon, 0)
  expect_equal(standalone_row$societal_total_cost, standalone_row$expected_total_cost + standalone_row$societal_addon)
  expect_equal(combined_row$societal_total_cost, combined_row$expected_total_cost)
})

test_that("compute_strategy_costs returns exactly one row per strategy", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  strategy_costs <- compute_strategy_costs(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)

  expect_equal(sort(strategy_costs$strategy), c("combined", "standalone"))
  expect_equal(nrow(strategy_costs), 2)
})

test_that("INDEPENDENT CONFIRMATION: base-case incremental cost matches a from-scratch recomputation", {
  # Re-derives the base-case comparison via a separate code path (raw
  # arithmetic plus direct adjust_for_inflation() calls on the raw
  # parameter rows, not by calling the compute_*_strategy_cost() functions
  # under test) so this check cannot share a bug with the code it verifies.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  reference_year <- get_parameter_value(model_parameters, "reference_dollar_year")

  device <- get_parameter_value(model_parameters, "iud_device_acquisition_cost_gpo")
  professional_fee <- get_parameter_value(model_parameters, "iud_insertion_professional_fee")
  office_visit <- get_parameter_value(model_parameters, "office_visit_em_cost")
  minutes <- get_parameter_value(model_parameters, "combined_arm_added_minutes")
  room_per_min <- adjust_for_inflation(20.90, 2014, reference_year, price_index_table)
  anesthesia_per_min <- adjust_for_inflation(3.42, 2014, reference_year, price_index_table)
  added_or_cost <- minutes * (room_per_min + anesthesia_per_min)
  expulsion_standalone <- get_parameter_value(model_parameters, "iud_expulsion_probability_standalone")
  expulsion_combined <- get_parameter_value(model_parameters, "iud_expulsion_probability_combined")
  failure_probability <- get_parameter_value(model_parameters, "standalone_office_failure_probability")
  patient_time_cost <- adjust_for_inflation(43, 2010, reference_year, all_items_price_index_table)
  replacement_encounter_cost <- device + professional_fee + office_visit
  perforation_probability <- get_parameter_value(model_parameters, "iud_perforation_risk_baseline")
  perforation_cost <- perforation_probability * adjust_for_inflation(20805.84, 2015, reference_year, price_index_table)
  coordination_minutes <- get_parameter_value(model_parameters, "combined_arm_scheduling_coordination_minutes")
  scheduler_wage_per_min <- adjust_for_inflation(0.368, 2025, reference_year, all_items_price_index_table)
  scheduling_coordination_cost <- coordination_minutes * scheduler_wage_per_min
  facility_fee_ratio <- get_parameter_value(model_parameters, "iud_insertion_professional_fee_facility_ratio")
  combined_professional_fee <- professional_fee * facility_fee_ratio
  disposable_supply_cost <- get_parameter_value(model_parameters, "iud_insertion_disposable_supply_cost")
  preop_office_visit_cost <- get_parameter_value(model_parameters, "iud_preop_office_visit_cost")
  discussion_minutes <- get_parameter_value(model_parameters, "combined_arm_postop_discussion_minutes")
  gynecologist_wage_per_min <- adjust_for_inflation(2.347, 2025, reference_year, all_items_price_index_table)
  postop_discussion_cost <- discussion_minutes * gynecologist_wage_per_min

  expected_standalone <- device + professional_fee + office_visit +
    expulsion_standalone * replacement_encounter_cost +
    failure_probability * added_or_cost +
    perforation_cost
  expected_combined <- device + combined_professional_fee + preop_office_visit_cost + disposable_supply_cost +
    added_or_cost + scheduling_coordination_cost + postop_discussion_cost +
    expulsion_combined * replacement_encounter_cost +
    perforation_cost

  strategy_costs <- compute_strategy_costs(model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)

  expect_equal(
    strategy_costs$expected_total_cost[strategy_costs$strategy == "standalone"],
    expected_standalone
  )
  expect_equal(
    strategy_costs$expected_total_cost[strategy_costs$strategy == "combined"],
    expected_combined
  )
  expect_equal(
    strategy_costs$societal_total_cost[strategy_costs$strategy == "standalone"],
    expected_standalone + patient_time_cost
  )

  loss_to_follow_up_probability <- get_parameter_value(model_parameters, "standalone_loss_to_follow_up_probability")

  cancer_lifetime_risk <- get_parameter_value(
    cancer_prevention_parameters, "endometrial_cancer_lifetime_risk_usual_care_bmi40"
  )
  cancer_surgery_hazard_ratio <- get_parameter_value(
    cancer_prevention_parameters, "bariatric_surgery_endometrial_cancer_hazard_ratio"
  )
  cancer_iud_incidence_ratio <- get_parameter_value(
    cancer_prevention_parameters, "iud_endometrial_cancer_incidence_ratio"
  )
  post_surgery_no_iud_risk <- cancer_lifetime_risk * cancer_surgery_hazard_ratio
  iud_absolute_risk_reduction <- post_surgery_no_iud_risk * (1 - cancer_iud_incidence_ratio)
  cancer_treatment_cost <- adjust_for_inflation(34982.33, 2015, reference_year, price_index_table)
  expected_missed_cancer_prevention_cost <- loss_to_follow_up_probability *
    iud_absolute_risk_reduction * cancer_treatment_cost

  expect_equal(
    strategy_costs$expected_cost_per_referred_patient[strategy_costs$strategy == "standalone"],
    expected_standalone * (1 - loss_to_follow_up_probability) + expected_missed_cancer_prevention_cost
  )
  expect_equal(
    strategy_costs$expected_cost_per_referred_patient[strategy_costs$strategy == "combined"],
    expected_combined
  )
})
