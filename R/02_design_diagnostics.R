source("R/00_common.R")

# Fit propensity scores in the complete-case survey domain.
all <- readRDS("data/derived/design_data.rds")
full <- make_design(subset(all, MEC8YR > 0))
des <- subset(full, complete)
analytic_data <- des$variables
stopifnot(
  nrow(analytic_data) == sum(all$complete),
  length(unique(analytic_data$SDMVSTRA)) == 58
)
ps <- svyglm(
  ps_formula,
  design = des,
  family = quasibinomial(),
  control = glm.control(epsilon = 1e-10, maxit = 100)
)
stopifnot(ps$converged, !anyNA(coef(ps)))
analytic_data$ps <- as.numeric(predict(ps, type = "response"))
cross <- glm(
  ps_formula,
  data = analytic_data,
  weights = MEC8YR / mean(MEC8YR),
  family = quasibinomial(),
  control = glm.control(epsilon = 1e-10, maxit = 100)
)
stopifnot(max(abs(analytic_data$ps - predict(cross, type = "response"))) < 1e-8)

# Check balance for raw covariates, spline terms, and factor levels.
covariate_matrix <- model.matrix(ps)[, -1, drop = FALSE]
covariate_matrix <- cbind(
  age = analytic_data$age,
  bmi = analytic_data$bmi,
  pir = analytic_data$pir,
  covariate_matrix
)
weights <- list(
  Survey = analytic_data$MEC8YR,
  PATE = composite(analytic_data$A, analytic_data$ps, analytic_data$MEC8YR, "PATE"),
  PATO = composite(analytic_data$A, analytic_data$ps, analytic_data$MEC8YR, "PATO")
)
bals <- do.call(rbind, lapply(names(weights), function(method_name) {
  transform(
    balance(covariate_matrix, analytic_data$A, analytic_data$MEC8YR, weights[[method_name]]),
    method = method_name
  )
}))
outcsv(bals, "balance")
print(aggregate(abs(smd) ~ method, bals, max))

# Compare weighted and unweighted propensity-score fits using the same formula.
unw <- glm(ps_formula, data = analytic_data, family = binomial())
pe <- predict(unw, type = "response")
comp <- do.call(rbind, lapply(c("Survey PS", "Unweighted PS"), function(spec) {
  ps_values <- if (spec == "Survey PS") analytic_data$ps else pe
  do.call(rbind, lapply(c("PATE", "PATO"), function(estimand) {
    analysis_weights <- composite(analytic_data$A, ps_values, analytic_data$MEC8YR, estimand)
    data.frame(
      specification = spec,
      estimand = estimand,
      max_abs_smd = max(abs(balance(
        covariate_matrix, analytic_data$A, analytic_data$MEC8YR, analysis_weights
      )$smd)),
      ESS0 = ess(analysis_weights[analytic_data$A == 0]),
      ESS1 = ess(analysis_weights[analytic_data$A == 1])
    )
  }))
}))
outcsv(comp, "ps_specification_comparison")
print(comp)

# Summarize weight dispersion and propensity-score overlap within each group.
quantiles <- list()
for (method_name in names(weights)) {
  for (exposure_level in 0:1) {
    analysis_weights <- weights[[method_name]][analytic_data$A == exposure_level]
    pw <- analysis_weights / analytic_data$MEC8YR[analytic_data$A == exposure_level]
    quantiles[[length(quantiles) + 1]] <- data.frame(
      method = method_name,
      A = exposure_level,
      n = length(analysis_weights),
      ESS = ess(analysis_weights),
      min = min(analysis_weights),
      median = median(analysis_weights),
      p95 = quantile(analysis_weights, .95),
      p99 = quantile(analysis_weights, .99),
      max = max(analysis_weights),
      max_over_mean = max(analysis_weights) / mean(analysis_weights),
      ps_multiplier_p99 = quantile(pw, .99),
      ps_multiplier_max = max(pw)
    )
  }
}
outcsv(do.call(rbind, quantiles), "weight_diagnostics")
outcsv(
  do.call(rbind, lapply(0:1, function(exposure_level) {
    data.frame(
      A = exposure_level,
      t(quantile(
        analytic_data$ps[analytic_data$A == exposure_level],
        c(0, .01, .05, .25, .5, .75, .95, .99, 1)
      ))
    )
  })),
  "ps_quantiles"
)
analytic_data$w_ate <- weights$PATE
analytic_data$w_ato <- weights$PATO

# Use each variable's available observations for its descriptive summary.
describe <- function(sample_data, analysis_weights, label) {
  rows <- list(data.frame(
    population = label,
    variable = "N",
    level = "",
    value = nrow(sample_data),
    available_n = nrow(sample_data),
    available_weight = sum(analysis_weights)
  ))
  for (variable in c("A", covars)) {
    ok <- !is.na(sample_data[[variable]])
    values <- sample_data[[variable]][ok]
    ww <- analysis_weights[ok]
    if (is.factor(values)) {
      for (level_label in levels(values)) {
        rows[[length(rows) + 1]] <- data.frame(
          population = label,
          variable = variable,
          level = level_label,
          value = 100 * wm(as.numeric(values == level_label), ww),
          available_n = sum(ok),
          available_weight = sum(ww)
        )
      }
    } else {
      rows[[length(rows) + 1]] <- data.frame(
        population = label,
        variable = variable,
        level = if (variable == "A") "Prevalence (%)" else "Mean",
        value = wm(values, ww) * ifelse(variable == "A", 100, 1),
        available_n = sum(ok),
        available_weight = sum(ww)
      )
    }
  }
  do.call(rbind, rows)
}
tab1 <- do.call(rbind, lapply(c("All", "A=0", "A=1"), function(level_label) {
  sample_data <- if (level_label == "All") {
    analytic_data
  } else {
    analytic_data[analytic_data$A == as.integer(substr(level_label, 3, 3)), ]
  }
  describe(sample_data, sample_data$MEC8YR, level_label)
}))
outcsv(tab1, "table1_survey")

