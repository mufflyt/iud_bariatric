#' Shared test fixtures.
#'
#' testthat::test_dir() changes the working directory to tests/testthat/
#' while tests run, so these fixtures resolve paths against the repo
#' root captured in tests/testthat.R rather than assuming the working
#' directory is the repo root.

repo_root_path <- function() {
  base::getOption("iud_bariatric_repo_root", ".")
}

test_model_parameters <- function() {
  load_model_parameters(base::file.path(repo_root_path(), "config/model_parameters.csv"))
}
