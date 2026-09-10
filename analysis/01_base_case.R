#!/usr/bin/env Rscript
#' Base-case analysis
#'
#' Compares standalone IUD insertion against IUD insertion at the time of
#' bariatric surgery. Run from the repository root:
#'   Rscript analysis/01_base_case.R

base::source("R/00_source_all.R")

base::message("=== IUD-at-bariatric-surgery: base-case analysis ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")
price_index_table <- load_price_index_table("data/cpi_medical_care.csv")
all_items_price_index_table <- load_price_index_table("data/cpi_all_items.csv")

strategy_costs <- compute_strategy_costs(
  model_parameters, price_index_table, all_items_price_index_table
)
strategy_comparison <- compare_combined_vs_standalone(strategy_costs)

base::print(strategy_comparison)

save_table(strategy_comparison, "strategy_comparison.csv")

standalone_row <- strategy_comparison |> dplyr::filter(.data$strategy == "standalone")
combined_row <- strategy_comparison |> dplyr::filter(.data$strategy == "combined")

summary_sentence <- base::paste0(
  "In the base case (healthcare-sector perspective), IUD insertion at the time ",
  "of bariatric surgery cost an estimated $", base::round(combined_row$expected_total_cost, 2),
  " per patient, compared with $", base::round(standalone_row$expected_total_cost, 2),
  " for a standalone insertion visit -- a difference of $",
  base::round(base::abs(combined_row$incremental_cost_vs_standalone), 2),
  " (", if (combined_row$is_cheaper) "cheaper" else "more expensive", "). Including the ",
  "societal patient-time/travel add-on, the standalone visit costs $",
  base::round(standalone_row$societal_total_cost, 2), " vs. the combined arm's $",
  base::round(combined_row$societal_total_cost, 2), "."
)

base::message(summary_sentence)
readr::write_lines(summary_sentence, "tables/summary_sentence.txt")

base::message("=== Base-case analysis complete ===")
