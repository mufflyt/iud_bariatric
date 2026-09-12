test_that("load_multi_hospital_rates_table returns 10 real hospitals", {
  rates_table <- test_multi_hospital_rates_table()

  expect_equal(nrow(rates_table), 10)
  expect_true(all(c("CO", "GA", "TX", "FL", "OH", "WA", "PA", "MS", "AR", "NY") %in% rates_table$state_abbr))
})

test_that("compute_multi_hospital_opportunity_cost matches an independent from-scratch recomputation for Denver Health", {
  model_parameters <- test_model_parameters()
  rates_table <- test_multi_hospital_rates_table()

  medicare_fraction <- 0.18
  medicaid_fraction <- 0.491
  commercial_fraction <- 0.17
  national_cost <- 11711.70
  typical_case_minutes <- 110.6
  added_minutes <- get_parameter_value(model_parameters, "combined_arm_added_minutes")

  expected_revenue <- 27902.21 * medicare_fraction + 11727.32 * medicaid_fraction + 32908.41 * commercial_fraction
  expected_margin <- expected_revenue - national_cost
  expected_opp_cost <- (expected_margin / typical_case_minutes) * added_minutes

  result <- compute_multi_hospital_opportunity_cost(model_parameters, rates_table)
  co_row <- result[result$state_abbr == "CO", ]

  expect_equal(co_row$weighted_revenue, expected_revenue, tolerance = 1e-6)
  expect_equal(co_row$contribution_margin, expected_margin, tolerance = 1e-6)
  expect_equal(co_row$opportunity_cost_of_added_minutes, expected_opp_cost, tolerance = 1e-6)
})

test_that("compute_multi_hospital_opportunity_cost returns NA, not a fabricated number, when a hospital is missing a rate", {
  model_parameters <- test_model_parameters()
  rates_table <- test_multi_hospital_rates_table()

  result <- compute_multi_hospital_opportunity_cost(model_parameters, rates_table)

  # Washington has no Medicare rate; Pennsylvania and Arkansas have no
  # Medicaid rate -- all three must propagate to NA, not a silently
  # dropped row or a zero standing in for missing data.
  expect_true(base::is.na(result$opportunity_cost_of_added_minutes[result$state_abbr == "WA"]))
  expect_true(base::is.na(result$opportunity_cost_of_added_minutes[result$state_abbr == "PA"]))
  expect_true(base::is.na(result$opportunity_cost_of_added_minutes[result$state_abbr == "AR"]))
  expect_equal(base::sum(!base::is.na(result$opportunity_cost_of_added_minutes)), 7)
})

test_that("the real multi-hospital sample shows genuinely mixed results, not a uniform sign", {
  # A real, checkable finding: unlike the single-hospital Denver Health
  # estimate (positive) or the borrowed-ratio 52-state sweep, the real
  # multi-hospital sample has both positive and negative results.
  model_parameters <- test_model_parameters()
  result <- compute_multi_hospital_opportunity_cost(model_parameters, test_multi_hospital_rates_table())
  complete <- result[!base::is.na(result$opportunity_cost_of_added_minutes), ]

  expect_true(base::any(complete$opportunity_cost_of_added_minutes > 0))
  expect_true(base::any(complete$opportunity_cost_of_added_minutes < 0))
})

test_that("compute_multi_hospital_opportunity_cost is not consumed by the base case", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()

  combined_cost_before <- compute_combined_strategy_cost(
    model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
  )
  perturbed_parameters <- override_model_parameters(
    model_parameters,
    list(empirical_commercial_to_medicare_ratio = 999)
  )
  combined_cost_after <- compute_combined_strategy_cost(
    perturbed_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
  )
  expect_equal(combined_cost_before$expected_total_cost, combined_cost_after$expected_total_cost)
})
