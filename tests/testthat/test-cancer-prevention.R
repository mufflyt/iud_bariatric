test_that("compute_post_surgery_baseline_risk multiplies lifetime risk by the surgery hazard ratio", {
  expect_equal(compute_post_surgery_baseline_risk(0.03, 0.50), 0.015)
})

test_that("compute_post_surgery_iud_risk multiplies post-surgery risk by the IUD incidence ratio", {
  expect_equal(compute_post_surgery_iud_risk(0.015, 0.50), 0.0075)
})

test_that("compute_iud_absolute_risk_reduction is post-surgery risk times (1 - incidence ratio)", {
  # Deliberately asymmetric inputs: 0.50 is a fixed point of x -> 1 - x, so
  # testing at 0.50 cannot distinguish this formula from the bug "forgot
  # the 1 -" (both give the same answer). 0.3 has no such blind spot.
  expect_equal(compute_iud_absolute_risk_reduction(0.02, 0.3), 0.02 * 0.7)
})

test_that("compute_number_needed_to_treat is 1 / absolute risk reduction", {
  expect_equal(compute_number_needed_to_treat(0.0075), 1 / 0.0075)
})

test_that("compute_expected_cases_prevented scales absolute risk reduction by cohort size", {
  expect_equal(compute_expected_cases_prevented(0.0075, 1000), 7.5)
})

test_that("compute_cancer_prevention_summary returns one row with the real BMI 40+ parameters", {
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  summary_bmi40 <- compute_cancer_prevention_summary(cancer_prevention_parameters, "bmi40", cohort_size = 1000)

  expect_equal(nrow(summary_bmi40), 1)
  expect_equal(summary_bmi40$lifetime_risk_no_intervention, 0.03)
  expect_equal(summary_bmi40$post_surgery_no_iud_risk, 0.03 * 0.50)
  expect_equal(summary_bmi40$post_surgery_with_iud_risk, 0.03 * 0.50 * 0.50)
  expect_equal(summary_bmi40$iud_absolute_risk_reduction, 0.03 * 0.50 * 0.50)
  expect_equal(summary_bmi40$expected_cases_prevented, 1000 * 0.03 * 0.50 * 0.50)
})

test_that("compute_cancer_prevention_summary rejects an unknown bmi_group", {
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  expect_error(compute_cancer_prevention_summary(cancer_prevention_parameters, "bmi50"))
})

test_that("compute_cancer_prevention_summary_all_groups returns one row per BMI group", {
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  all_groups <- compute_cancer_prevention_summary_all_groups(cancer_prevention_parameters, cohort_size = 1000)

  expect_equal(sort(all_groups$bmi_group), c("bmi30", "bmi40"))
  expect_equal(nrow(all_groups), 2)
})

test_that("BMI 40+ carries a higher absolute risk reduction than BMI 30+, reflecting its higher baseline risk", {
  cancer_prevention_parameters <- test_cancer_prevention_parameters()
  all_groups <- compute_cancer_prevention_summary_all_groups(cancer_prevention_parameters, cohort_size = 1000)

  risk_reduction_bmi40 <- all_groups$iud_absolute_risk_reduction[all_groups$bmi_group == "bmi40"]
  risk_reduction_bmi30 <- all_groups$iud_absolute_risk_reduction[all_groups$bmi_group == "bmi30"]

  expect_gt(risk_reduction_bmi40, risk_reduction_bmi30)
})

test_that("INDEPENDENT CONFIRMATION: BMI 40+ cases-prevented matches a from-scratch recomputation", {
  # Re-derives the result via raw arithmetic on the parameter file's own
  # values, read directly with get_parameter_value(), not by calling
  # compute_cancer_prevention_summary(), so this check cannot share a bug
  # with the code it verifies.
  cancer_prevention_parameters <- test_cancer_prevention_parameters()

  lifetime_risk <- get_parameter_value(
    cancer_prevention_parameters, "endometrial_cancer_lifetime_risk_usual_care_bmi40"
  )
  surgery_hazard_ratio <- get_parameter_value(
    cancer_prevention_parameters, "bariatric_surgery_endometrial_cancer_hazard_ratio"
  )
  iud_incidence_ratio <- get_parameter_value(
    cancer_prevention_parameters, "iud_endometrial_cancer_incidence_ratio"
  )

  post_surgery_risk <- lifetime_risk * surgery_hazard_ratio
  expected_arr <- post_surgery_risk * (1 - iud_incidence_ratio)
  expected_cases_prevented <- expected_arr * 1000
  expected_nnt <- 1 / expected_arr

  actual <- compute_cancer_prevention_summary(cancer_prevention_parameters, "bmi40", cohort_size = 1000)

  expect_equal(actual$iud_absolute_risk_reduction, expected_arr)
  expect_equal(actual$expected_cases_prevented, expected_cases_prevented)
  expect_equal(actual$number_needed_to_treat, expected_nnt)
})
