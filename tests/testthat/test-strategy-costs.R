test_that("compute_standalone_strategy_cost sums device + professional fee + office visit + expected replacement + expected escalation", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  standalone_cost <- compute_standalone_strategy_cost(
    model_parameters, price_index_table, all_items_price_index_table
  )

  expect_equal(standalone_cost$device_cost, 568.50)
  expect_equal(standalone_cost$professional_fee, 116.08)
  expect_equal(standalone_cost$office_visit_cost, 88.76)
  expect_equal(standalone_cost$expected_replacement_cost, 0.056 * (568.50 + 116.08 + 88.76))
  expect_gt(standalone_cost$expected_escalation_cost, 0)
  expect_equal(
    standalone_cost$expected_total_cost,
    568.50 + 116.08 + 88.76 +
      0.056 * (568.50 + 116.08 + 88.76) +
      standalone_cost$expected_escalation_cost
  )
})

test_that("compute_combined_strategy_cost excludes the professional fee when the toggle is FALSE", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  combined_cost <- compute_combined_strategy_cost(
    model_parameters, price_index_table, all_items_price_index_table
  )

  expect_equal(combined_cost$professional_fee, 0)
  expect_equal(combined_cost$office_visit_cost, 0)
  expect_gt(combined_cost$added_or_cost, 10 * (20.90 + 3.42)) # inflation-adjusted, so strictly bigger than nominal 2014 dollars
  expect_equal(combined_cost$expected_replacement_cost, 0.163 * (568.50 + 116.08 + 88.76))
  expect_equal(
    combined_cost$expected_total_cost,
    568.50 + combined_cost$added_or_cost + 0.163 * (568.50 + 116.08 + 88.76)
  )
})

test_that("compute_combined_strategy_cost includes the professional fee when the toggle is TRUE", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  toggled_parameters <- override_model_parameters(
    model_parameters,
    list(combined_requires_separate_professional_fee = TRUE)
  )
  combined_cost <- compute_combined_strategy_cost(
    toggled_parameters, price_index_table, all_items_price_index_table
  )

  expect_equal(combined_cost$professional_fee, 116.08)
})

test_that("combined arm's higher expulsion rate produces a higher expected replacement cost", {
  # Directly encodes the Masten et al. 2024 finding this parameterization is
  # built on: combined placement carries higher expulsion risk, so its
  # expected replacement cost should exceed the standalone arm's, even
  # though both arms replace an expelled device via the same formula.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  standalone_cost <- compute_standalone_strategy_cost(model_parameters, price_index_table, all_items_price_index_table)
  combined_cost <- compute_combined_strategy_cost(model_parameters, price_index_table, all_items_price_index_table)

  expect_gt(combined_cost$expected_replacement_cost, standalone_cost$expected_replacement_cost)
})

test_that("only the standalone arm carries a societal patient-time add-on", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  strategy_costs <- compute_strategy_costs(model_parameters, price_index_table, all_items_price_index_table)

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
  strategy_costs <- compute_strategy_costs(model_parameters, price_index_table, all_items_price_index_table)

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

  expected_standalone <- device + professional_fee + office_visit +
    expulsion_standalone * replacement_encounter_cost +
    failure_probability * added_or_cost
  expected_combined <- device + added_or_cost +
    expulsion_combined * replacement_encounter_cost

  strategy_costs <- compute_strategy_costs(model_parameters, price_index_table, all_items_price_index_table)

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
})
