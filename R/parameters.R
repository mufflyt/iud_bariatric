#' Model parameter loading and access
#'
#' Conventions mirror the sibling `emb_colonoscopy` project: every parameter
#' lives in `config/model_parameters.csv` with a source citation, an
#' evidence tier (A = direct/primary source, B = adjacent primary source or
#' reused verified extraction, C = general-population/secondary-source
#' literature, D = placeholder pending verification), and a `provisional`
#' flag. Check that file, not code comments, for what is real vs. assumed.

#' Load and validate the model parameter table
#'
#' @param path Character scalar path to the parameter CSV.
#' @return A tibble with one row per parameter.
load_model_parameters <- function(path = "config/model_parameters.csv") {
  if (!base::file.exists(path)) {
    base::stop("Model parameter file not found: ", path)
  }

  model_parameters <- readr::read_csv(
    path,
    col_types = readr::cols(
      parameter = readr::col_character(),
      category = readr::col_character(),
      strategy = readr::col_character(),
      description = readr::col_character(),
      base_value = readr::col_character(),
      unit = readr::col_character(),
      low_value = readr::col_double(),
      high_value = readr::col_double(),
      distribution = readr::col_character(),
      dollar_year = readr::col_double(),
      source = readr::col_character(),
      provisional = readr::col_logical(),
      notes = readr::col_character(),
      gamma_alpha = readr::col_double(),
      gamma_rate = readr::col_double(),
      evidence_tier = readr::col_character()
    )
  )

  duplicate_names <- model_parameters |>
    dplyr::count(.data$parameter, name = "n") |>
    dplyr::filter(.data$n > 1)
  if (base::nrow(duplicate_names) > 0) {
    base::stop(
      "Duplicate parameter name(s): ",
      base::paste(duplicate_names$parameter, collapse = ", ")
    )
  }

  model_parameters
}

#' Pull one parameter's numeric base value
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param parameter_name Character scalar.
#' @return Numeric scalar.
get_parameter_value <- function(model_parameters, parameter_name) {
  row <- model_parameters |>
    dplyr::filter(.data$parameter == .env$parameter_name)

  if (base::nrow(row) != 1) {
    base::stop("Expected exactly one parameter row for: ", parameter_name)
  }

  base::as.numeric(row$base_value[[1]])
}

#' Pull one parameter's raw (possibly non-numeric) base value
#'
#' Used for boolean/structural parameters like
#' `combined_requires_separate_professional_fee`.
#'
#' @inheritParams get_parameter_value
#' @return Character scalar.
get_parameter_raw_value <- function(model_parameters, parameter_name) {
  row <- model_parameters |>
    dplyr::filter(.data$parameter == .env$parameter_name)

  if (base::nrow(row) != 1) {
    base::stop("Expected exactly one parameter row for: ", parameter_name)
  }

  row$base_value[[1]]
}

#' Override one or more parameters' base values (for scenario analysis)
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param overrides Named list of new base values.
#' @return `model_parameters` with the named rows' `base_value` replaced.
override_model_parameters <- function(model_parameters, overrides) {
  if (base::length(overrides) == 0) {
    return(model_parameters)
  }

  unknown_names <- base::setdiff(base::names(overrides), model_parameters$parameter)
  if (base::length(unknown_names) > 0) {
    base::stop(
      "override_model_parameters() received unknown parameter name(s): ",
      base::paste(unknown_names, collapse = ", ")
    )
  }

  updated_parameters <- model_parameters
  for (parameter_name in base::names(overrides)) {
    row_index <- base::which(updated_parameters$parameter == parameter_name)
    updated_parameters$base_value[[row_index]] <- base::as.character(
      overrides[[parameter_name]]
    )
  }

  updated_parameters
}
