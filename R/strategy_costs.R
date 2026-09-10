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
#'   Carries an expected escalation cost if the office attempt fails
#'   outright (Saito-Tom et al. 2015).
#' - `combined`: IUD device only, plus (if
#'   `combined_requires_separate_professional_fee` is TRUE) the same
#'   insertion professional fee, plus incremental operating-room and
#'   anesthesia minutes at the time of the already-scheduled bariatric
#'   surgery, inflation-adjusted to `reference_dollar_year`.
#'
#' Both arms also carry an EXPECTED replacement cost for device expulsion,
#' since Masten et al. 2024 (J Pediatr Adolesc Gynecol) found combined
#' bariatric-surgery placement carries a significantly higher 12-month
#' expulsion rate than non-combined placement (16.3% vs. 5.6%, adjusted
#' OR=3.23, P=.024) -- a real cost/effectiveness tradeoff working against
#' the combined arm's facility-cost advantage. A replacement is modeled as
#' its own standalone-style encounter (diagnosis office visit + new device
#' + reinsertion fee), regardless of which arm's device expelled, since by
#' the time expulsion is discovered the patient is no longer in the OR.
#'
#' Both arms also report a SOCIETAL add-on (patient time/travel
#' opportunity cost, Ray et al. 2015) alongside the healthcare-sector
#' total, not folded into it -- the standalone arm's dedicated office
#' visit incurs this cost; the combined arm's does not, since the patient
#' was already coming in for the bariatric surgery regardless.

#' Compute the expected cost of replacing an expelled device
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param expulsion_probability_parameter Character scalar naming the
#'   strategy-specific expulsion-probability parameter to use.
#' @return Numeric scalar: expulsion probability * full replacement-encounter cost.
compute_expected_replacement_cost <- function(model_parameters, expulsion_probability_parameter) {
  expulsion_probability <- get_parameter_value(model_parameters, expulsion_probability_parameter)
  device_cost <- get_parameter_value(model_parameters, "iud_device_acquisition_cost_gpo")
  professional_fee <- get_parameter_value(model_parameters, "iud_insertion_professional_fee")
  office_visit_cost <- get_parameter_value(model_parameters, "office_visit_em_cost")

  expulsion_probability * (device_cost + professional_fee + office_visit_cost)
}

#' Compute the inflation-adjusted incremental OR/anesthesia cost for the
#' combined arm's added minutes
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param price_index_table Tibble from [load_price_index_table()].
#' @return Numeric scalar, in `reference_dollar_year` dollars.
compute_added_or_cost <- function(model_parameters, price_index_table) {
  reference_year <- get_parameter_value(model_parameters, "reference_dollar_year")
  added_minutes <- get_parameter_value(model_parameters, "combined_arm_added_minutes")

  room_row <- model_parameters |> dplyr::filter(.data$parameter == "direct_room_cost_per_minute")
  anesthesia_row <- model_parameters |> dplyr::filter(.data$parameter == "anesthesia_cost_per_minute")

  room_cost_per_minute <- adjust_for_inflation(
    base::as.numeric(room_row$base_value[[1]]), room_row$dollar_year[[1]], reference_year, price_index_table
  )
  anesthesia_cost_per_minute <- adjust_for_inflation(
    base::as.numeric(anesthesia_row$base_value[[1]]), anesthesia_row$dollar_year[[1]], reference_year, price_index_table
  )

  added_minutes * (room_cost_per_minute + anesthesia_cost_per_minute)
}

#' Compute the standalone arm's societal (patient time/travel) add-on
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param price_index_table Tibble from [load_price_index_table()], using
#'   the general (all-items) CPI series.
#' @return Numeric scalar, in `reference_dollar_year` dollars.
compute_patient_time_addon <- function(model_parameters, price_index_table) {
  reference_year <- get_parameter_value(model_parameters, "reference_dollar_year")
  row <- model_parameters |>
    dplyr::filter(.data$parameter == "patient_time_opportunity_cost_per_visit")

  adjust_for_inflation(
    base::as.numeric(row$base_value[[1]]), row$dollar_year[[1]], reference_year, price_index_table
  )
}

