# Load the packages used across the analysis scripts.
suppressPackageStartupMessages({
  library(survey)
  library(foreign)
  library(splines)
  library(ggplot2)
})
options(survey.lonely.psu = "fail", survey.adjust.domain.lonely = FALSE, warn = 1)
set.seed(20260923)

# Write tables with the same CSV settings throughout.
outcsv <- function(table_data, name) {
  write.csv(
    table_data,
    file.path("outputs/tables", paste0(name, ".csv")),
    row.names = FALSE,
    na = ""
  )
}

# Use the same adjustment variables in each model.
covars <- c(
  "age", "sex", "race", "education", "pir", "smoking", "alcohol", "bmi",
  "aerobic", "health", "diabetes", "hypertension", "cvd", "cancer", "cycle"
)
ps_formula <- A ~ ns(age, df = 4) + sex + race + education + ns(pir, df = 3) +
  smoking + alcohol + ns(bmi, df = 3) + aerobic + health + diabetes +
  hypertension + cvd + cancer + cycle

# Summarize weighted values and the effective sample size.
wm <- function(values, weights) sum(values * weights) / sum(weights)
ess <- function(weights) sum(weights)^2 / sum(weights^2)

# Count deaths through month 120 and require enough follow-up for survivors.
death_at_120 <- function(status, months) {
  stopifnot(length(status) == length(months))
  ifelse(
    status == 1 & !is.na(months) & months >= 0 & months <= 120,
    1L,
    ifelse(status %in% c(0, 1) & !is.na(months) & months >= 120, 0L, NA_integer_)
  )
}

# Combine survey weights with the weights for each target population.
composite <- function(exposure, ps, survey_weights, type) {
  stopifnot(all(ps > 0 & ps < 1), all(survey_weights >= 0))
  if (type == "PATE") {
    survey_weights * ifelse(exposure == 1, 1 / ps, 1 / (1 - ps))
  } else if (type == "PATO") {
    survey_weights * ifelse(exposure == 1, 1 - ps, ps)
  } else {
    survey_weights
  }
}

# Keep the NHANES strata and PSUs when creating a survey design.
make_design <- function(analytic_data) {
  svydesign(
    ids = ~SDMVPSU,
    strata = ~SDMVSTRA,
    weights = ~MEC8YR,
    data = analytic_data,
    nest = TRUE
  )
}

# Compare weighted group means using the original pooled standard deviation.
balance <- function(covariate_matrix, exposure, survey_weights, weights) {
  sd0 <- sqrt(apply(covariate_matrix, 2, function(values) {
    (
      wm(
        (values[exposure == 1] - wm(values[exposure == 1], survey_weights[exposure == 1]))^2,
        survey_weights[exposure == 1]
      ) +
        wm(
          (values[exposure == 0] - wm(values[exposure == 0], survey_weights[exposure == 0]))^2,
          survey_weights[exposure == 0]
        )
    ) / 2
  }))
  difference <- apply(covariate_matrix, 2, function(values) {
    wm(values[exposure == 1], weights[exposure == 1]) -
      wm(values[exposure == 0], weights[exposure == 0])
  })
  data.frame(
    term = colnames(covariate_matrix),
    smd = ifelse(sd0 > 0, difference / sd0, 0)
  )
}
