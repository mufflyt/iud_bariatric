#' Probabilistic sensitivity analysis (Monte Carlo)
#'
#' A different question from `run_one_way_sensitivity()`'s tornado
#' diagram: not "which single parameter moves the gap most if swept
#' alone, holding everything else at base case," but "given every
#' uncertain parameter varying at once, how uncertain is the headline
#' incremental-cost gap itself, and how often does it even flip sign
#' (i.e. which strategy looks cheaper)?"
#'
#' Reuses `SENSITIVITY_PARAMETER_NAMES` (`R/sensitivity_deterministic.R`)
#' unchanged: the same ten parameters already vetted there as (a)
#' actually consumed by the cost engine and (b) carrying a real, sourced
#' low_value/high_value range. Nothing new is swept here that wasn't
#' already swept one-way; this just samples all ten jointly instead of
#' one at a time.
#'
#' Distribution family comes from each parameter's own `distribution`
#' column in `config/model_parameters.csv` -- present since this
#' project's parameter schema was written, but unused by any code until
#' now:
#' - `triangular`: sampled directly from (low_value, base_value,
#'   high_value) via the standard inverse-CDF triangular formula.
#' - `gamma`: fit by the method-of-moments technique standard in
#'   health-economic PSA modeling (Briggs A, Claxton K, Sculpher M.
#'   "Decision Modelling for Health Economic Evaluation." Oxford
#'   University Press; 2006, ch. 4): `base_value` is treated as the
#'   mean, `(high_value - low_value) / (2 * 1.96)` as the standard error
#'   implied by a 95% CI, then `rate = mean / SE^2`,
#'   `shape = mean * rate`. This keeps the fitted gamma's own mean
#'   exactly equal to `base_value`, so the PSA's average draw should
#'   land close to the deterministic base case -- a useful sanity check,
#'   not just a modeling nicety.
#' - Anything else (in practice, `fixed`): held at `base_value` in every
#'   draw, no variation. Two of the ten parameters
#'   (`iud_expulsion_probability_combined`, `iud_perforation_risk_baseline`)
#'   fall here: both carry a real low_value/high_value range (used by
#'   the one-way sweep above) but are tagged `fixed` rather than given a
#'   distribution family. That tag is respected as written, not
#'   silently reinterpreted -- a bounded probability would naturally
#'   take a beta distribution instead, but assigning one is a real
#'   methodological decision this file does not make unasked. A future
#'   revision could add it by changing the CSV tag; until then these two
#'   parameters are correctly reported as NOT varied here, matching what
#'   the CSV itself says.
#'
#' Not varied at all: `cancer_prevention_parameters`, and therefore
#' `expected_missed_cancer_prevention_cost`. This PSA is scoped to
#' `expected_total_cost`'s `incremental_cost_vs_standalone` -- the exact
#' "headline result" `run_one_way_sensitivity()` already targets -- which
#' does not consume `cancer_prevention_parameters` at all (see
#' `R/strategy_costs.R`: `expected_total_cost` never includes
#' `expected_missed_cancer_prevention_cost`, only
#' `expected_cost_per_referred_patient` does). Extending this PSA to that
#' second metric would require sourced low/high ranges for
#' `endometrial_cancer_lifetime_risk_usual_care_bmi40`,
#' `endometrial_cancer_death_risk_usual_care_bmi40`, and
#' `endometrial_cancer_treatment_cost`, none of which currently exist --
#' not done here rather than inventing plausible-looking ranges.

#' Sample from a triangular distribution
#'
#' Standard inverse-CDF (inverse-transform) formula for the triangular
#' distribution.
#'
#' @param n Integer scalar, number of draws.
#' @param low,mode,high Numeric scalars, the distribution's min, mode, max.
#' @return Numeric vector of length `n`.
sample_triangular <- function(n, low, mode, high) {
  u <- stats::runif(n)
  fraction_below_mode <- (mode - low) / (high - low)

  base::ifelse(
    u < fraction_below_mode,
    low + base::sqrt(u * (high - low) * (mode - low)),
    high - base::sqrt((1 - u) * (high - low) * (high - mode))
  )
}

#' Fit a gamma distribution's shape/rate by method of moments
#'
#' @param mean Numeric scalar, the distribution's target mean.
#' @param low,high Numeric scalars, treated as a 95% CI's bounds; the
#'   implied standard error is `(high - low) / (2 * 1.96)`.
#' @return A list with `shape` and `rate`.
fit_gamma_moments <- function(mean, low, high) {
  standard_error <- (high - low) / (2 * 1.96)
  rate <- mean / standard_error^2
  shape <- mean * rate

  base::list(shape = shape, rate = rate)
}

