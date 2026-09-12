test_that("load_state_wage_index_table returns one row per state with a real wage index", {
  wage_index_table <- test_state_wage_index_table()

  expect_gt(nrow(wage_index_table), 45)
  expect_true(all(wage_index_table$mean_wage_index > 0))
  expect_true("CO" %in% wage_index_table$state_abbr)
})

test_that("compute_state_medicare_payment matches an independent from-scratch recomputation for a high-wage-index state", {
  model_parameters <- test_model_parameters()

  operating_base <- 6752.61
  capital_base <- 524.15
  weight <- 1.5084
  wage_index <- 1.4895 # California
  labor_share <- 0.66 # wage_index > 1.0

  expected <- weight * operating_base * (labor_share * wage_index + (1 - labor_share)) +
    weight * capital_base

  expect_equal(
    compute_state_medicare_payment(model_parameters, wage_index),
    expected,
    tolerance = 1e-6
  )
})

test_that("compute_state_medicare_payment matches an independent from-scratch recomputation for a low-wage-index state", {
  model_parameters <- test_model_parameters()

  operating_base <- 6752.61
  capital_base <- 524.15
  weight <- 1.5084
  wage_index <- 0.7901 # Mississippi
  labor_share <- 0.62 # wage_index <= 1.0

  expected <- weight * operating_base * (labor_share * wage_index + (1 - labor_share)) +
    weight * capital_base

  expect_equal(
    compute_state_medicare_payment(model_parameters, wage_index),
    expected,
    tolerance = 1e-6
  )
})

test_that("compute_state_medicare_payment at wage_index = 1.0 reproduces the national unadjusted payment", {
  # A useful internal sanity check: at the national-average wage index,
  # this per-state formula should collapse back to
  # bariatric_medicare_drg621_national_payment.
  model_parameters <- test_model_parameters()
  national_payment <- get_parameter_value(model_parameters, "bariatric_medicare_drg621_national_payment")

  expect_equal(
    compute_state_medicare_payment(model_parameters, 1.0),
    national_payment,
    tolerance = 1e-5
  )
})

test_that("the state-average formula for Colorado is well below Denver Health's own real MRF-reported rate", {
  # A real, documented, and deliberately checked understatement: this
  # formula uses a STATE-AVERAGE wage index with no hospital-specific
  # IME/DSH adjustment, so it should NOT be mistaken for a Denver
  # Health-specific estimate.
  model_parameters <- test_model_parameters()
  wage_index_table <- test_state_wage_index_table()
  co_wage_index <- wage_index_table$mean_wage_index[wage_index_table$state_abbr == "CO"]

  co_formula_estimate <- compute_state_medicare_payment(model_parameters, co_wage_index)
  denver_health_real_rate <- get_parameter_value(model_parameters, "bariatric_denver_health_medicare_rate")

  expect_lt(co_formula_estimate, denver_health_real_rate)
  expect_lt(co_formula_estimate / denver_health_real_rate, 0.6)
})

test_that("compute_national_opportunity_cost_by_state returns one row per state and is not consumed by the base case", {
  model_parameters <- test_model_parameters()
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  cancer_prevention_parameters <- test_cancer_prevention_parameters()

  wage_index_table <- test_state_wage_index_table()
  result <- compute_national_opportunity_cost_by_state(model_parameters, wage_index_table)

  expect_equal(nrow(result), nrow(wage_index_table))
  expect_true(all(c("state_abbr", "opportunity_cost_of_added_minutes") %in% names(result)))

  combined_cost_before <- compute_combined_strategy_cost(
    model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
  )
  perturbed_parameters <- override_model_parameters(
    model_parameters,
    list(national_commercial_to_medicare_ratio = 999)
  )
  combined_cost_after <- compute_combined_strategy_cost(
    perturbed_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
  )
  expect_equal(combined_cost_before$expected_total_cost, combined_cost_after$expected_total_cost)
})
