test_that("compute_bounded_displaced_case_opportunity_cost matches an independent from-scratch recomputation", {
  model_parameters <- test_model_parameters()

  medicare_payment <- 10976.27
  national_cost <- 11711.70
  typical_case_minutes <- 110.6
  added_minutes <- get_parameter_value(model_parameters, "combined_arm_added_minutes")
  cost_low <- 9111.70
  cost_high <- 15204.00

  expected_margin <- medicare_payment - national_cost
  expected_per_minute <- expected_margin / typical_case_minutes
  expected_base <- expected_per_minute * added_minutes
  expected_high <- ((medicare_payment - cost_low) / typical_case_minutes) * added_minutes
  expected_low <- ((medicare_payment - cost_high) / typical_case_minutes) * added_minutes

  result <- compute_bounded_displaced_case_opportunity_cost(model_parameters)

  expect_equal(result$contribution_margin, expected_margin, tolerance = 0.01)
  expect_equal(result$opportunity_cost_of_added_minutes, expected_base, tolerance = 0.01)
  expect_equal(result$opportunity_cost_of_added_minutes_low, expected_low, tolerance = 0.01)
  expect_equal(result$opportunity_cost_of_added_minutes_high, expected_high, tolerance = 0.01)
})

test_that("compute_bounded_displaced_case_opportunity_cost's base-case margin is negative, given real Medicare payment vs. real national cost", {
  # A real, checkable finding, not an assumption: national Medicare
  # payment for the routine bariatric-surgery DRG is below the national
  # blended cost of the procedure.
  model_parameters <- test_model_parameters()
  result <- compute_bounded_displaced_case_opportunity_cost(model_parameters)

  expect_lt(result$contribution_margin, 0)
  expect_lt(result$opportunity_cost_of_added_minutes, 0)
})

test_that("a lower national-cost bound produces a higher (less negative) opportunity-cost estimate than a higher cost bound", {
  model_parameters <- test_model_parameters()
  result <- compute_bounded_displaced_case_opportunity_cost(model_parameters)

  expect_lt(
    result$opportunity_cost_of_added_minutes_low,
    result$opportunity_cost_of_added_minutes_high
  )
  expect_true(
    result$opportunity_cost_of_added_minutes_low <= result$opportunity_cost_of_added_minutes
  )
  expect_true(
    result$opportunity_cost_of_added_minutes <= result$opportunity_cost_of_added_minutes_high
  )
})

test_that("compute_bounded_displaced_case_opportunity_cost is not consumed by any base-case strategy-cost function", {
  # Regression guard: this sensitivity-only exercise must never silently
  # become part of expected_total_cost.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()

  combined_cost_before <- compute_combined_strategy_cost(
    model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
  )

  # Wildly different opportunity-cost inputs must not change expected_total_cost.
  perturbed_parameters <- override_model_parameters(
    model_parameters,
    list(bariatric_medicare_drg621_national_payment = 999999)
  )
  combined_cost_after <- compute_combined_strategy_cost(
    perturbed_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
  )

  expect_equal(combined_cost_before$expected_total_cost, combined_cost_after$expected_total_cost)
})