#' Sample from a gamma distribution fit to a mean and a 95% CI
#'
#' @param n Integer scalar, number of draws.
#' @inheritParams fit_gamma_moments
#' @return Numeric vector of length `n`.
sample_gamma_from_ci <- function(n, mean, low, high) {
  fitted <- fit_gamma_moments(mean, low, high)
  stats::rgamma(n, shape = fitted$shape, rate = fitted$rate)
}

#' Draw `n` Monte Carlo samples for one parameter row
#'
#' Dispatches on the row's own `distribution` column; see this file's
#' top-of-file docstring for the full rationale.
#'
#' @param n Integer scalar, number of draws.
#' @param parameter_row A one-row tibble slice from
#'   [load_model_parameters()] (i.e. `model_parameters |>
#'   dplyr::filter(parameter == "...")`).
#' @return Numeric vector of length `n`.
sample_parameter_draws <- function(n, parameter_row) {
  distribution <- parameter_row$distribution[[1]]
  base_value <- base::as.numeric(parameter_row$base_value[[1]])
  low_value <- parameter_row$low_value[[1]]
  high_value <- parameter_row$high_value[[1]]

  if (distribution == "triangular") {
    return(sample_triangular(n, low_value, base_value, high_value))
  }
  if (distribution == "gamma") {
    return(sample_gamma_from_ci(n, base_value, low_value, high_value))
  }

  base::rep(base_value, n)
}

#' Run a probabilistic (Monte Carlo) sensitivity analysis
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param price_index_table Tibble from [load_price_index_table()].
#' @param all_items_price_index_table Tibble from [load_price_index_table()]
#'   pointed at `data/cpi_all_items.csv`.
#' @param cancer_prevention_parameters Tibble from
#'   [load_model_parameters()] pointed at
#'   `config/cancer_prevention_parameters.csv`. Held fixed at base
#'   values throughout (see top-of-file docstring); accepted as a
#'   parameter only so [compute_incremental_gap()] can be called.
#' @param n_draws Integer scalar, number of Monte Carlo draws.
#' @param seed Integer scalar, random seed (for reproducibility).
#' @return A list with two elements: `draws` (a tibble, one row per
#'   draw, one column per varied parameter plus
#'   `incremental_cost_vs_standalone`), and `summary` (a one-row tibble:
#'   `n_draws`, `mean_gap`, `median_gap`, `sd_gap`, `ci_low`, `ci_high`,
#'   `probability_standalone_cheaper` -- the fraction of draws where the
#'   combined arm costs more than standalone, i.e. `gap > 0`).
run_probabilistic_sensitivity_analysis <- function(
  model_parameters,
  price_index_table,
  all_items_price_index_table,
  cancer_prevention_parameters = load_model_parameters("config/cancer_prevention_parameters.csv"),
  n_draws = 10000,
  seed = 20260911
) {
  base::set.seed(seed)

  parameter_rows <- purrr::map(SENSITIVITY_PARAMETER_NAMES, function(parameter_name) {
    row <- model_parameters |> dplyr::filter(.data$parameter == .env$parameter_name)
    if (base::nrow(row) != 1) {
      base::stop("Expected exactly one parameter row for: ", parameter_name)
    }
    row
  })
  base::names(parameter_rows) <- SENSITIVITY_PARAMETER_NAMES

  draws_by_parameter <- purrr::map(parameter_rows, function(row) sample_parameter_draws(n_draws, row))

  gaps <- base::numeric(n_draws)
  for (draw_index in base::seq_len(n_draws)) {
    overrides <- purrr::map(draws_by_parameter, function(draws) draws[[draw_index]])
    draw_parameters <- override_model_parameters(model_parameters, overrides)
    gaps[[draw_index]] <- compute_incremental_gap(
      draw_parameters, price_index_table, all_items_price_index_table, cancer_prevention_parameters
    )
  }

  draws_tibble <- tibble::as_tibble(draws_by_parameter)
  draws_tibble$incremental_cost_vs_standalone <- gaps

  ci <- stats::quantile(gaps, c(0.025, 0.975))

  summary_tibble <- tibble::tibble(
    n_draws = n_draws,
    mean_gap = base::mean(gaps),
    median_gap = stats::median(gaps),
    sd_gap = stats::sd(gaps),
    ci_low = ci[[1]],
    ci_high = ci[[2]],
    probability_standalone_cheaper = base::mean(gaps > 0)
  )

  base::list(draws = draws_tibble, summary = summary_tibble)
}
