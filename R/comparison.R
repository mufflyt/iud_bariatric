#' Strategy comparison
#'
#' @param strategy_costs Tibble from [compute_strategy_costs()].
#' @return `strategy_costs` with an added `incremental_cost_vs_standalone`
#'   column and a `is_cheaper` flag.
compare_combined_vs_standalone <- function(strategy_costs) {
  standalone_cost <- strategy_costs$expected_total_cost[
    strategy_costs$strategy == "standalone"
  ]

  strategy_costs |>
    dplyr::mutate(
      incremental_cost_vs_standalone = .data$expected_total_cost - standalone_cost,
      is_cheaper = .data$expected_total_cost < standalone_cost
    )
}
