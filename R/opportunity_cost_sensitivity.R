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
#' REVISION HISTORY, kept visible rather than silently overwritten (see
#' `docs/data_sources.md` for the full account): the first version of
#' this file used a single, generic national-unadjusted Medicare payment
#' (`bariatric_medicare_drg621_national_payment`, $10,976.27) as the
#' revenue side, producing a NEGATIVE contribution margin and a small
#' negative opportunity-cost estimate. Asked to dig harder for real
#' payer-specific data, Denver Health's own current CMS
#' price-transparency file and Colorado Medicaid's own published rate
#' tables were downloaded and parsed directly, revealing that this
#' hospital's actual negotiated/adjusted rates for every payer run
#' substantially ABOVE the generic national figures (its own Medicare
#' rate alone is 2.5x the national-unadjusted estimate). Using those
#' hospital-specific rates, weighted by Denver Health's own reported
#' payer mix, reverses the sign: the margin is POSITIVE, and the
#' opportunity cost of the added minutes is now a real, moderate
#' expected cost, not a wash or a saving. This is exactly the kind of
#' correction this project's documentation discipline exists to surface
#' plainly rather than quietly patch over.
#'
#' Method: a payer-mix-weighted revenue estimate for a routine bariatric
#' case at Denver Health is built from three real, hospital-specific
#' rates -- `bariatric_denver_health_medicare_rate` (from Denver
#' Health's own CMS machine-readable file), `bariatric_denver_health_
#' medicaid_rate` (Denver Health's own Colorado Medicaid base rate x
#' the matching APR-DRG weight), and `bariatric_denver_health_
#' commercial_mean_rate` (the mean of five real negotiated commercial
#' rates at Denver Health) -- weighted by Denver Health's approximate
#' payer-mix fractions (`denver_health_payer_mix_medicare_fraction`,
#' `_medicaid_fraction`, `_commercial_fraction`; uninsured/self-pay is
#' assigned $0 net revenue, a standard conservative simplification).
#' That weighted revenue minus `bariatric_blended_national_cost_ng2023`
#' (still a NATIONAL cost proxy -- no Denver-Health-specific cost figure
#' was found) gives a contribution margin, divided by
#' `bariatric_blended_typical_or_minutes` to get a dollars-per-minute
#' rate, then multiplied by `combined_arm_added_minutes`. This treats
#' the case's margin as if it were earned uniformly across every minute
#' of the case -- a SIMPLIFYING ASSUMPTION, not the true mechanism. In
#' reality, a displaced case is a discrete, threshold event (an added 10
#' minutes either does or does not push a case off the day's schedule);
#' it does not accrue continuously the way this per-minute approximation
#' implies. Treat the result as a bound on the order of magnitude, not a
#' precise cost.

#' Compute Denver Health's payer-mix-weighted revenue for a routine
#' bariatric-surgery case
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @return Numeric scalar, in USD. Uninsured/self-pay is implicitly
#'   assigned $0 net revenue: the three named payer fractions do not sum
#'   to 1, and the remainder (Denver Health's uninsured share) is simply
#'   not added to the weighted sum.
compute_payer_mix_weighted_revenue <- function(model_parameters) {
  medicare_rate <- get_parameter_value(model_parameters, "bariatric_denver_health_medicare_rate")
  medicaid_rate <- get_parameter_value(model_parameters, "bariatric_denver_health_medicaid_rate")
  commercial_rate <- get_parameter_value(model_parameters, "bariatric_denver_health_commercial_mean_rate")

  medicare_fraction <- get_parameter_value(model_parameters, "denver_health_payer_mix_medicare_fraction")
  medicaid_fraction <- get_parameter_value(model_parameters, "denver_health_payer_mix_medicaid_fraction")
  commercial_fraction <- get_parameter_value(model_parameters, "denver_health_payer_mix_commercial_fraction")

  medicare_rate * medicare_fraction +
    medicaid_rate * medicaid_fraction +
    commercial_rate * commercial_fraction
}

#' Compute a bounded estimate of the opportunity cost of the combined
#' arm's added OR minutes, under a linear-share-of-case-time assumption
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @return A one-row tibble: `weighted_revenue`, `national_cost`,
#'   `contribution_margin`, `typical_case_minutes`,
#'   `opportunity_cost_per_minute`, `added_minutes`,
#'   `opportunity_cost_of_added_minutes` (base case), plus
#'   `opportunity_cost_of_added_minutes_low` and `_high`, computed at
#'   `bariatric_blended_national_cost_ng2023`'s high and low bounds
#'   respectively (a higher cost means a lower margin, so the cost's
#'   high bound produces the opportunity-cost low bound, and vice
#'   versa).
compute_bounded_displaced_case_opportunity_cost <- function(model_parameters) {
  weighted_revenue <- compute_payer_mix_weighted_revenue(model_parameters)
  national_cost <- get_parameter_value(model_parameters, "bariatric_blended_national_cost_ng2023")
  typical_case_minutes <- get_parameter_value(model_parameters, "bariatric_blended_typical_or_minutes")
  added_minutes <- get_parameter_value(model_parameters, "combined_arm_added_minutes")

  cost_row <- model_parameters |> dplyr::filter(.data$parameter == "bariatric_blended_national_cost_ng2023")
  cost_low <- cost_row$low_value[[1]]
  cost_high <- cost_row$high_value[[1]]

  contribution_margin <- weighted_revenue - national_cost
  opportunity_cost_per_minute <- contribution_margin / typical_case_minutes
  opportunity_cost_of_added_minutes <- opportunity_cost_per_minute * added_minutes

  margin_at_low_cost <- weighted_revenue - cost_low
  margin_at_high_cost <- weighted_revenue - cost_high
  opportunity_cost_high <- (margin_at_low_cost / typical_case_minutes) * added_minutes
  opportunity_cost_low <- (margin_at_high_cost / typical_case_minutes) * added_minutes

  tibble::tibble(
    weighted_revenue = weighted_revenue,
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
