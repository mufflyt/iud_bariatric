test_that("compute_standalone_strategy_cost sums device + professional fee + office visit", {
  model_parameters <- test_model_parameters()
  standalone_cost <- compute_standalone_strategy_cost(model_parameters)

  expect_equal(standalone_cost$device_cost, 568.50)
  expect_equal(standalone_cost$professional_fee, 116.08)
  expect_equal(standalone_cost$office_visit_cost, 88.76)
  expect_equal(standalone_cost$expected_total_cost, 568.50 + 116.08 + 88.76)
})

test_that("compute_combined_strategy_cost excludes the professional fee when the toggle is FALSE", {
  model_parameters <- test_model_parameters()
  combined_cost <- compute_combined_strategy_cost(model_parameters)

  expect_equal(combined_cost$professional_fee, 0)
  expect_equal(combined_cost$office_visit_cost, 0)
  expect_equal(combined_cost$added_or_cost, 10 * (20.90 + 3.42))
  expect_equal(combined_cost$expected_total_cost, 568.50 + 10 * (20.90 + 3.42))
})

test_that("compute_combined_strategy_cost includes the professional fee when the toggle is TRUE", {
  model_parameters <- test_model_parameters()
  toggled_parameters <- override_model_parameters(
    model_parameters,
    list(combined_requires_separate_professional_fee = TRUE)
  )
  combined_cost <- compute_combined_strategy_cost(toggled_parameters)

  expect_equal(combined_cost$professional_fee, 116.08)
})

test_that("compute_strategy_costs returns exactly one row per strategy", {
  model_parameters <- test_model_parameters()
  strategy_costs <- compute_strategy_costs(model_parameters)

  expect_equal(sort(strategy_costs$strategy), c("combined", "standalone"))
  expect_equal(nrow(strategy_costs), 2)
})

test_that("INDEPENDENT CONFIRMATION: base-case incremental cost matches a from-scratch recomputation", {
  # Re-derives the base-case comparison via a separate code path (raw
  # arithmetic on the parameter values, not by calling the pipeline
  # functions under test) so this check cannot share a bug with the code
  # it verifies.
  model_parameters <- test_model_parameters()

  device <- get_parameter_value(model_parameters, "iud_device_acquisition_cost_gpo")
  professional_fee <- get_parameter_value(model_parameters, "iud_insertion_professional_fee")
  office_visit <- get_parameter_value(model_parameters, "office_visit_em_cost")
  minutes <- get_parameter_value(model_parameters, "combined_arm_added_minutes")
  room_per_min <- get_parameter_value(model_parameters, "direct_room_cost_per_minute")
  anesthesia_per_min <- get_parameter_value(model_parameters, "anesthesia_cost_per_minute")

  expected_standalone <- device + professional_fee + office_visit
  expected_combined <- device + minutes * (room_per_min + anesthesia_per_min)

  strategy_costs <- compute_strategy_costs(model_parameters)

  expect_equal(
    strategy_costs$expected_total_cost[strategy_costs$strategy == "standalone"],
    expected_standalone
  )
  expect_equal(
    strategy_costs$expected_total_cost[strategy_costs$strategy == "combined"],
    expected_combined
  )
})
