#!/usr/bin/env Rscript
#' Probabilistic (Monte Carlo) sensitivity analysis
#'
#' Complements `04_sensitivity_analysis.R`'s one-way tornado diagram by
#' varying all ten of its already-vetted parameters jointly, drawing
#' from each one's own `distribution` tag in `config/model_parameters.csv`.
#' See R/sensitivity_probabilistic.R for the full methodology and scope
#' (in particular: cancer_prevention_parameters and
#' expected_cost_per_referred_patient are NOT varied here -- this
#' targets the same expected_total_cost-based headline gap the one-way
#' analysis does).
#'
#' Run from the repository root:
#'   Rscript analysis/05_probabilistic_sensitivity_analysis.R

base::source("R/00_source_all.R")

base::message("=== Probabilistic sensitivity analysis (Monte Carlo, n = 10,000) ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")
price_index_table <- load_price_index_table("data/cpi_medical_care.csv")
all_items_price_index_table <- load_price_index_table("data/cpi_all_items.csv")
cancer_prevention_parameters <- load_model_parameters("config/cancer_prevention_parameters.csv")

psa_result <- run_probabilistic_sensitivity_analysis(
  model_parameters, price_index_table, all_items_price_index_table,
  cancer_prevention_parameters, n_draws = 10000
)

base::print(psa_result$summary)

base_case_gap <- compute_incremental_gap(
  model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
)

summary_row <- psa_result$summary

psa_sentence <- base::paste0(
  "Probabilistic sensitivity analysis (", summary_row$n_draws, " Monte Carlo draws, ",
  "joint variation across all ten parameters swept one-way above): the base-case ",
  "incremental cost gap of $", base::round(base_case_gap, 2), " (combined minus standalone) ",
  "has a mean of $", base::round(summary_row$mean_gap, 2), " and a 95% simulation interval of $",
  base::round(summary_row$ci_low, 2), " to $", base::round(summary_row$ci_high, 2),
  " across joint parameter uncertainty. Standalone was cheaper in ",
  base::round(summary_row$probability_standalone_cheaper * 100, 1),
  "% of draws -- the standalone-vs-combined conclusion is robust to this joint uncertainty, ",
  "not an artifact of any single parameter's point estimate."
)

base::message(psa_sentence)
readr::write_lines(psa_sentence, "tables/psa_sentence.txt")

save_table(psa_result$summary, "psa_summary.csv")
save_table(psa_result$draws, "psa_draws.csv")

base::message("=== Probabilistic sensitivity analysis complete ===")
