source("R/00_common.R")

# Check hand-calculated weights and the scaling of survey weights.
stopifnot(isTRUE(all.equal(composite(c(1, 0), c(.2, .8), c(10, 20), "PATE"), c(50, 100))))
stopifnot(isTRUE(all.equal(composite(c(1, 0), c(.2, .8), c(10, 20), "PATO"), c(8, 16))))
stopifnot(all.equal(c(200, 400) / 2, c(100, 200)), all.equal(c(200, 400) / 4, c(50, 100)))

# Check deaths and censoring at the ten-year boundary.
stopifnot(identical(
  death_at_120(c(1, 1, 1, 0, 0, 1), c(0, 120, 121, 120, 119, NA)),
  c(1L, 1L, 0L, 0L, NA_integer_, NA_integer_)
))

# Confirm that the design sample meets each eligibility rule and has no outcomes.
design_objects <- readRDS("data/derived/design_objects.rds")
analytic_data <- design_objects$data
stopifnot(
  !anyDuplicated(analytic_data$SEQN),
  all(analytic_data$A %in% 0:1),
  all(analytic_data$ELIGSTAT == 1),
  all(analytic_data$age >= 20),
  !anyNA(analytic_data[, covars]),
  all(analytic_data$MEC8YR > 0)
)
stopifnot(!any(grepl("mort|death|permth", names(analytic_data), ignore.case = TRUE)))

# Check covariate balance for both target populations.
stopifnot(
  max(abs(subset(design_objects$balance, method == "PATE")$smd)) < .1,
  max(abs(subset(design_objects$balance, method == "PATO")$smd)) < 1e-7
)

# Use the weighted logistic score equations to check exact mean balance.
covariate_matrix <- model.matrix(design_objects$ps)
stopifnot(max(abs(
  colSums(covariate_matrix * (analytic_data$MEC8YR * (analytic_data$A - analytic_data$ps))) /
    sum(analytic_data$MEC8YR)
)) < 1e-7)
stopifnot(sum(analytic_data$A == 0) + sum(analytic_data$A == 1) == nrow(analytic_data))
cat(paste0(
  "Design checks PASS: hand weights, boundaries, unique joins, eligibility, ",
  "no outcomes, balance and logistic score equations.\n"
))
