#' National, state-by-state extension of the opportunity-cost exercise
#'
#' `R/opportunity_cost_sensitivity.R` computed a real, hospital-specific
#' opportunity-cost estimate for Denver Health, using its own actual
#' negotiated Medicare, Medicaid, and commercial rates. This file asks a
#' different, much rougher question: "if we assumed Denver Health's own
#' payer mix and case economics held everywhere, but let Medicare's
#' payment vary by each state's own wage index, what would this look
#' like nationally?" The honest answer is that this compounds several
#' real approximations on top of each other, each documented in
#' `config/model_parameters.csv` and `docs/data_sources.md`:
#'
#' 1. Medicare payment uses a STATE-AVERAGE wage index (from CMS's own
#'    FY2026 data, real and current), not a hospital-specific one, and
#'    does not apply IME, DSH, or outlier adjustments. Checked directly
#'    against Colorado: this formula predicts $11,355 for a "typical"
#'    Colorado hospital, only 41% of Denver Health's own real,
#'    MRF-reported rate ($27,902.21) -- a specific, demonstrated
#'    understatement for safety-net teaching hospitals, not a
#'    hypothetical concern.
#' 2. UPDATE (2026-09-12): Medicaid and commercial payments now use
#'    EMPIRICAL ratios (`empirical_medicaid_to_medicare_ratio`,
#'    `empirical_commercial_to_medicare_ratio`) derived from real
#'    payer-specific rates at 9-10 real hospitals across 9-10 states
#'    (`data/bariatric_drg621_multi_hospital_rates.csv`) -- replacing
#'    the original single borrowed national ratios (RAND's 2.54,
#'    MACPAC's stale 1.06), both still kept in
#'    `config/model_parameters.csv` as documented superseded reference
#'    points. This real sample confirms two things: RAND's national
#'    commercial ratio (2.54) is actually a reasonable estimate of the
#'    CENTRAL TENDENCY (this sample's mean is 2.035), it just doesn't
#'    apply well to any one hospital (the real range is 1.167-3.542,
#'    a 3x spread) -- and MACPAC's Medicaid ratio (1.06, from 2010 data)
#'    was a real overstatement: this sample's real, current ratios run
#'    0.25-0.98, mean 0.589. Still NOT state-specific: this file still
#'    applies one flat ratio (not 50 different ones) to every state's
#'    own Medicare figure, since no real ratio exists yet for the other
#'    ~40 states not sampled.
#' 3. The payer-mix weights are Denver Health's OWN mix (heavily
#'    Medicare/Medicaid, safety-net-hospital-specific), applied
#'    uniformly to every state. Most hospitals nationally are not
#'    safety-net hospitals with this payer mix.
#'
#' Given all three, this file's 52-state sweep should still be read as
#' an order-of-magnitude, illustrative exercise -- not as 51 real,
#' independently-verified answers. For that, see
#' `compute_multi_hospital_opportunity_cost()` below, which uses each of
#' the 9-10 real, individually-sourced hospitals' OWN actual rates
#' directly, with no state-average or borrowed-ratio approximation on
#' the revenue side at all -- the strongest evidence this project has,
#' just for far fewer hospitals. Like `R/opportunity_cost_sensitivity.R`,
#' nothing here is called by the base-case cost engine or either
#' sensitivity module.

#' Load the state-average Medicare wage index table
#'
#' @param path Character scalar path to the wage index CSV.
#' @return A tibble: `state_abbr`, `n_hospitals`, `mean_wage_index`, `source`.
load_state_wage_index_table <- function(path = "data/medicare_wage_index_by_state_fy2026.csv") {
  if (!base::file.exists(path)) {
    base::stop("State wage index file not found at: ", path)
  }

  readr::read_csv(
    path,
    col_types = readr::cols(
      state_abbr = readr::col_character(),
      n_hospitals = readr::col_double(),
      mean_wage_index = readr::col_double(),
      source = readr::col_character()
    ),
    show_col_types = FALSE
  )
}

#' Compute one state's estimated Medicare DRG 621 payment from its wage index
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param wage_index Numeric scalar, a state's mean Medicare wage index.
#' @return Numeric scalar, in USD.
compute_state_medicare_payment <- function(model_parameters, wage_index) {
  operating_base <- get_parameter_value(model_parameters, "medicare_ipps_operating_base_rate_fy2026")
  capital_base <- get_parameter_value(model_parameters, "medicare_ipps_capital_base_rate_fy2026")
  weight <- get_parameter_value(model_parameters, "medicare_drg621_relative_weight")

  labor_share_high <- get_parameter_value(model_parameters, "medicare_labor_related_share_high_wage_index")
  labor_share_low <- get_parameter_value(model_parameters, "medicare_labor_related_share_low_wage_index")
  labor_share <- if (wage_index > 1.0) labor_share_high else labor_share_low

  operating_payment <- weight * operating_base * (labor_share * wage_index + (1 - labor_share))
  capital_payment <- weight * capital_base

  operating_payment + capital_payment
}

