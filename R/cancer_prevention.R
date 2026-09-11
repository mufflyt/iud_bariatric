#' Endometrial cancer prevention estimate
#'
#' This is a SEPARATE analysis from the cost-minimization model in
#' `R/strategy_costs.R`, which assumes the IUD is placed with equal
#' effectiveness regardless of arm and therefore has no cancer-outcome
#' parameter at all. This module answers a different question: given that
#' the device gets placed, how much endometrial cancer risk reduction does
#' that actually buy, for a population that is already having bariatric
#' surgery (and therefore already gets a large risk reduction from weight
#' loss alone, independent of the IUD)?
#'
#' Two real, separately-measured effects are layered multiplicatively:
#' bariatric surgery's own independent reduction in endometrial cancer
#' risk (Schauer et al. 2019, a matched cohort of actual bariatric-surgery
#' patients), and the LNG-IUD's own additional reduction on top of that
#' (Soini et al. 2014, the same evidence base used by the field's existing
#' obesity/LNG-IUD cost-effectiveness models, e.g. Dottino et al. 2016,
#' Bernard et al. 2021). No study has measured these two effects together
#' in one cohort; treating them as multiplicative and independent is an
#' explicit, flagged simplifying assumption, not an empirical finding. See
#' `config/cancer_prevention_parameters.csv` and
#' `docs/data_sources.md` ("Cancer-prevention estimate" section) for the
#' full citation trail and the lifetime-vs-protected-window caveat.

#' Bariatric-surgery-population "usual care" (no IUD) endometrial cancer risk
#'
#' @param lifetime_risk_no_intervention Numeric scalar, an untreated obese
#'   population's lifetime endometrial cancer risk (e.g.
#'   `endometrial_cancer_lifetime_risk_usual_care_bmi40`).
#' @param surgery_hazard_ratio Numeric scalar, bariatric surgery's own
#'   hazard ratio for endometrial cancer vs. non-surgical matched controls.
#' @return Numeric scalar: the risk after surgery, before any IUD effect.
compute_post_surgery_baseline_risk <- function(lifetime_risk_no_intervention, surgery_hazard_ratio) {
  lifetime_risk_no_intervention * surgery_hazard_ratio
}

#' Bariatric-surgery-population risk with an LNG-IUD also placed
#'
#' @param post_surgery_baseline_risk Numeric scalar from
#'   [compute_post_surgery_baseline_risk()].
#' @param iud_incidence_ratio Numeric scalar, the IUD's own standardized
#'   incidence ratio for endometrial cancer.
#' @return Numeric scalar: the risk after surgery AND the IUD.
compute_post_surgery_iud_risk <- function(post_surgery_baseline_risk, iud_incidence_ratio) {
  post_surgery_baseline_risk * iud_incidence_ratio
}

#' The IUD's own absolute risk reduction, on top of surgery
#'
#' @inheritParams compute_post_surgery_iud_risk
#' @return Numeric scalar (probability scale), the IUD-attributable share
#'   of risk reduction, isolated from surgery's own (much larger) effect.
compute_iud_absolute_risk_reduction <- function(post_surgery_baseline_risk, iud_incidence_ratio) {
  post_surgery_baseline_risk * (1 - iud_incidence_ratio)
}

#' Number needed to treat with an IUD (on top of surgery) to prevent one case
#'
#' @param absolute_risk_reduction Numeric scalar from
#'   [compute_iud_absolute_risk_reduction()].
#' @return Numeric scalar.
compute_number_needed_to_treat <- function(absolute_risk_reduction) {
  1 / absolute_risk_reduction
}

#' Expected endometrial cancer cases prevented by the IUD in a cohort
#'
#' @param absolute_risk_reduction Numeric scalar from
#'   [compute_iud_absolute_risk_reduction()].
#' @param cohort_size Numeric scalar, number of bariatric-surgery patients
#'   who receive an IUD.
#' @return Numeric scalar.
compute_expected_cases_prevented <- function(absolute_risk_reduction, cohort_size) {
  absolute_risk_reduction * cohort_size
}

#' Full cancer-prevention summary for one BMI group
#'
#' @param cancer_prevention_parameters Tibble from
#'   [load_model_parameters()] pointed at
#'   `config/cancer_prevention_parameters.csv`.
#' @param bmi_group Character scalar, `"bmi40"` or `"bmi30"`.
#' @param cohort_size Numeric scalar, number of bariatric-surgery patients
#'   who receive an IUD (default 1,000, for a per-mille rate).
#' @return A one-row tibble: `bmi_group`, `cohort_size`,
#'   `lifetime_risk_no_intervention`, `post_surgery_no_iud_risk`,
#'   `post_surgery_with_iud_risk`, `iud_absolute_risk_reduction`,
#'   `number_needed_to_treat`, `expected_cases_prevented`.
compute_cancer_prevention_summary <- function(
  cancer_prevention_parameters,
  bmi_group = c("bmi40", "bmi30"),
  cohort_size = 1000
) {
  bmi_group <- base::match.arg(bmi_group)

  lifetime_risk <- get_parameter_value(
    cancer_prevention_parameters,
    base::paste0("endometrial_cancer_lifetime_risk_usual_care_", bmi_group)
  )
  surgery_hazard_ratio <- get_parameter_value(
    cancer_prevention_parameters, "bariatric_surgery_endometrial_cancer_hazard_ratio"
  )
  iud_incidence_ratio <- get_parameter_value(
    cancer_prevention_parameters, "iud_endometrial_cancer_incidence_ratio"
  )

  post_surgery_risk <- compute_post_surgery_baseline_risk(lifetime_risk, surgery_hazard_ratio)
  post_surgery_iud_risk <- compute_post_surgery_iud_risk(post_surgery_risk, iud_incidence_ratio)
  absolute_risk_reduction <- compute_iud_absolute_risk_reduction(post_surgery_risk, iud_incidence_ratio)

  tibble::tibble(
    bmi_group = bmi_group,
    cohort_size = cohort_size,
    lifetime_risk_no_intervention = lifetime_risk,
    post_surgery_no_iud_risk = post_surgery_risk,
    post_surgery_with_iud_risk = post_surgery_iud_risk,
    iud_absolute_risk_reduction = absolute_risk_reduction,
    number_needed_to_treat = compute_number_needed_to_treat(absolute_risk_reduction),
    expected_cases_prevented = compute_expected_cases_prevented(absolute_risk_reduction, cohort_size)
  )
}

#' Cancer-prevention summary for both BMI groups
#'
#' @inheritParams compute_cancer_prevention_summary
#' @return A tibble with one row per BMI group.
compute_cancer_prevention_summary_all_groups <- function(
  cancer_prevention_parameters,
  cohort_size = 1000
) {
  dplyr::bind_rows(
    compute_cancer_prevention_summary(cancer_prevention_parameters, "bmi40", cohort_size),
    compute_cancer_prevention_summary(cancer_prevention_parameters, "bmi30", cohort_size)
  )
}
