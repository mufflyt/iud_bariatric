test_that("compute_incremental_gap matches compare_combined_vs_standalone's own combined-row value", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()

  strategy_costs <- compute_strategy_costs(
    model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
  )
  comparison <- compare_combined_vs_standalone(strategy_costs)
  expected <- comparison$incremental_cost_vs_standalone[comparison$strategy == "combined"]

  expect_equal(
    compute_incremental_gap(
      model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
    ),
    expected
  )
})

test_that("run_one_way_sensitivity returns one row per requested parameter, sorted by swing descending", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()

  results <- run_one_way_sensitivity(
    model_parameters, price_index_table, all_items_price_index_table,
    cancer_prevention_parameters = cancer_prevention_parameters
  )

  expect_equal(nrow(results), length(SENSITIVITY_PARAMETER_NAMES))
  expect_equal(sort(results$parameter), sort(SENSITIVITY_PARAMETER_NAMES))
  expect_equal(results$swing, sort(results$swing, decreasing = TRUE))
})

test_that("run_one_way_sensitivity rejects a parameter with a missing low or high value", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()

  # patient_time_opportunity_cost_per_visit is used by the cost engine but
  # has no sourced low/high range -- this must fail loudly, not silently
  # sweep a fabricated bound.
  expect_error(
    run_one_way_sensitivity(
      model_parameters, price_index_table, all_items_price_index_table,
      parameter_names = "patient_time_opportunity_cost_per_visit",
      cancer_prevention_parameters = cancer_prevention_parameters
    )
  )
})

test_that("iud_expulsion_probability_combined is now sweepable and is a real driver of the gap", {
  # Confirms the 2026-09-10 fix: this parameter previously had no low/high
  # range (see the test above, which used to target this parameter
  # instead) and is now the kind of large, real driver this analysis
  # exists to find.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()

  results <- run_one_way_sensitivity(
    model_parameters, price_index_table, all_items_price_index_table,
    parameter_names = "iud_expulsion_probability_combined",
    cancer_prevention_parameters = cancer_prevention_parameters
  )

  expect_gt(results$swing, 50)
})

test_that("iud_perforation_risk_baseline washes out: it moves both arms equally, so the gap barely changes", {
  # This is the concrete, checkable version of R/strategy_costs.R's
  # incremental-cost principle: perforation cost is a flat add-on with no
  # per-arm differential multiplier, so its wide $0.0011-$0.0018 range
  # should leave the combined-vs-standalone gap essentially untouched.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()

  results <- run_one_way_sensitivity(
    model_parameters, price_index_table, all_items_price_index_table,
    parameter_names = "iud_perforation_risk_baseline",
    cancer_prevention_parameters = cancer_prevention_parameters
  )

  expect_lt(results$swing, 0.01)
})

test_that("combined_arm_added_minutes is a real driver of the gap: swing is large and positive", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()

  results <- run_one_way_sensitivity(
    model_parameters, price_index_table, all_items_price_index_table,
    parameter_names = "combined_arm_added_minutes",
    cancer_prevention_parameters = cancer_prevention_parameters
  )

  expect_gt(results$swing, 100)
})

test_that("INDEPENDENT CONFIRMATION: combined_arm_added_minutes' low/high gaps match a from-scratch override+recompute", {
  # Re-derives gap_at_low/gap_at_high by calling override_model_parameters()
  # and compute_strategy_costs()/compare_combined_vs_standalone() directly,
  # not run_one_way_sensitivity(), so this check cannot share a bug with
  # the code it verifies.
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()

  low_parameters <- override_model_parameters(model_parameters, list(combined_arm_added_minutes = 5))
  high_parameters <- override_model_parameters(model_parameters, list(combined_arm_added_minutes = 15))

  expected_gap_at_low <- compare_combined_vs_standalone(
    compute_strategy_costs(low_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)
  )
  expected_gap_at_low <- expected_gap_at_low$incremental_cost_vs_standalone[expected_gap_at_low$strategy == "combined"]

  expected_gap_at_high <- compare_combined_vs_standalone(
    compute_strategy_costs(high_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters)
  )
  expected_gap_at_high <- expected_gap_at_high$incremental_cost_vs_standalone[expected_gap_at_high$strategy == "combined"]

  actual <- run_one_way_sensitivity(
    model_parameters, price_index_table, all_items_price_index_table,
    parameter_names = "combined_arm_added_minutes",
    cancer_prevention_parameters = cancer_prevention_parameters
  )

  expect_equal(actual$gap_at_low, expected_gap_at_low)
  expect_equal(actual$gap_at_high, expected_gap_at_high)
  expect_equal(actual$swing, base::abs(expected_gap_at_high - expected_gap_at_low))
})
