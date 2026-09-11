test_that("compare_combined_vs_standalone flags the correct cheaper strategy", {
  model_parameters <- test_model_parameters()
  strategy_costs <- compute_strategy_costs(
    model_parameters, test_price_index_table(), test_all_items_price_index_table(), test_cancer_prevention_parameters()
  )
  comparison <- compare_combined_vs_standalone(strategy_costs)

  standalone_cost <- comparison$expected_total_cost[comparison$strategy == "standalone"]
  combined_cost <- comparison$expected_total_cost[comparison$strategy == "combined"]

  expect_equal(
    comparison$incremental_cost_vs_standalone[comparison$strategy == "combined"],
    combined_cost - standalone_cost
  )
  expect_equal(
    comparison$is_cheaper[comparison$strategy == "combined"],
    combined_cost < standalone_cost
  )
  # standalone is always the reference: its own incremental cost is 0
  expect_equal(
    comparison$incremental_cost_vs_standalone[comparison$strategy == "standalone"],
    0
  )
})
