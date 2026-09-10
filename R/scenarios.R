#' Scenario analysis
#'
#' Named payer/policy scenarios expressed as parameter overrides, applied
#' via [override_model_parameters()], mirroring the sibling
#' `emb_colonoscopy` project's scenario-analysis pattern. Medicare is not a
#' realistic scenario here (see README/docs/data_sources.md: Medicare
#' statutorily excludes contraceptive devices), so unlike the sibling
#' project's Medicare-anchored base case with Medicaid/commercial
#' variants, this project's base case is already a non-Medicare
#' (self-pay-chargemaster/GPO-acquisition-cost) anchor, and Medicaid is
#' the more clinically realistic alternative to explore, not a discount
#' off of Medicare.

#' Named scenario definitions
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param price_index_table Tibble from [load_price_index_table()], used
#'   to inflation-adjust the Medicaid scenario's 2015-dollar national
#'   estimate.
#' @param reference_year Numeric scalar target year for that adjustment.
#' @return A named list of override lists, one per scenario.
build_scenario_definitions <- function(
  model_parameters,
  price_index_table = load_price_index_table("data/cpi_medical_care.csv"),
  reference_year = get_parameter_value(model_parameters, "reference_dollar_year")
) {
  # National 2015 Medicaid-context estimate for the insertion professional
  # fee: $71-$135 (midpoint $103), from the systematic review of state
  # postpartum-LARC reimbursement policies (see docs/data_sources.md,
  # "Medicaid payer scenario" section, for the full citation and why a
  # Colorado-specific CPT 58300 rate could not be found despite directly
  # downloading and searching Colorado's own April 2026 Medicaid physician
  # fee schedule).
  medicaid_professional_fee_national_2015 <- 103
  medicaid_professional_fee_inflated <- adjust_for_inflation(
    medicaid_professional_fee_national_2015, 2015, reference_year, price_index_table
  )

  list(
    base_case = list(
      overrides = list(),
      description = "Base case: office-visit and insertion professional fees at their existing (self-pay-chargemaster-derived and CMS-PUF-reused) sourcing; device priced at the non-340B GPO acquisition cost.",
      provisional = FALSE
    ),
    medicaid_illustrative = list(
      overrides = list(
        office_visit_em_cost = 77.39,
        iud_insertion_professional_fee = medicaid_professional_fee_inflated,
        combined_requires_separate_professional_fee = "TRUE"
      ),
      description = base::paste0(
        "Medicaid payer scenario. office_visit_em_cost = $77.39 is Colorado's ",
        "REAL, currently-effective Health First Colorado Medicaid Family ",
        "Planning professional-component rate for CPT 99213 (directly ",
        "confirmed 2026-09-11 from Colorado HCPF's own April 2026 physician ",
        "fee schedule PDF). iud_insertion_professional_fee = $",
        base::round(medicaid_professional_fee_inflated, 2), " is NOT Colorado-specific -- ",
        "Colorado's own fee schedule was searched directly and does not list ",
        "CPT 58300 at all (it may live in a different Family Planning/OB ",
        "billing manual not yet located); this uses a national 2015 Medicaid-",
        "context estimate ($71-$135, midpoint $103) inflation-adjusted to ",
        "the reference year instead. combined_requires_separate_professional_fee ",
        "is set TRUE as a POLICY-ANALOGY assumption, not current law: Colorado ",
        "Medicaid has a REAL separate-payment carve-out for LARC devices ",
        "inserted during an otherwise-DRG-bundled inpatient stay (effective ",
        "2020-01-01, paid at 'the fee schedule rate or the amount billed, ",
        "whichever is less', funded by a 0.004 reduction to delivery DRG ",
        "weights 540/542/560), but that carve-out is scoped to delivery/",
        "postpartum admissions specifically, NOT bariatric surgery. This ",
        "scenario asks what the combined arm would cost IF an equivalent ",
        "carve-out were extended to bariatric-surgery DRGs. The device's own ",
        "GPO acquisition cost is left unchanged in both scenarios: which ",
        "payer eventually reimburses a claim does not change what the ",
        "hospital pays its supplier to acquire the device in the first place."
      ),
      provisional = TRUE
    )
  )
}

#' Run the strategy-cost model under every named scenario
#'
#' @param model_parameters Tibble from [load_model_parameters()].
#' @param price_index_table Tibble from [load_price_index_table()].
#' @param all_items_price_index_table Tibble from [load_price_index_table()]
#'   pointed at `data/cpi_all_items.csv`.
#' @return A tibble binding `strategy_costs` for every scenario, with a
#'   leading `scenario` column and the scenario's `provisional` flag.
run_scenario_analysis <- function(
  model_parameters,
  price_index_table = load_price_index_table("data/cpi_medical_care.csv"),
  all_items_price_index_table = load_price_index_table("data/cpi_all_items.csv")
) {
  scenario_definitions <- build_scenario_definitions(model_parameters, price_index_table)

  base::message("Running ", base::length(scenario_definitions), " scenario(s).")

  scenario_rows <- purrr::imap(scenario_definitions, function(scenario_definition, scenario_name) {
    base::message(
      "  Scenario: ", scenario_name,
      if (base::isTRUE(scenario_definition$provisional)) " [PROVISIONAL]" else ""
    )

    scenario_parameters <- override_model_parameters(
      model_parameters, scenario_definition$overrides
    )
    strategy_costs <- compute_strategy_costs(
      scenario_parameters, price_index_table, all_items_price_index_table
    )

    strategy_costs |>
      dplyr::mutate(
        scenario = scenario_name,
        scenario_description = scenario_definition$description,
        scenario_provisional = scenario_definition$provisional
      ) |>
      dplyr::select("scenario", dplyr::everything())
  })

  dplyr::bind_rows(scenario_rows)
}
