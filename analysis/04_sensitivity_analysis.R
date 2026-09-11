#!/usr/bin/env Rscript
#' One-way deterministic sensitivity analysis
#'
#' For every parameter with a real, sourced low/high range, sweeps it
#' across that range (holding everything else at base case) and records
#' how much the combined-vs-standalone incremental cost gap moves. See
#' R/sensitivity_deterministic.R for which parameters are included, and
#' three that are known-used-but-currently-unranged and deliberately
#' excluded rather than swept with a fabricated bound.
#'
#' Run from the repository root:
#'   Rscript analysis/04_sensitivity_analysis.R

base::source("R/00_source_all.R")

base::message("=== One-way sensitivity analysis ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")
price_index_table <- load_price_index_table("data/cpi_medical_care.csv")
all_items_price_index_table <- load_price_index_table("data/cpi_all_items.csv")

sensitivity_results <- run_one_way_sensitivity(
  model_parameters, price_index_table, all_items_price_index_table
)

base::print(sensitivity_results)

base_case_gap <- sensitivity_results$base_case_gap[[1]]
top_parameter <- sensitivity_results$parameter[[1]]
top_swing <- sensitivity_results$swing[[1]]
washes_out <- sensitivity_results |> dplyr::filter(.data$swing < 1)

base::message(
  "\nBase-case incremental cost gap (combined - standalone): $",
  base::round(base_case_gap, 2)
)
base::message(
  "Most impactful parameter on the gap: ", top_parameter,
  " (swings the gap by up to $", base::round(top_swing, 2), ")"
)
if (base::nrow(washes_out) > 0) {
  base::message(
    "Wash out (affect both arms equally, don't change the gap by more ",
    "than $1 despite a real low/high range): ",
    base::paste(washes_out$parameter, collapse = ", "),
    ". Verifying these further would sharpen the ABSOLUTE cost estimate, ",
    "not the standalone-vs-combined conclusion."
  )
}
base::message(
  "NOT swept, because they are used by the cost engine but currently have ",
  "no sourced low/high range at all: patient_time_opportunity_cost_per_visit. ",
  "iud_perforation_management_cost has a low value but no sourced high value. ",
  "(iud_expulsion_probability_combined, the single number most directly ",
  "responsible for the combined arm's cost disadvantage, WAS in this list ",
  "until 2026-09-10, when a real Clopper-Pearson CI was computed directly ",
  "from Masten et al. 2024's own 7/43 raw proportion; it is now included above.)"
)

save_table(sensitivity_results, "sensitivity_analysis.csv")

base::message("=== Sensitivity analysis complete ===")
