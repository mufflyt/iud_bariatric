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

coverage_sentence <- base::paste0(
  "Coverage caveat: this cost comparison assumes both arms place the device with equal ",
  "effectiveness. They do not. Combined placement happens in the OR while the patient is ",
  "already anesthetized, so it is treated as guaranteed (probability_device_placed = 1). ",
  "A real fraction of standalone patients never return for their scheduled visit at all ",
  "(probability_device_placed = ", base::round(standalone_row$probability_device_placed, 3),
  "), and unlike the postpartum-LARC literature's usual choice to chain that loss to an ",
  "unintended pregnancy, this population's actual stake is chained to endometrial cancer ",
  "instead (expected_missed_cancer_prevention_cost = $",
  base::round(standalone_row$expected_missed_cancer_prevention_cost, 2),
  " per referred standalone patient). Even counting that real cost, per patient REFERRED to ",
  "each strategy (not per patient who completes it), standalone costs an estimated $",
  base::round(standalone_row$expected_cost_per_referred_patient, 2),
  " vs. combined's $", base::round(combined_row$expected_cost_per_referred_patient, 2),
  " -- still a WIDER gap in standalone's favor than the per-completed-visit comparison above, ",
  "because the avoided-visit savings ($",
  base::round(
    standalone_row$expected_total_cost * (1 - standalone_row$probability_device_placed), 2
  ),
  ") outweighs the added cancer-risk cost. That is precisely the problem: standalone's ",
  "apparent extra savings here come partly from some patients never getting an IUD at all, ",
  "not entirely from a genuinely cheaper delivery of the same protection. Read the two ",
  "numbers together, not in isolation."
)

base::message(coverage_sentence)
readr::write_lines(coverage_sentence, "tables/coverage_sentence.txt")

base::message("=== Base-case analysis complete ===")
