#' Opportunity cost of a displaced case: a bounded sensitivity exercise
#'
#' Answers a direct question that came up in review: if the combined
#' arm's `combined_arm_added_minutes` means the OR can't fit in another
#' case that day, is that a real, priced cost? `docs/data_sources.md`
#' ("Opportunity cost of a displaced case: checked, real, not
#' quantifiable here") documents why no generalizable per-minute figure
#' exists in the OR-economics literature. This file goes one step
#' further with real, payer-specific case data, rather than stopping at
#' "no generic rate exists."
#'
#' SEPARATE from the base case. `compute_bounded_displaced_case_opportunity_cost()`
#' is not called by `compute_standalone_strategy_cost()`,
#' `compute_combined_strategy_cost()`, `compute_strategy_costs()`,
#' `run_scenario_analysis()`, or either sensitivity module. Nothing in
#' this file changes `expected_total_cost` or any other base-case
#' number.
#'
#' Method (a real, but explicitly bounding, calculation): a Medicare-
#' payer contribution margin for a routine bariatric-surgery case is
#' computed from two independently sourced national figures --
#' `bariatric_medicare_drg621_national_payment` (CMS's own FY2026 IPPS
#' payment for MS-DRG 621) minus `bariatric_blended_national_cost_ng2023`
#' (Ng et al. 2023's HCUP cost-to-charge-ratio-derived national cost) --
#' then divided by `bariatric_blended_typical_or_minutes` to get a
#' dollars-per-minute rate, then multiplied by
#' `combined_arm_added_minutes`. This treats the case's margin as if it
#' were earned uniformly across every minute of the case -- a
#' SIMPLIFYING ASSUMPTION, not the true mechanism. In reality, a
#' displaced case is a discrete, threshold event (an added 10 minutes
#' either does or does not push a case off the day's schedule); it does
#' not accrue continuously the way this per-minute approximation
#' implies. Treat the result as a bound on the order of magnitude, not
#' a precise cost.
#'
#' `denver_health_payer_mix_medicare_medicaid_uninsured_fraction`
#' (~83%) means this Medicare-payer calculation is representative of
#' most, but not all, of the anchor hospital's actual bariatric-surgery
#' payer mix; the remaining ~17% (commercial/other) is NOT quantified,
#' since no verified bariatric-surgery-specific commercial negotiated
#' rate was found for any hospital (see `docs/data_sources.md`).

#' Compute a bounded estimate of the opportunity cost of the combined
#' arm's added OR minutes, under a linear-share-of-case-time assumption
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @return A one-row tibble: `medicare_payment`, `national_cost`,
#'   `contribution_margin`, `typical_case_minutes`,
#'   `opportunity_cost_per_minute`, `added_minutes`,
#'   `opportunity_cost_of_added_minutes` (base case), plus
#'   `opportunity_cost_of_added_minutes_low` and `_high`, computed at
#'   `bariatric_blended_national_cost_ng2023`'s high and low bounds
#'   respectively (a higher cost means a lower margin, so the cost's
#'   high bound produces the opportunity-cost low bound, and vice
#'   versa).
compute_bounded_displaced_case_opportunity_cost <- function(model_parameters) {
  medicare_payment <- get_parameter_value(model_parameters, "bariatric_medicare_drg621_national_payment")
  national_cost <- get_parameter_value(model_parameters, "bariatric_blended_national_cost_ng2023")
  typical_case_minutes <- get_parameter_value(model_parameters, "bariatric_blended_typical_or_minutes")
  added_minutes <- get_parameter_value(model_parameters, "combined_arm_added_minutes")

  cost_row <- model_parameters |> dplyr::filter(.data$parameter == "bariatric_blended_national_cost_ng2023")
  cost_low <- cost_row$low_value[[1]]
  cost_high <- cost_row$high_value[[1]]

  contribution_margin <- medicare_payment - national_cost
  opportunity_cost_per_minute <- contribution_margin / typical_case_minutes
  opportunity_cost_of_added_minutes <- opportunity_cost_per_minute * added_minutes

  margin_at_low_cost <- medicare_payment - cost_low
  margin_at_high_cost <- medicare_payment - cost_high
  opportunity_cost_high <- (margin_at_low_cost / typical_case_minutes) * added_minutes
  opportunity_cost_low <- (margin_at_high_cost / typical_case_minutes) * added_minutes

  tibble::tibble(
    medicare_payment = medicare_payment,
    national_cost = national_cost,
    contribution_margin = contribution_margin,
    typical_case_minutes = typical_case_minutes,
    opportunity_cost_per_minute = opportunity_cost_per_minute,
    added_minutes = added_minutes,
    opportunity_cost_of_added_minutes = opportunity_cost_of_added_minutes,
    opportunity_cost_of_added_minutes_low = opportunity_cost_low,
    opportunity_cost_of_added_minutes_high = opportunity_cost_high
  )
}
