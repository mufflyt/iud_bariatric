#!/usr/bin/env Rscript
#' Illustrative national, state-by-state opportunity-cost sweep
#'
#' NOT 51 independently-verified answers -- see R/opportunity_cost_national.R's
#' own docstring and docs/data_sources.md for the three compounding
#' approximations this makes (state-average, not hospital-specific,
#' Medicare wage index; single national ratios for Medicaid and
#' commercial, the latter already known not to match Denver Health's
#' own real rate for this procedure; Denver Health's own payer mix
#' applied to every state). Read this as an order-of-magnitude sweep
#' across Medicare's real geographic variation, not a precise
#' state-by-state finding.
#'
#' Run from the repository root:
#'   Rscript analysis/07_opportunity_cost_national.R

base::source("R/00_source_all.R")

base::message("=== Illustrative national opportunity-cost sweep (heavily caveated) ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")
wage_index_table <- load_state_wage_index_table()

result <- compute_national_opportunity_cost_by_state(model_parameters, wage_index_table)
result_sorted <- result |> dplyr::arrange(dplyr::desc(.data$opportunity_cost_of_added_minutes))

base::print(result_sorted)

n_positive <- base::sum(result$opportunity_cost_of_added_minutes > 0)
n_states <- base::nrow(result)

co_row <- result |> dplyr::filter(.data$state_abbr == "CO")
denver_health_real_rate <- get_parameter_value(model_parameters, "bariatric_denver_health_medicare_rate")

summary_sentence <- base::paste0(
  "Illustrative sweep across ", n_states, " states/territories: ", n_positive, " show a positive ",
  "implied opportunity cost, ranging from $", base::round(base::min(result$opportunity_cost_of_added_minutes), 2),
  " to $", base::round(base::max(result$opportunity_cost_of_added_minutes), 2), ". This is NOT a claim of ",
  "51 real, independently-verified answers -- Colorado's own state-average formula estimate here ",
  "($", base::round(co_row$medicare_payment, 2), ") is only ",
  base::round(co_row$medicare_payment / denver_health_real_rate * 100, 0),
  "% of Denver Health's own real, MRF-reported Medicare rate ($", base::round(denver_health_real_rate, 2),
  "), demonstrating directly that a state average understates hospital-specific outliers. The Medicaid ",
  "and commercial figures use single NATIONAL ratios, not state-specific ones, and the commercial ratio ",
  "specifically is already known to disagree with Denver Health's own real rate for this procedure. See ",
  "docs/data_sources.md for the full account of what this sweep can and cannot tell you."
)

base::message(summary_sentence)
readr::write_lines(summary_sentence, "tables/opportunity_cost_national_sentence.txt")

save_table(result_sorted, "opportunity_cost_national_by_state.csv")

base::message("")
base::message("=== Real multi-hospital comparison (strongest evidence, fewer hospitals) ===")

rates_table <- load_multi_hospital_rates_table()
multi_hospital_result <- compute_multi_hospital_opportunity_cost(model_parameters, rates_table) |>
  dplyr::arrange(dplyr::desc(.data$opportunity_cost_of_added_minutes))

base::print(multi_hospital_result)

complete_rows <- multi_hospital_result |> dplyr::filter(!base::is.na(.data$opportunity_cost_of_added_minutes))

multi_hospital_sentence <- base::paste0(
  "Real multi-hospital comparison (", base::nrow(complete_rows), " of ", base::nrow(multi_hospital_result),
  " hospitals with complete Medicare+Medicaid+commercial data, each hospital's OWN actual rate, no ",
  "state-average or borrowed-ratio approximation on the revenue side): opportunity cost of the added ",
  "minutes ranges from $", base::round(base::min(complete_rows$opportunity_cost_of_added_minutes), 2),
  " to $", base::round(base::max(complete_rows$opportunity_cost_of_added_minutes), 2), " -- genuinely ",
  "mixed sign, not a uniform finding. The three incomplete hospitals (Washington: no Medicare rate; ",
  "Pennsylvania and Arkansas: no public Medicaid rate) are reported as NA, not silently dropped or ",
  "backfilled. See docs/data_sources.md for the full citation trail on every figure."
)

base::message(multi_hospital_sentence)
readr::write_lines(multi_hospital_sentence, "tables/opportunity_cost_multi_hospital_sentence.txt")

save_table(multi_hospital_result, "opportunity_cost_multi_hospital.csv")

base::message("=== National sweep complete ===")
