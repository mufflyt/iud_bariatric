#' Save a table to the `tables/` directory
#'
#' @param table_data A data frame/tibble.
#' @param file_name Character scalar, e.g. `"strategy_comparison.csv"`.
#' @param output_dir Character scalar destination directory.
#' @return Invisibly, the full output path.
save_table <- function(table_data, file_name, output_dir = "tables") {
  if (!base::dir.exists(output_dir)) {
    base::message("Creating output directory: ", output_dir)
    base::dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  output_path <- base::file.path(output_dir, file_name)
  readr::write_csv(table_data, output_path)
  base::message("Saved table to: ", output_path)

  base::invisible(output_path)
}
