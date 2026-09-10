test_that("build_scenario_definitions returns base_case and medicaid_illustrative", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  scenario_definitions <- build_scenario_definitions(model_parameters, price_index_table)

  expect_equal(sort(names(scenario_definitions)), c("base_case", "medicaid_illustrative"))
  expect_false(scenario_definitions$base_case$provisional)
  expect_true(scenario_definitions$medicaid_illustrative$provisional)
})

test_that("base_case scenario has no overrides and reproduces compute_strategy_costs() exactly", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()

  scenario_definitions <- build_scenario_definitions(model_parameters, price_index_table)
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
  scenario_definitions <- build_scenario_definitions(model_parameters, price_index_table)

  expect_equal(scenario_definitions$medicaid_illustrative$overrides$office_visit_em_cost, 77.39)
})

test_that("medicaid_illustrative scenario turns on the combined arm's separate professional fee", {
  # This is the policy-analogy assumption (extending Colorado's real
  # delivery-DRG LARC carve-out to a bariatric-surgery DRG) -- it should
  # make the combined arm pay iud_insertion_professional_fee, unlike the
  # base case where that toggle defaults to FALSE.
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

  expect_equal(medicaid_combined$professional_fee, medicaid_combined$professional_fee[[1]])
  expect_gt(medicaid_combined$professional_fee, 0)
  expect_equal(base_combined$professional_fee, 0)
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
  medicaid_professional_fee <- adjust_for_inflation(103, 2015, reference_year, price_index_table)
  medicaid_office_visit <- 77.39
  expulsion_standalone <- get_parameter_value(model_parameters, "iud_expulsion_probability_standalone")
  failure_probability <- get_parameter_value(model_parameters, "standalone_office_failure_probability")
  minutes <- get_parameter_value(model_parameters, "combined_arm_added_minutes")
  room_per_min <- adjust_for_inflation(20.90, 2014, reference_year, price_index_table)
  anesthesia_per_min <- adjust_for_inflation(3.42, 2014, reference_year, price_index_table)
  added_or_cost <- minutes * (room_per_min + anesthesia_per_min)
  replacement_encounter_cost <- device + medicaid_professional_fee + medicaid_office_visit

  expected_standalone <- device + medicaid_professional_fee + medicaid_office_visit +
    expulsion_standalone * replacement_encounter_cost +
    failure_probability * added_or_cost

  scenario_results <- run_scenario_analysis(model_parameters, price_index_table, all_items_price_index_table)
  actual_standalone <- scenario_results[
    scenario_results$scenario == "medicaid_illustrative" & scenario_results$strategy == "standalone",
  ]

  expect_equal(actual_standalone$expected_total_cost, expected_standalone)
})
