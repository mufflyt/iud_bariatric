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
#' - `combined`: IUD device, plus (if
#'   `combined_requires_separate_professional_fee` is TRUE, the default:
#'   the gynecologist places the device, not the bariatric surgeon,
#'   confirmed by the model owner 2026-09-10) the FACILITY-setting
#'   insertion professional fee (lower than standalone's office rate --
#'   a real CMS RVU differential, since the facility bills its own
#'   overhead separately; `iud_insertion_professional_fee x
#'   iud_insertion_professional_fee_facility_ratio`) plus the disposable
#'   supplies that facility rate excludes but the
#'   office rate bundles in (`iud_insertion_disposable_supply_cost`),
#'   plus (if `combined_requires_preop_office_visit` is TRUE, the
#'   default) a separate preop office visit with the gynecologist for
#'   counseling/consent -- a patient cannot meaningfully consent while
#'   already under anesthesia for a different procedure, so this happens
#'   on an earlier date, not folded into standalone's single combined
#'   E/M-plus-insertion visit -- plus incremental operating-room and
#'   anesthesia minutes at the time of the already-scheduled bariatric
#'   surgery, inflation-adjusted to `reference_dollar_year`, plus a
#'   scheduling-coordination cost (see
#'   `compute_scheduling_coordination_cost()`) for aligning the two
#'   surgeons' OR time, plus a postop results-discussion cost (see
#'   `compute_postop_discussion_cost()`) -- the patient is under
#'   anesthesia during placement, so the gynecologist has to discuss the
#'   procedure with them separately, by phone, since IUD insertions do
#'   not get a formal postop office visit. None of this is incurred by
#'   the standalone arm, whose single office visit already includes this
#'   discussion live.
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
#' Both arms also carry an EXPECTED perforation-management cost (Heinemann
#' et al. 2015, EURAS-IUD, 1.4 perforations per 1,000 LNG-IUD insertions;
#' HCUPnet-derived retrieval-episode cost via Dottino et al. 2016's Table
#' 2), applied identically to both arms -- no differential is modeled for
#' insertion setting, so this does not yet capture the possibility that a
#' perforation recognized at the time of a concurrent bariatric-surgery
#' insertion could be managed in the same operative setting rather than a
#' separate one (see `iud_perforation_management_cost`'s notes in
#' `config/model_parameters.csv` for why that refinement is deferred, not
#' omitted by oversight).
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