# Compare included and excluded participants using their available covariates.
eligible_data <- subset(all, design_eligible)
incl <- do.call(rbind, lapply(c(TRUE, FALSE), function(included) {
  sample_data <- eligible_data[eligible_data$complete == included, ]
  describe(sample_data, sample_data$MEC8YR, if (included) "Included" else "Excluded")
}))
outcsv(incl, "included_excluded")

# Give both exposure groups equal weight in the composite population summaries.
pool_weights <- function(analysis_weights, A) {
  analysis_weights / ave(analysis_weights, A, FUN = sum) / 2
}
targets <- rbind(
  describe(analytic_data, analytic_data$MEC8YR, "Original complete-case population"),
  describe(
    analytic_data,
    pool_weights(analytic_data$w_ate, analytic_data$A),
    "PATE composite population"
  ),
  describe(
    analytic_data,
    pool_weights(analytic_data$w_ato, analytic_data$A),
    "PATO composite population"
  ),
  describe(
    analytic_data,
    analytic_data$MEC8YR * analytic_data$ps * (1 - analytic_data$ps),
    "PATO tilting target"
  )
)
outcsv(targets, "target_populations")
outcsv(
  data.frame(
    n = nrow(analytic_data),
    A0 = sum(analytic_data$A == 0),
    A1 = sum(analytic_data$A == 1),
    weighted_prevalence = wm(analytic_data$A, analytic_data$MEC8YR),
    weighted_population = sum(analytic_data$MEC8YR),
    strata = length(unique(analytic_data$SDMVSTRA)),
    PSUs = nrow(unique(analytic_data[c("SDMVSTRA", "SDMVPSU")])),
    df = degf(des),
    complete_fraction = nrow(analytic_data) / nrow(eligible_data)
  ),
  "design_summary"
)

# Plot balance, overlap, and the distribution of weights.
theme_set(theme_minimal(base_size = 12))
cols <- c(Survey = "#7C8A98", PATE = "#2166AC", PATO = "#C75B39")
diagnostic_plot <- ggplot(
  bals, aes(abs(smd), reorder(term, abs(smd), max), color = method)
) +
  geom_point(size = 1.8) +
  geom_vline(xintercept = .1, linetype = 2) +
  scale_color_manual(values = cols) +
  labs(
    x = "Absolute standardized mean difference",
    y = NULL,
    color = NULL,
    title = "Balance in the survey-weighted target population",
    subtitle = "Fixed denominator: pooled within-group SD under MEC weights"
  ) +
  theme(legend.position = "bottom")
ggsave("outputs/figures/love_plot.png", diagnostic_plot, width = 9, height = 9, dpi = 180)
diagnostic_plot <- ggplot(
  analytic_data, aes(ps, weight = MEC8YR / sum(MEC8YR), fill = factor(A))
) +
  geom_histogram(position = "identity", alpha = .5, bins = 35) +
  scale_fill_manual(values = c("#2166AC", "#C75B39"), labels = c("<8 / 30 days", ">=8 / 30 days")) +
  labs(
    x = "Survey-weighted propensity score",
    y = "Weighted fraction of complete-case population",
    fill = "Strength activity",
    title = "Observed propensity-score overlap"
  ) +
  theme(legend.position = "bottom")
ggsave(
  "outputs/figures/propensity_overlap.png", diagnostic_plot,
  width = 8, height = 4.7, dpi = 180
)
long <- do.call(rbind, lapply(names(weights), function(method_name) {
  data.frame(
    method = method_name,
    A = factor(analytic_data$A),
    weight = weights[[method_name]] / mean(weights[[method_name]])
  )
}))
diagnostic_plot <- ggplot(long, aes(A, weight, fill = method)) +
  geom_boxplot(outlier.size = .3) +
  scale_y_log10() +
  facet_wrap(~method) +
  scale_fill_manual(values = cols) +
  labs(
    x = "Exposure (1 = >=8 sessions/30 days)",
    y = "Composite weight / mean (log scale)",
    title = "Weight dispersion"
  ) +
  theme(legend.position = "none")
ggsave(
  "outputs/figures/weight_distribution.png", diagnostic_plot,
  width = 8, height = 4.7, dpi = 180
)

# Save the design objects for the outcome analysis.
saveRDS(
  list(
    data = analytic_data,
    ps = ps,
    X = covariate_matrix,
    formula = ps_formula,
    comparison = comp,
    balance = bals
  ),
  "data/derived/design_objects.rds",
  version = 3
)
capture.output(sessionInfo(), file = "logs/sessionInfo_design.txt")
cat("Design diagnostics completed. No outcomes accessed.\n")
