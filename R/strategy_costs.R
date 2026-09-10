#' Strategy cost engine
#'
#' Two strategies, following the same incremental-cost principle as the
#' sibling `emb_colonoscopy` model: the bariatric surgery itself (and its
#' anesthesia, facility fee, and surgeon fee) is common to both strategies
#' and is never charged to either arm. Only genuinely incremental costs are
#' counted.
#'
#' - `standalone`: IUD device + a separate office visit (E/M fee) + a
#'   separate insertion professional fee (CPT 58300), as its own encounter.
#' - `combined`: IUD device only, plus (if
#'   `combined_requires_separate_professional_fee` is TRUE) the same
#'   insertion professional fee, plus incremental operating-room and
#'   anesthesia minutes at the time of the already-scheduled bariatric
#'   surgery.

#' Compute the standalone strategy's expected cost
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @return A one-row tibble: `strategy`, `device_cost`, `professional_fee`,
#'   `office_visit_cost`, `expected_total_cost`.
compute_standalone_strategy_cost <- function(model_parameters) {
  device_cost <- get_parameter_value(
    model_parameters, "iud_device_acquisition_cost_gpo"
  )
  professional_fee <- get_parameter_value(
    model_parameters, "iud_insertion_professional_fee"
  )
  office_visit_cost <- get_parameter_value(
    model_parameters, "office_visit_em_cost"
  )

  tibble::tibble(
    strategy = "standalone",
    device_cost = device_cost,
    professional_fee = professional_fee,
    office_visit_cost = office_visit_cost,
    added_or_cost = 0,
    expected_total_cost = device_cost + professional_fee + office_visit_cost
  )
}

#' Compute the combined (at time of bariatric surgery) strategy's expected cost
#'
#' @inheritParams compute_standalone_strategy_cost
#' @return A one-row tibble, same columns as [compute_standalone_strategy_cost()].
compute_combined_strategy_cost <- function(model_parameters) {
  device_cost <- get_parameter_value(
    model_parameters, "iud_device_acquisition_cost_gpo"
  )

  requires_separate_fee <- base::isTRUE(
    base::as.logical(
      get_parameter_raw_value(
        model_parameters, "combined_requires_separate_professional_fee"
      )
    )
  )
  professional_fee <- if (requires_separate_fee) {
    get_parameter_value(model_parameters, "iud_insertion_professional_fee")
  } else {
    0
  }

  added_minutes <- get_parameter_value(model_parameters, "combined_arm_added_minutes")
  room_cost_per_minute <- get_parameter_value(model_parameters, "direct_room_cost_per_minute")
  anesthesia_cost_per_minute <- get_parameter_value(model_parameters, "anesthesia_cost_per_minute")
  added_or_cost <- added_minutes * (room_cost_per_minute + anesthesia_cost_per_minute)

  tibble::tibble(
    strategy = "combined",
    device_cost = device_cost,
    professional_fee = professional_fee,
    office_visit_cost = 0,
    added_or_cost = added_or_cost,
    expected_total_cost = device_cost + professional_fee + added_or_cost
  )
}

#' Compute both strategies' costs and bind them into one tibble
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @return A tibble with one row per strategy.
compute_strategy_costs <- function(model_parameters) {
  dplyr::bind_rows(
    compute_standalone_strategy_cost(model_parameters),
    compute_combined_strategy_cost(model_parameters)
  )
}