#' Compute the expected cost of managing a perforated device
#'
#' Applied identically to both arms: no differential is modeled for
#' insertion setting or anesthesia (see `iud_perforation_risk_baseline`'s
#' notes in `config/model_parameters.csv` for why), and the same
#' HCUPnet-derived retrieval-episode cost is used regardless of arm (see
#' `iud_perforation_management_cost`'s notes for a deferred refinement:
#' EURAS-IUD found perforation recognized at insertion in only a minority
#' of cases, which could in principle let the combined arm avoid a full
#' separate episode for that subset -- not modeled here).
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param price_index_table Tibble from [load_price_index_table()].
#' @return Numeric scalar: perforation probability * inflation-adjusted
#'   management cost.
compute_expected_perforation_cost <- function(model_parameters, price_index_table) {
  reference_year <- get_parameter_value(model_parameters, "reference_dollar_year")
  perforation_probability <- get_parameter_value(model_parameters, "iud_perforation_risk_baseline")

  row <- model_parameters |> dplyr::filter(.data$parameter == "iud_perforation_management_cost")
  management_cost <- adjust_for_inflation(
    base::as.numeric(row$base_value[[1]]), row$dollar_year[[1]], reference_year, price_index_table
  )

  perforation_probability * management_cost
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

#' Compute the combined arm's scheduling-coordination cost
#'
#' The gynecologist places the IUD, not the bariatric surgeon (confirmed
#' by the model owner, 2026-09-10), so combining the two procedures
#' requires two different surgeons' OR time to be aligned -- a real
#' administrative cost the standalone arm never incurs, since it is a
#' single physician's own routine office visit.
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param price_index_table Tibble from [load_price_index_table()], using
#'   the general (all-items) CPI series, since this is a wage cost, not a
#'   medical-service price.
#' @return Numeric scalar, in `reference_dollar_year` dollars.
compute_scheduling_coordination_cost <- function(model_parameters, price_index_table) {
  reference_year <- get_parameter_value(model_parameters, "reference_dollar_year")
  coordination_minutes <- get_parameter_value(model_parameters, "combined_arm_scheduling_coordination_minutes")

  row <- model_parameters |> dplyr::filter(.data$parameter == "surgery_scheduler_wage_per_minute")
  wage_per_minute <- adjust_for_inflation(
    base::as.numeric(row$base_value[[1]]), row$dollar_year[[1]], reference_year, price_index_table
  )

  coordination_minutes * wage_per_minute
}

#' Compute the combined arm's postop results-discussion cost
#'
#' The combined arm's device is placed while the patient is under
#' anesthesia, so the gynecologist cannot discuss the procedure with the
#' patient at the time of placement the way the standalone arm's single
#' office visit does. IUD insertions do not get a formal postop office
#' visit (confirmed directly, see
#' `iud_string_check_followup_not_recommended`), so this conversation
#' happens as a separate phone call after the patient's bariatric-surgery
#' recovery, not as a billable encounter (no physical exam is needed for
#' the IUD specifically) -- priced as raw physician time, not a
#' procedure fee.
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param price_index_table Tibble from [load_price_index_table()], using
#'   the general (all-items) CPI series, since this is a wage cost, not a
#'   medical-service price.
#' @return Numeric scalar, in `reference_dollar_year` dollars.
compute_postop_discussion_cost <- function(model_parameters, price_index_table) {
  reference_year <- get_parameter_value(model_parameters, "reference_dollar_year")
  discussion_minutes <- get_parameter_value(model_parameters, "combined_arm_postop_discussion_minutes")

  row <- model_parameters |> dplyr::filter(.data$parameter == "gynecologist_wage_per_minute")
  wage_per_minute <- adjust_for_inflation(
    base::as.numeric(row$base_value[[1]]), row$dollar_year[[1]], reference_year, price_index_table
  )

  discussion_minutes * wage_per_minute
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

  expected_perforation_cost <- compute_expected_perforation_cost(model_parameters, price_index_table)

  expected_total_cost <- device_cost + professional_fee + office_visit_cost +
    expected_replacement_cost + expected_escalation_cost + expected_perforation_cost

  societal_addon <- compute_patient_time_addon(model_parameters, all_items_price_index_table)

  tibble::tibble(
    strategy = "standalone",
    device_cost = device_cost,
    professional_fee = professional_fee,
    office_visit_cost = office_visit_cost,
    disposable_supply_cost = 0,
    added_or_cost = 0,
    scheduling_coordination_cost = 0,
    postop_discussion_cost = 0,
    expected_replacement_cost = expected_replacement_cost,
    expected_escalation_cost = expected_escalation_cost,
    expected_perforation_cost = expected_perforation_cost,
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
  # The combined arm's own (first) insertion happens in the OR/facility
  # setting, not the physician's own office, so it uses the
  # facility-setting professional fee (lower than the office rate: a real
  # CMS RVU differential, see iud_insertion_professional_fee_facility's
  # source) plus the disposable supplies the facility rate excludes (see
  # iud_insertion_disposable_supply_cost). This does NOT apply to a
  # replacement encounter (always modeled as an office-style visit
  # regardless of which arm's device expelled) or to the standalone arm's
  # own insertion, both of which correctly keep using
  # iud_insertion_professional_fee, the office rate.
  professional_fee <- if (requires_separate_fee) {
    get_parameter_value(model_parameters, "iud_insertion_professional_fee") *
      get_parameter_value(model_parameters, "iud_insertion_professional_fee_facility_ratio")
  } else {
    0
  }
  disposable_supply_cost <- if (requires_separate_fee) {
    get_parameter_value(model_parameters, "iud_insertion_disposable_supply_cost")
  } else {
    0
  }

  # A patient cannot meaningfully consent to a procedure while already
  # under anesthesia for a different one, so the consenting physician
  # (the gynecologist, not the bariatric surgeon) needs their own
  # encounter on an earlier date. Uses office_visit_cost, the same
  # column standalone's own insertion visit occupies, since this fills
  # the analogous "office visit" slot in the combined arm's cost
  # breakdown rather than adding a new one.
  requires_preop_visit <- base::isTRUE(
    base::as.logical(
      get_parameter_raw_value(
        model_parameters, "combined_requires_preop_office_visit"
      )
    )
  )
  office_visit_cost <- if (requires_preop_visit) {
    get_parameter_value(model_parameters, "iud_preop_office_visit_cost")
  } else {
    0
  }

  added_or_cost <- compute_added_or_cost(model_parameters, price_index_table)

  expected_replacement_cost <- compute_expected_replacement_cost(
    model_parameters, "iud_expulsion_probability_combined"
  )

  expected_perforation_cost <- compute_expected_perforation_cost(model_parameters, price_index_table)

  scheduling_coordination_cost <- compute_scheduling_coordination_cost(
    model_parameters, all_items_price_index_table
  )

  postop_discussion_cost <- compute_postop_discussion_cost(model_parameters, all_items_price_index_table)

  expected_total_cost <- device_cost + professional_fee + office_visit_cost + disposable_supply_cost +
    added_or_cost + expected_replacement_cost + expected_perforation_cost + scheduling_coordination_cost +
    postop_discussion_cost

  # No societal add-on: the patient was already coming in for the
  # bariatric surgery regardless, so this arm adds no incremental patient
  # time/travel burden.
  tibble::tibble(
    strategy = "combined",
    device_cost = device_cost,
    professional_fee = professional_fee,
    office_visit_cost = office_visit_cost,
    disposable_supply_cost = disposable_supply_cost,
    added_or_cost = added_or_cost,
    scheduling_coordination_cost = scheduling_coordination_cost,
    postop_discussion_cost = postop_discussion_cost,
    expected_replacement_cost = expected_replacement_cost,
    expected_escalation_cost = 0,
    expected_perforation_cost = expected_perforation_cost,
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
