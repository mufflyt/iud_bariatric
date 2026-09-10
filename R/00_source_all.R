#' Source every R/ function file
#'
#' Run from the repository root before using any model function:
#'   base::source("R/00_source_all.R")

r_files <- base::list.files("R", pattern = "\\.R$", full.names = TRUE)
r_files <- r_files[r_files != "R/00_source_all.R"]

for (r_file in r_files) {
  base::source(r_file)
}

base::message("All R/ function files sourced (", base::length(r_files), " files).")
