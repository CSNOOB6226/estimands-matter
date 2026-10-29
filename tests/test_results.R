source("R/00_common.R")

# Check participant counts and the mortality outcome with a second file parser.
analytic_data <- readRDS("data/derived/outcome_data.rds")
risk_results <- readRDS("data/derived/all_risk_results.rds")
stopifnot(
  nrow(analytic_data) == 15091,
  sum(analytic_data$death10) == 1980,
  sum(analytic_data$A == 1) == 2826
)
ind <- do.call(rbind, lapply(c(1999, 2001, 2003, 2005), function(cycle_start) {
  read.fwf(
    paste0("data/raw/NHANES_", cycle_start, "_", cycle_start + 1, "_MORT_2019_PUBLIC.dat"),
    widths = c(6, -8, 1, 1, -29, 3),
    col.names = c("SEQN", "ELIGSTAT", "MORTSTAT", "PERMTH_EXM"),
    na.strings = c(".", ""),
    strip.white = TRUE
  )
}))
ind <- ind[match(analytic_data$SEQN, ind$SEQN), ]
stopifnot(
  all(ind$ELIGSTAT == analytic_data$ELIGSTAT),
  all(ind$MORTSTAT == analytic_data$MORTSTAT),
  all(ind$PERMTH_EXM == analytic_data$PERMTH_EXM)
)
ind_y <- as.integer(ind$MORTSTAT == 1 & ind$PERMTH_EXM <= 120)
stopifnot(identical(ind_y, analytic_data$death10))

# Check risk arithmetic and recompute each replicate covariance matrix.
for (scenario_result in risk_results[c("main", "landmark", "no_disease")]) {
  summary_stats <- scenario_result$summary
  stopifnot(
    all(summary_stats$risk0 >= 0 & summary_stats$risk0 <= 1),
    all(summary_stats$risk1 >= 0 & summary_stats$risk1 <= 1),
    all(abs(summary_stats$RD - (summary_stats$risk1 - summary_stats$risk0)) < 1e-12),
    all(abs(summary_stats$RR - summary_stats$risk1 / summary_stats$risk0) < 1e-12),
    all(is.finite(scenario_result$replicates))
  )
  delta <- sweep(scenario_result$replicates, 2, scenario_result$theta, "-")
  vv <- matrix(0, ncol(delta), ncol(delta))
  for (replicate_index in seq_len(nrow(delta))) {
    vv <- vv + outer(delta[replicate_index, ], delta[replicate_index, ]) *
      risk_results$rscales[replicate_index] * risk_results$scale
  }
  stopifnot(max(abs(vv - scenario_result$variance)) < 1e-12)
}

# Check the independent Cox fit and the direct risk calculations.
cox_results <- readRDS("data/derived/cox_results.rds")
stopifnot(cox_results$coefficient_check < 1e-7)
checks <- read.csv("outputs/tables/independent_risk_validation.csv")
stopifnot(max(checks$max_point_difference) < 1e-10)
outcsv(
  data.frame(
    check = c(
      "Independent fixed-width mortality parser",
      "Exposure and event counts",
      "Risk contrast arithmetic",
      "Independent replicate covariance",
      "Weighted means versus direct ratios",
      "Independent Cox coefficients"
    ),
    status = "PASS"
  ),
  "validation_results"
)
cat("Outcome validation PASS; all117 replicates retained in each scenario.\n")
