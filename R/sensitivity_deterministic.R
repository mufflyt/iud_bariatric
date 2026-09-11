#' One-way deterministic sensitivity analysis
#'
#' Answers a concrete question this project had been treating as a guess:
#' of all the uncertain parameters in `config/model_parameters.csv`, which
#' ones actually move the headline result (the incremental cost gap
#' between the combined and standalone arms), and which ones only move
#' both arms' absolute cost levels together without changing which
#' strategy looks cheaper? A parameter whose low/high sweep leaves the gap
#' essentially unchanged (`swing` near zero) is one applied identically to
#' both arms (see `R/strategy_costs.R`'s incremental-cost principle) --
#' verifying it further would sharpen the absolute cost estimate but would
#' not change the standalone-vs-combined conclusion.
#'
#' Only parameters that are (a) actually consumed by the cost engine and
#' (b) have a real, sourced `low_value`/`high_value` pair in
#' `config/model_parameters.csv` are swept. Two parameters that ARE
#' consumed by the cost engine but currently have NO low/high range at
#' all are deliberately excluded rather than silently skipped:
#' `patient_time_opportunity_cost_per_visit` (reused from the sibling
#' project as a point estimate) and `iud_perforation_management_cost`
#' (a low value exists, Dottino's HCUPnet median, but no sourced high
#' value -- only a mean and median were reported, no upper CI). These
#' gaps are exactly the kind of thing this analysis exists to surface,
#' not paper over with an invented range.
#'
#' `iud_expulsion_probability_combined` -- Masten et al. 2024's 16.3%
#' combined-arm expulsion rate, the single number most directly
#' responsible for the combined arm's cost disadvantage -- was itself one
#' of these gaps until 2026-09-10, when this analysis's own output made
#' the gap worth closing: it now has a real low/high range (an exact
#' Clopper-Pearson 95% CI on the paper's own 7/43 raw proportion) and is
#' included below.

#' Named vector of parameters eligible for one-way sensitivity sweeps
#'
#' Every name here is (a) read by a `compute_*` function in
#' `R/strategy_costs.R` and (b) has a real, non-missing `low_value` and
#' `high_value` in `config/model_parameters.csv`.
SENSITIVITY_PARAMETER_NAMES <- c(
  "iud_device_acquisition_cost_gpo",
  "iud_insertion_professional_fee",
  "office_visit_em_cost",
  "combined_arm_added_minutes",
  "direct_room_cost_per_minute",
  "anesthesia_cost_per_minute",
  "iud_expulsion_probability_standalone",
  "iud_expulsion_probability_combined",
  "standalone_office_failure_probability",
  "iud_perforation_risk_baseline"
)

#' Compute the combined arm's incremental cost vs. standalone
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param price_index_table Tibble from [load_price_index_table()].
#' @param all_items_price_index_table Tibble from [load_price_index_table()]
#'   pointed at `data/cpi_all_items.csv`.
#' @param cancer_prevention_parameters Tibble from
#'   [load_model_parameters()] pointed at
#'   `config/cancer_prevention_parameters.csv`.
#' @return Numeric scalar: combined's `expected_total_cost` minus
#'   standalone's.
compute_incremental_gap <- function(
  model_parameters,
  price_index_table,
  all_items_price_index_table,
  cancer_prevention_parameters = load_model_parameters("config/cancer_prevention_parameters.csv")
) {
  strategy_costs <- compute_strategy_costs(
    model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
  )
  comparison <- compare_combined_vs_standalone(strategy_costs)

  comparison$incremental_cost_vs_standalone[comparison$strategy == "combined"]
}

#' Run a one-way (low/high, one parameter at a time) sensitivity sweep
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param price_index_table Tibble from [load_price_index_table()].
#' @param all_items_price_index_table Tibble from [load_price_index_table()]
#'   pointed at `data/cpi_all_items.csv`.
#' @param parameter_names Character vector of parameter names to sweep;
#'   defaults to [SENSITIVITY_PARAMETER_NAMES].
#' @param cancer_prevention_parameters Tibble from
#'   [load_model_parameters()] pointed at
#'   `config/cancer_prevention_parameters.csv`.
#' @return A tibble with one row per parameter: `parameter`, `low_value`,
#'   `high_value`, `base_case_gap`, `gap_at_low`, `gap_at_high`, `swing`
#'   (`abs(gap_at_high - gap_at_low)`), sorted by `swing` descending (the
#'   conventional tornado-diagram order: most-impactful parameter first).
run_one_way_sensitivity <- function(
  model_parameters,
  price_index_table,
  all_items_price_index_table,
  parameter_names = SENSITIVITY_PARAMETER_NAMES,
  cancer_prevention_parameters = load_model_parameters("config/cancer_prevention_parameters.csv")
) {
  base_case_gap <- compute_incremental_gap(
    model_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
  )

  results <- purrr::map_dfr(parameter_names, function(parameter_name) {
    row <- model_parameters |> dplyr::filter(.data$parameter == .env$parameter_name)
    if (base::nrow(row) != 1) {
      base::stop("Expected exactly one parameter row for: ", parameter_name)
    }

    low_value <- row$low_value[[1]]
    high_value <- row$high_value[[1]]
    if (base::is.na(low_value) || base::is.na(high_value)) {
      base::stop(
        "run_one_way_sensitivity() requires a non-missing low_value and ",
        "high_value; ", parameter_name, " has at least one missing. ",
        "Exclude it from parameter_names instead of sweeping a fabricated bound."
      )
    }

    low_parameters <- override_model_parameters(
      model_parameters, stats::setNames(base::list(low_value), parameter_name)
    )
    high_parameters <- override_model_parameters(
      model_parameters, stats::setNames(base::list(high_value), parameter_name)
    )

    gap_at_low <- compute_incremental_gap(
      low_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
    )
    gap_at_high <- compute_incremental_gap(
      high_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
    )

    tibble::tibble(
      parameter = parameter_name,
      low_value = low_value,
      high_value = high_value,
      base_case_gap = base_case_gap,
      gap_at_low = gap_at_low,
      gap_at_high = gap_at_high,
      swing = base::abs(gap_at_high - gap_at_low)
    )
  })

  results |> dplyr::arrange(dplyr::desc(.data$swing))
}
