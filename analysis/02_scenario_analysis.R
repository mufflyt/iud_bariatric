#!/usr/bin/env Rscript
#' Scenario analysis
#'
#' Compares the base case against a Medicaid payer scenario. Run from the
#' repository root:
#'   Rscript analysis/02_scenario_analysis.R

base::source("R/00_source_all.R")

base::message("=== Scenario analysis ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")
price_index_table <- load_price_index_table("data/cpi_medical_care.csv")
all_items_price_index_table <- load_price_index_table("data/cpi_all_items.csv")

scenario_results <- run_scenario_analysis(
  model_parameters, price_index_table, all_items_price_index_table
)

base::print(
  scenario_results |>
    dplyr::select("scenario", "strategy", "expected_total_cost", "societal_total_cost")
)

save_table(scenario_results, "scenario_analysis.csv")

base::message("=== Scenario analysis complete ===")
