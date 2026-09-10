test_that("adjust_for_inflation returns cost unchanged when years match", {
  price_index_table <- test_price_index_table()
  expect_equal(
    adjust_for_inflation(100, 2026, 2026, price_index_table),
    100
  )
})

test_that("adjust_for_inflation scales cost by the index ratio", {
  price_index_table <- tibble::tibble(
    year = c(2010, 2020),
    index_value = c(100, 150)
  )
  expect_equal(
    adjust_for_inflation(200, 2010, 2020, price_index_table),
    300
  )
})

test_that("adjust_for_inflation errors on an unmatched year", {
  price_index_table <- test_price_index_table()
  expect_error(
    adjust_for_inflation(100, 1999, 2026, price_index_table),
    "no unique index_value"
  )
})

test_that("load_price_index_table reads all required columns", {
  price_index_table <- test_price_index_table()
  expect_true(all(c("year", "index_value", "index_source", "is_placeholder") %in% names(price_index_table)))
})

test_that("this project's CPI tables carry no placeholder rows, unlike the sibling project's", {
  # Regression guard: the sibling emb_colonoscopy project's data/cpi_medical_care.csv
  # ships a flagged placeholder 2014 row (interpolated, not a real BLS value).
  # This project's copy was deliberately rebuilt with a real 2014 value
  # (FRED CUUS0000SAM Jan/Jul average) -- if this ever regresses to a
  # placeholder, that's worth knowing.
  price_index_table <- test_price_index_table()
  all_items_price_index_table <- test_all_items_price_index_table()
  expect_false(any(price_index_table$is_placeholder))
  expect_false(any(all_items_price_index_table$is_placeholder))
})

test_that("no adjacent pair of index years implies an implausible multi-year inflation multiplier", {
  # Same regression guard as the sibling project's test-inflation.R: catches
  # a disconnected/synthetic index value silently producing an implausible
  # inflation multiplier.
  for (tbl in list(test_price_index_table(), test_all_items_price_index_table())) {
    tbl <- tbl[order(tbl$year), ]
    for (i in seq_len(nrow(tbl) - 1)) {
      year_gap <- tbl$year[[i + 1]] - tbl$year[[i]]
      ratio <- tbl$index_value[[i + 1]] / tbl$index_value[[i]]
      max_plausible_ratio <- 1.15^year_gap
      expect_true(
        ratio < max_plausible_ratio,
        info = base::sprintf(
          "Index ratio %s -> %s implies > 15%%/year inflation (ratio = %.3f over %d years)",
          tbl$year[[i]], tbl$year[[i + 1]], ratio, year_gap
        )
      )
    }
  }
})

test_that("adjust_for_inflation errors rather than dividing by a zero or negative index_value", {
  bad_price_index_table <- tibble::tibble(year = c(2010, 2020), index_value = c(100, 0))
  expect_error(
    adjust_for_inflation(100, 2010, 2020, bad_price_index_table),
    "non-positive or non-finite"
  )
})

test_that("adjust_for_inflation rejects a negative cost_value", {
  price_index_table <- test_price_index_table()
  expect_error(
    adjust_for_inflation(-5, 2010, 2026, price_index_table),
    "non-negative"
  )
})
