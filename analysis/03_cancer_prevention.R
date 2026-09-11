#!/usr/bin/env Rscript
#' Cancer-prevention estimate
#'
#' Estimates the endometrial cancer cases prevented by placing an LNG-IUD
#' in bariatric-surgery patients, on top of the risk reduction bariatric
#' surgery itself already provides. This is a separate analysis from the
#' cost-minimization model (see analysis/01_base_case.R,
#' analysis/02_scenario_analysis.R): it does not compare the standalone
#' and combined arms, since both are assumed to place an equally effective
#' device once placed. See docs/data_sources.md, "Cancer-prevention
#' estimate" section, for the full citation trail and an important
#' caveat: this applies the IUD's incidence ratio to a LIFETIME baseline
#' risk, which is a likely-optimistic upper bound, not a duration-
#' corrected figure (see iud_protective_duration_years in
#' config/cancer_prevention_parameters.csv).
#'
#' Run from the repository root:
#'   Rscript analysis/03_cancer_prevention.R

base::source("R/00_source_all.R")

base::message("=== Cancer-prevention estimate ===")

cancer_prevention_parameters <- load_model_parameters("config/cancer_prevention_parameters.csv")

cancer_prevention_summary <- compute_cancer_prevention_summary_all_groups(
  cancer_prevention_parameters, cohort_size = 1000
)

base::print(cancer_prevention_summary)

base::message(
  "\nPer 1,000 bariatric-surgery patients who receive an LNG-IUD (BMI 40+ baseline): ",
  base::round(cancer_prevention_summary$expected_cases_prevented[
    cancer_prevention_summary$bmi_group == "bmi40"
  ], 2),
  " expected endometrial cancer cases prevented (NNT = ",
  base::round(cancer_prevention_summary$number_needed_to_treat[
    cancer_prevention_summary$bmi_group == "bmi40"
  ], 0),
  ")."
)
base::message(
  "PROVISIONAL: applies the IUD's incidence ratio to a LIFETIME baseline ",
  "risk (Dottino et al. 2016's age-50-to-100 Markov horizon), not a ",
  "duration-corrected estimate. Treat as a likely-optimistic upper bound; ",
  "see docs/data_sources.md for why."
)

save_table(cancer_prevention_summary, "cancer_prevention_summary.csv")

base::message("=== Cancer-prevention estimate complete ===")