#' Compute the standalone strategy's expected cost
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param price_index_table Tibble from [load_price_index_table()], used
#'   for the medical-care CPI (OR/anesthesia escalation cost).
#' @param all_items_price_index_table Tibble from [load_price_index_table()]
#'   pointed at `data/cpi_all_items.csv`, used for the patient-time-cost
#'   societal add-on.
#' @return A one-row tibble: `strategy`, `device_cost`, `professional_fee`,
#'   `office_visit_cost`, `added_or_cost`, `expected_replacement_cost`,
#'   `expected_escalation_cost`, `expected_total_cost`, `societal_addon`,
#'   `societal_total_cost`.
compute_standalone_strategy_cost <- function(
  model_parameters,
  price_index_table = load_price_index_table("data/cpi_medical_care.csv"),
  all_items_price_index_table = load_price_index_table("data/cpi_all_items.csv")
) {
  device_cost <- get_parameter_value(
    model_parameters, "iud_device_acquisition_cost_gpo"
  )
  professional_fee <- get_parameter_value(
    model_parameters, "iud_insertion_professional_fee"
  )
  office_visit_cost <- get_parameter_value(
    model_parameters, "office_visit_em_cost"
  )
  expected_replacement_cost <- compute_expected_replacement_cost(
    model_parameters, "iud_expulsion_probability_standalone"
  )

  failure_probability <- get_parameter_value(
    model_parameters, "standalone_office_failure_probability"
  )
  expected_escalation_cost <- failure_probability * compute_added_or_cost(
    model_parameters, price_index_table
  )

  expected_total_cost <- device_cost + professional_fee + office_visit_cost +
    expected_replacement_cost + expected_escalation_cost

  societal_addon <- compute_patient_time_addon(model_parameters, all_items_price_index_table)

  tibble::tibble(
    strategy = "standalone",
    device_cost = device_cost,
    professional_fee = professional_fee,
    office_visit_cost = office_visit_cost,
    added_or_cost = 0,
    expected_replacement_cost = expected_replacement_cost,
    expected_escalation_cost = expected_escalation_cost,
    expected_total_cost = expected_total_cost,
    societal_addon = societal_addon,
    societal_total_cost = expected_total_cost + societal_addon
  )
}

#' Compute the combined (at time of bariatric surgery) strategy's expected cost
#'
#' @inheritParams compute_standalone_strategy_cost
#' @return A one-row tibble, same columns as [compute_standalone_strategy_cost()].
compute_combined_strategy_cost <- function(
  model_parameters,
  price_index_table = load_price_index_table("data/cpi_medical_care.csv"),
  all_items_price_index_table = load_price_index_table("data/cpi_all_items.csv")
) {
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

  added_or_cost <- compute_added_or_cost(model_parameters, price_index_table)

  expected_replacement_cost <- compute_expected_replacement_cost(
    model_parameters, "iud_expulsion_probability_combined"
  )

  expected_total_cost <- device_cost + professional_fee + added_or_cost +
    expected_replacement_cost

  # No societal add-on: the patient was already coming in for the
  # bariatric surgery regardless, so this arm adds no incremental patient
  # time/travel burden.
  tibble::tibble(
    strategy = "combined",
    device_cost = device_cost,
    professional_fee = professional_fee,
    office_visit_cost = 0,
    added_or_cost = added_or_cost,
    expected_replacement_cost = expected_replacement_cost,
    expected_escalation_cost = 0,
    expected_total_cost = expected_total_cost,
    societal_addon = 0,
    societal_total_cost = expected_total_cost
  )
}

#' Compute both strategies' costs and bind them into one tibble
#'
#' @inheritParams compute_standalone_strategy_cost
#' @return A tibble with one row per strategy.
compute_strategy_costs <- function(
  model_parameters,
  price_index_table = load_price_index_table("data/cpi_medical_care.csv"),
  all_items_price_index_table = load_price_index_table("data/cpi_all_items.csv")
) {
  dplyr::bind_rows(
    compute_standalone_strategy_cost(model_parameters, price_index_table, all_items_price_index_table),
    compute_combined_strategy_cost(model_parameters, price_index_table, all_items_price_index_table)
  )
}