#' Compute the illustrative national, state-by-state opportunity-cost sweep
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param wage_index_table Tibble from [load_state_wage_index_table()].
#' @return A tibble, one row per state: `state_abbr`, `n_hospitals`,
#'   `mean_wage_index`, `medicare_payment`, `medicaid_payment`,
#'   `commercial_payment`, `weighted_revenue`, `contribution_margin`,
#'   `opportunity_cost_of_added_minutes`.
compute_national_opportunity_cost_by_state <- function(
  model_parameters,
  wage_index_table = load_state_wage_index_table()
) {
  medicaid_ratio <- get_parameter_value(model_parameters, "empirical_medicaid_to_medicare_ratio")
  commercial_ratio <- get_parameter_value(model_parameters, "empirical_commercial_to_medicare_ratio")

  medicare_fraction <- get_parameter_value(model_parameters, "denver_health_payer_mix_medicare_fraction")
  medicaid_fraction <- get_parameter_value(model_parameters, "denver_health_payer_mix_medicaid_fraction")
  commercial_fraction <- get_parameter_value(model_parameters, "denver_health_payer_mix_commercial_fraction")

  national_cost <- get_parameter_value(model_parameters, "bariatric_blended_national_cost_ng2023")
  typical_case_minutes <- get_parameter_value(model_parameters, "bariatric_blended_typical_or_minutes")
  added_minutes <- get_parameter_value(model_parameters, "combined_arm_added_minutes")

  wage_index_table |>
    dplyr::rowwise() |>
    dplyr::mutate(
      medicare_payment = compute_state_medicare_payment(model_parameters, .data$mean_wage_index),
      medicaid_payment = .data$medicare_payment * medicaid_ratio,
      commercial_payment = .data$medicare_payment * commercial_ratio,
      weighted_revenue = .data$medicare_payment * medicare_fraction +
        .data$medicaid_payment * medicaid_fraction +
        .data$commercial_payment * commercial_fraction,
      contribution_margin = .data$weighted_revenue - national_cost,
      opportunity_cost_of_added_minutes = (.data$contribution_margin / typical_case_minutes) * added_minutes
    ) |>
    dplyr::ungroup() |>
    dplyr::select(
      "state_abbr", "n_hospitals", "mean_wage_index", "medicare_payment", "medicaid_payment",
      "commercial_payment", "weighted_revenue", "contribution_margin", "opportunity_cost_of_added_minutes"
    )
}

#' Load the real, multi-hospital MS-DRG 621 rate table
#'
#' Ten hospitals across ten states, each with payer-specific rates
#' pulled directly from that hospital's own CMS price-transparency file
#' and, where a public state Medicaid rate methodology exists, a
#' computed Medicaid payment. See `docs/data_sources.md` for the full
#' citation trail (every URL, exact figure, and confidence note).
#'
#' @param path Character scalar path to the multi-hospital rate CSV.
#' @return A tibble, one row per hospital.
load_multi_hospital_rates_table <- function(path = "data/bariatric_drg621_multi_hospital_rates.csv") {
  if (!base::file.exists(path)) {
    base::stop("Multi-hospital rate file not found at: ", path)
  }

  readr::read_csv(
    path,
    col_types = readr::cols(
      state_abbr = readr::col_character(),
      hospital = readr::col_character(),
      medicare_rate = readr::col_double(),
      medicaid_rate = readr::col_double(),
      commercial_mean_rate = readr::col_double(),
      medicare_confidence = readr::col_character(),
      medicaid_confidence = readr::col_character(),
      commercial_confidence = readr::col_character(),
      notes = readr::col_character(),
      medicaid_to_medicare_ratio = readr::col_double(),
      commercial_to_medicare_ratio = readr::col_double(),
      source = readr::col_character()
    ),
    show_col_types = FALSE
  )
}

#' Compute each real hospital's own opportunity-cost estimate directly
#' from its own actual rates
#'
#' Unlike `compute_national_opportunity_cost_by_state()`, this applies
#' NO state-average or borrowed-ratio approximation to the revenue side:
#' every Medicare, Medicaid, and commercial figure is that specific
#' hospital's own real rate. The only remaining approximation is the
#' payer-mix weighting (still Denver Health's own mix, applied to every
#' hospital) and the national cost proxy (Ng et al., not
#' hospital-specific). Hospitals missing any one of the three rates are
#' returned with `NA` results rather than silently dropped or
#' backfilled with a placeholder.
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param rates_table Tibble from [load_multi_hospital_rates_table()].
#' @return A tibble, one row per hospital: `state_abbr`, `hospital`,
#'   `medicare_rate`, `medicaid_rate`, `commercial_mean_rate`,
#'   `weighted_revenue`, `contribution_margin`,
#'   `opportunity_cost_of_added_minutes` (the latter three `NA` when any
#'   input rate is missing).
compute_multi_hospital_opportunity_cost <- function(
  model_parameters,
  rates_table = load_multi_hospital_rates_table()
) {
  medicare_fraction <- get_parameter_value(model_parameters, "denver_health_payer_mix_medicare_fraction")
  medicaid_fraction <- get_parameter_value(model_parameters, "denver_health_payer_mix_medicaid_fraction")
  commercial_fraction <- get_parameter_value(model_parameters, "denver_health_payer_mix_commercial_fraction")

  national_cost <- get_parameter_value(model_parameters, "bariatric_blended_national_cost_ng2023")
  typical_case_minutes <- get_parameter_value(model_parameters, "bariatric_blended_typical_or_minutes")
  added_minutes <- get_parameter_value(model_parameters, "combined_arm_added_minutes")

  rates_table |>
    dplyr::mutate(
      weighted_revenue = .data$medicare_rate * medicare_fraction +
        .data$medicaid_rate * medicaid_fraction +
        .data$commercial_mean_rate * commercial_fraction,
      contribution_margin = .data$weighted_revenue - national_cost,
      opportunity_cost_of_added_minutes = (.data$contribution_margin / typical_case_minutes) * added_minutes
    ) |>
    dplyr::select(
      "state_abbr", "hospital", "medicare_rate", "medicaid_rate", "commercial_mean_rate",
      "weighted_revenue", "contribution_margin", "opportunity_cost_of_added_minutes"
    )
}
