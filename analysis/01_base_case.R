#!/usr/bin/env Rscript
#' Base-case analysis
#'
#' Compares standalone IUD insertion against IUD insertion at the time of
#' bariatric surgery. Run from the repository root:
#'   Rscript analysis/01_base_case.R

base::source("R/00_source_all.R")

base::message("=== IUD-at-bariatric-surgery: base-case analysis ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")

strategy_costs <- compute_strategy_costs(model_parameters)
strategy_comparison <- compare_combined_vs_standalone(strategy_costs)

base::print(strategy_comparison)

save_table(strategy_comparison, "strategy_comparison.csv")

combined_row <- strategy_comparison |>
  dplyr::filter(.data$strategy == "combined")

summary_sentence <- base::paste0(
  "In the base case, IUD insertion at the time of bariatric surgery cost an ",
  "estimated $", base::round(combined_row$expected_total_cost, 2),
  " per patient, compared with $",
  base::round(
    strategy_comparison$expected_total_cost[strategy_comparison$strategy == "standalone"],
    2
  ),
  " for a standalone insertion visit -- a difference of $",
  base::round(base::abs(combined_row$incremental_cost_vs_standalone), 2),
  " (", if (combined_row$is_cheaper) "cheaper" else "more expensive", ")."
)

base::message(summary_sentence)
readr::write_lines(summary_sentence, "tables/summary_sentence.txt")

base::message("=== Base-case analysis complete ===")
