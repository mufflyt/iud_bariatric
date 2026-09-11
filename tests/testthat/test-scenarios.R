test_that("build_scenario_definitions returns base_case and medicaid_illustrative", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  scenario_definitions <- build_scenario_definitions(model_parameters)

  expect_equal(sort(names(scenario_definitions)), c("base_case", "medicaid_illustrative"))
  expect_false(scenario_definitions$base_case$provisional)
  expect_true(scenario_definitions$medicaid_illustrative$provisional)
})

test_that("base_case scenario has no overrides and reproduces compute_strategy_costs() exactly", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()

  scenario_definitions <- build_scenario_definitions(model_parameters)
  expect_equal(scenario_definitions$base_case$overrides, list())

  scenario_results <- run_scenario_analysis(model_parameters, price_index_table, all_items_price_index_table)
  base_case_rows <- scenario_results[scenario_results$scenario == "base_case", ]
  direct_rows <- compute_strategy_costs(model_parameters, price_index_table, all_items_price_index_table)

  expect_equal(
    base_case_rows$expected_total_cost[base_case_rows$strategy == "standalone"],
    direct_rows$expected_total_cost[direct_rows$strategy == "standalone"]
  )
  expect_equal(
    base_case_rows$expected_total_cost[base_case_rows$strategy == "combined"],
    direct_rows$expected_total_cost[direct_rows$strategy == "combined"]
  )
})

test_that("medicaid_illustrative scenario uses the real Colorado CPT 99213 rate", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  scenario_definitions <- build_scenario_definitions(model_parameters)

  expect_equal(scenario_definitions$medicaid_illustrative$overrides$office_visit_em_cost, 77.39)
})

test_that("medicaid_illustrative scenario uses the real Colorado CPT 58300 rate", {
  model_parameters <- test_model_parameters()
  scenario_definitions <- build_scenario_definitions(model_parameters)

  expect_equal(scenario_definitions$medicaid_illustrative$overrides$iud_insertion_professional_fee, 58.65)
})

test_that("medicaid_illustrative and base_case combined arms both pay a separate professional fee, at different rates", {
  # combined_requires_separate_professional_fee now defaults to TRUE in
  # the base case too (2026-09-10: the gynecologist, not the bariatric
  # surgeon, places the device), so the medicaid_illustrative scenario's
  # own override of this same toggle to TRUE is now redundant with the
  # base case rather than the thing that turns the fee on. What still
  # meaningfully differs between the two scenarios is the DOLLAR AMOUNT of
  # that fee: Colorado's real Medicaid CPT 58300 rate ($58.65) vs. the
  # base case's self-pay-chargemaster-derived rate ($116.08).
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()

  scenario_results <- run_scenario_analysis(model_parameters, price_index_table, all_items_price_index_table)
  medicaid_combined <- scenario_results[
    scenario_results$scenario == "medicaid_illustrative" & scenario_results$strategy == "combined",
  ]
  base_combined <- scenario_results[
    scenario_results$scenario == "base_case" & scenario_results$strategy == "combined",
  ]

  expect_gt(medicaid_combined$professional_fee, 0)
  expect_gt(base_combined$professional_fee, 0)
  expect_equal(medicaid_combined$professional_fee, 58.65)
  expect_false(medicaid_combined$professional_fee == base_combined$professional_fee)
})

test_that("run_scenario_analysis returns 2 scenarios x 2 strategies = 4 rows", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()

  scenario_results <- run_scenario_analysis(model_parameters, price_index_table, all_items_price_index_table)
  expect_equal(nrow(scenario_results), 4)
})

test_that("INDEPENDENT CONFIRMATION: medicaid_illustrative standalone cost matches a from-scratch recomputation", {
  # Re-derives the Medicaid-scenario standalone total via raw arithmetic on
  # the overridden values, not by calling run_scenario_analysis(), so this
  # check cannot share a bug with the code it verifies.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  reference_year <- get_parameter_value(model_parameters, "reference_dollar_year")

  device <- get_parameter_value(model_parameters, "iud_device_acquisition_cost_gpo")
  medicaid_professional_fee <- 58.65
  medicaid_office_visit <- 77.39
  expulsion_standalone <- get_parameter_value(model_parameters, "iud_expulsion_probability_standalone")
  failure_probability <- get_parameter_value(model_parameters, "standalone_office_failure_probability")
  minutes <- get_parameter_value(model_parameters, "combined_arm_added_minutes")
  room_per_min <- adjust_for_inflation(20.90, 2014, reference_year, price_index_table)
  anesthesia_per_min <- adjust_for_inflation(3.42, 2014, reference_year, price_index_table)
  added_or_cost <- minutes * (room_per_min + anesthesia_per_min)
  replacement_encounter_cost <- device + medicaid_professional_fee + medicaid_office_visit
  perforation_probability <- get_parameter_value(model_parameters, "iud_perforation_risk_baseline")
  perforation_cost <- perforation_probability * adjust_for_inflation(20805.84, 2015, reference_year, price_index_table)

  expected_standalone <- device + medicaid_professional_fee + medicaid_office_visit +
    expulsion_standalone * replacement_encounter_cost +
    failure_probability * added_or_cost +
    perforation_cost

  scenario_results <- run_scenario_analysis(model_parameters, price_index_table, all_items_price_index_table)
  actual_standalone <- scenario_results[
    scenario_results$scenario == "medicaid_illustrative" & scenario_results$strategy == "standalone",
  ]

  expect_equal(actual_standalone$expected_total_cost, expected_standalone)
})
