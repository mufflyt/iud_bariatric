test_that("load_model_parameters reads and validates the shipped parameter file", {
  model_parameters <- test_model_parameters()
  expect_s3_class(model_parameters, "data.frame")
  expect_true(nrow(model_parameters) > 5)
  expect_true("provisional" %in% names(model_parameters))
  expect_true("evidence_tier" %in% names(model_parameters))
})

test_that("load_model_parameters errors on a missing file", {
  expect_error(load_model_parameters("does/not/exist.csv"), "not found")
})

test_that("get_parameter_value returns the correct numeric base value", {
  model_parameters <- test_model_parameters()
  expect_equal(
    get_parameter_value(model_parameters, "iud_device_acquisition_cost_gpo"),
    568.50
  )
})

test_that("get_parameter_value errors for an unknown parameter", {
  model_parameters <- test_model_parameters()
  expect_error(
    get_parameter_value(model_parameters, "not_a_real_parameter"),
    "Expected exactly one parameter row"
  )
})

test_that("get_parameter_raw_value reads the structural boolean toggle", {
  model_parameters <- test_model_parameters()
  expect_equal(
    get_parameter_raw_value(model_parameters, "combined_requires_separate_professional_fee"),
    "TRUE"
  )
})

test_that("override_model_parameters replaces a base value", {
  model_parameters <- test_model_parameters()
  overridden <- override_model_parameters(
    model_parameters,
    list(iud_device_acquisition_cost_gpo = 100)
  )
  expect_equal(
    get_parameter_value(overridden, "iud_device_acquisition_cost_gpo"),
    100
  )
})

test_that("override_model_parameters errors on an unknown parameter name", {
  model_parameters <- test_model_parameters()
  expect_error(
    override_model_parameters(model_parameters, list(not_a_real_parameter = 1)),
    "unknown parameter name"
  )
})
