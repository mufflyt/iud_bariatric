test_that("sample_triangular draws only within [low, high] and averages near the mode", {
  set.seed(1)
  draws <- sample_triangular(100000, low = 10, mode = 40, high = 100)

  expect_true(all(draws >= 10))
  expect_true(all(draws <= 100))
  # Triangular mean = (low + mode + high) / 3.
  expect_equal(mean(draws), (10 + 40 + 100) / 3, tolerance = 0.5)
})

test_that("fit_gamma_moments's shape/rate reproduce the target mean exactly", {
  fitted <- fit_gamma_moments(mean = 100, low = 80, high = 120)

  expect_equal(fitted$shape / fitted$rate, 100)
  expect_true(fitted$shape > 0)
  expect_true(fitted$rate > 0)
})

test_that("fit_gamma_moments derives the standard error from a 95% CI (low/high as the 2.5th/97.5th percentiles)", {
  # Independently recomputed from the formula's own definition: this
  # test's job is to catch a wrong SE-scaling constant, which the
  # shape/rate == mean identity above cannot (that ratio always equals
  # mean regardless of the SE used).
  standard_error <- (120 - 80) / (2 * 1.96)
  expected_rate <- 100 / standard_error^2
  expected_shape <- 100 * expected_rate

  fitted <- fit_gamma_moments(mean = 100, low = 80, high = 120)

  expect_equal(fitted$rate, expected_rate)
  expect_equal(fitted$shape, expected_shape)
})

test_that("sample_gamma_from_ci draws are all positive and average near the target mean", {
  set.seed(2)
  draws <- sample_gamma_from_ci(100000, mean = 116.08, low = 75, high = 125)

  expect_true(all(draws > 0))
  expect_equal(mean(draws), 116.08, tolerance = 1)
})

test_that("sample_parameter_draws holds a 'fixed'-tagged parameter at its base_value with zero variance", {
  model_parameters <- test_model_parameters()
  row <- model_parameters |> dplyr::filter(.data$parameter == "iud_perforation_risk_baseline")

  draws <- sample_parameter_draws(500, row)

  expect_equal(sd(draws), 0)
  expect_true(all(draws == get_parameter_value(model_parameters, "iud_perforation_risk_baseline")))
})

test_that("sample_parameter_draws varies a 'triangular'-tagged parameter within its sourced range", {
  model_parameters <- test_model_parameters()
  row <- model_parameters |> dplyr::filter(.data$parameter == "iud_device_acquisition_cost_gpo")

  draws <- sample_parameter_draws(500, row)

  expect_true(sd(draws) > 0)
  expect_true(all(draws >= 537))
  expect_true(all(draws <= 600))
})

test_that("run_probabilistic_sensitivity_analysis is reproducible given the same seed", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()

  result_a <- run_probabilistic_sensitivity_analysis(
    model_parameters, price_index_table, all_items_price_index_table,
    cancer_prevention_parameters, n_draws = 300, seed = 42
  )
  result_b <- run_probabilistic_sensitivity_analysis(
    model_parameters, price_index_table, all_items_price_index_table,
    cancer_prevention_parameters, n_draws = 300, seed = 42
  )

  expect_equal(result_a$summary, result_b$summary)
  expect_equal(result_a$draws, result_b$draws)
})

test_that("run_probabilistic_sensitivity_analysis's draws hold the two 'fixed'-tagged parameters constant", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()

  result <- run_probabilistic_sensitivity_analysis(
    model_parameters, price_index_table, all_items_price_index_table,
    cancer_prevention_parameters, n_draws = 300, seed = 1
  )

  expect_equal(sd(result$draws$iud_expulsion_probability_combined), 0)
  expect_equal(sd(result$draws$iud_perforation_risk_baseline), 0)
  expect_true(sd(result$draws$iud_device_acquisition_cost_gpo) > 0)
  expect_true(sd(result$draws$iud_insertion_professional_fee) > 0)
})

test_that("run_probabilistic_sensitivity_analysis's mean gap lands close to the deterministic base case", {
  # A gamma-fit mean equals base_value exactly and a triangular mean is
  # close to its mode, so averaging enough draws should land near the
  # deterministic base_case_gap -- a sanity check on the sampling, not a
  # tight statistical claim.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()

  base_case_gap <- compute_incremental_gap(
    model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
  )
  result <- run_probabilistic_sensitivity_analysis(
    model_parameters, price_index_table, all_items_price_index_table,
    cancer_prevention_parameters, n_draws = 1000, seed = 7
  )

  expect_equal(result$summary$mean_gap, base_case_gap, tolerance = 0.1)
  expect_true(result$summary$ci_low < result$summary$mean_gap)
  expect_true(result$summary$mean_gap < result$summary$ci_high)
  expect_true(result$summary$probability_standalone_cheaper >= 0)
  expect_true(result$summary$probability_standalone_cheaper <= 1)
})
