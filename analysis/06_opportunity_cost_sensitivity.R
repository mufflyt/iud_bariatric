#!/usr/bin/env Rscript
#' Opportunity cost of a displaced case: bounded sensitivity exercise
#'
#' NOT part of the base case. See R/opportunity_cost_sensitivity.R for
#' the full methodology, and docs/data_sources.md for the citation
#' trail and the linear-vs-threshold modeling caveat.
#'
#' Run from the repository root:
#'   Rscript analysis/06_opportunity_cost_sensitivity.R

base::source("R/00_source_all.R")

base::message("=== Opportunity cost of a displaced case: bounded sensitivity exercise ===")

model_parameters <- load_model_parameters("config/model_parameters.csv")

result <- compute_bounded_displaced_case_opportunity_cost(model_parameters)
base::print(result)

payer_mix_fraction <- get_parameter_value(
  model_parameters, "denver_health_payer_mix_medicare_medicaid_uninsured_fraction"
)

opportunity_cost_sentence <- base::paste0(
  "Using real, payer-specific data (CMS FY2026 IPPS MS-DRG 621 national payment $",
  base::round(result$medicare_payment, 2), "; Ng et al. 2023's blended national bariatric-surgery ",
  "cost $", base::round(result$national_cost, 2), "), the implied Medicare-payer contribution margin ",
  "for a routine bariatric case is $", base::round(result$contribution_margin, 2), " -- NEGATIVE. ",
  "Spread across a typical case's ", base::round(result$typical_case_minutes, 1),
  " minutes (a simplifying linear-share assumption, not the true threshold mechanism -- see this ",
  "script's header), the combined arm's ", result$added_minutes, "-minute add-on implies an ",
  "opportunity cost of $", base::round(result$opportunity_cost_of_added_minutes, 2),
  " (95% range implied by Ng et al.'s cost IQR: $",
  base::round(result$opportunity_cost_of_added_minutes_low, 2), " to $",
  base::round(result$opportunity_cost_of_added_minutes_high, 2), "). A NEGATIVE value means no real ",
  "added cost under this bound -- if anything, a small implied saving. This is representative of ",
  "roughly ", base::round(payer_mix_fraction * 100, 0), "% of Denver Health's actual bariatric-surgery ",
  "payer mix (Medicare, Medicaid, and uninsured combined); the remaining ~",
  base::round((1 - payer_mix_fraction) * 100, 0), "% (commercial/other) is NOT quantified here, since ",
  "no verified bariatric-surgery-specific commercial negotiated rate was found. Not added to ",
  "expected_total_cost anywhere in this model -- see docs/data_sources.md for why this stays a ",
  "documented bound, not a wired-in parameter."
)

base::message(opportunity_cost_sentence)
readr::write_lines(opportunity_cost_sentence, "tables/opportunity_cost_sentence.txt")

save_table(result, "opportunity_cost_sensitivity.csv")

base::message("=== Opportunity cost sensitivity exercise complete ===")
