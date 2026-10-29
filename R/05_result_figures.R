source("R/00_common.R")

# Load the main and sensitivity results for the forest plots.
risk_results <- readRDS("data/derived/all_risk_results.rds")
main_results <- risk_results$main$summary
sensitivity_results <- rbind(risk_results$landmark$summary, risk_results$no_disease$summary)
theme_set(theme_minimal(base_size = 12))
forest <- rbind(main_results[, names(sensitivity_results)], sensitivity_results)
forest$label <- paste(forest$scenario, forest$method, sep = " | ")

# Plot the risk differences across target populations and sensitivity analyses.
plot <- ggplot(forest, aes(RD * 100, reorder(label, seq_along(label)))) +
  geom_vline(xintercept = 0, color = "#8995A0", linetype = 2) +
  geom_errorbar(
    aes(xmin = RD_low * 100, xmax = RD_high * 100),
    orientation = "y", width = .15, color = "#2166AC"
  ) +
  geom_point(size = 2.4, color = "#2166AC") +
  labs(
    x = "Risk difference, percentage points (95% CI)",
    y = NULL,
    title = "Marginal mortality associations by target population",
    subtitle = "Contrast: >=8 minus <8 strength sessions/30 days; JKn uncertainty",
    caption = paste0(
      "Landmark: risk during months24–120 among survivors to month24. ",
      "Capped PATE is a robustness check."
    )
  )
ggsave("outputs/figures/risk_difference_forest.png", plot, width = 10.5, height = 6.4, dpi = 180)

# Plot risk ratios on a log scale.
plot <- ggplot(forest, aes(RR, reorder(label, seq_along(label)))) +
  geom_vline(xintercept = 1, color = "#8995A0", linetype = 2) +
  geom_errorbar(
    aes(xmin = RR_low, xmax = RR_high),
    orientation = "y", width = .15, color = "#C75B39"
  ) +
  geom_point(size = 2.4, color = "#C75B39") +
  scale_x_log10() +
  labs(
    x = "Risk ratio (95% CI, log scale)",
    y = NULL,
    title = "Relative associations across analyses",
    caption = "JKn re-estimates the propensity model in every replicate."
  )
ggsave("outputs/figures/risk_ratio_forest.png", plot, width = 10.5, height = 6.4, dpi = 180)

# Compare absolute mortality risks in the two exposure groups.
risks <- rbind(
  data.frame(
    method = main_results$method,
    A = "<8",
    risk = main_results$risk0,
    low = main_results$risk0_low,
    high = main_results$risk0_high
  ),
  data.frame(
    method = main_results$method,
    A = ">=8",
    risk = main_results$risk1,
    low = main_results$risk1_low,
    high = main_results$risk1_high
  )
)
plot <- ggplot(risks, aes(method, risk * 100, color = A)) +
  geom_point(position = position_dodge(.4), size = 2.5) +
  geom_errorbar(
    aes(ymin = low * 100, ymax = high * 100),
    position = position_dodge(.4), width = .15
  ) +
  scale_color_manual(values = c("#2166AC", "#C75B39")) +
  labs(
    x = NULL,
    y = "10-year mortality risk (%)",
    color = "Sessions /30 days",
    title = "Absolute risks depend on adjustment and target"
  ) +
  theme(legend.position = "bottom")
ggsave("outputs/figures/marginal_risks.png", plot, width = 9, height = 5, dpi = 180)

# Draw the participant counts and exclusions at each selection step.
flow <- read.csv("outputs/tables/participant_flow_design.csv")
png("outputs/figures/participant_flow.png", width = 1300, height = 1450, res = 180)
par(mar = c(0, 0, 2, 0))
plot.new()
plot.window(xlim = c(0, 1), ylim = c(0, 1))
title("Participant selection: NHANES 1999–2006", cex.main = 1)
row_positions <- seq(.87, .12, length.out = nrow(flow))
for (row_index in seq_len(nrow(flow))) {
  rect(
    .1, row_positions[row_index] - .045, .9, row_positions[row_index] + .045,
    col = "#EDF3F8", border = "#2166AC"
  )
  text(
    .5, row_positions[row_index],
    paste0(flow$stage[row_index], "\nn = ", format(flow$n[row_index], big.mark = ",")),
    cex = .85
  )
  if (row_index < nrow(flow)) {
    arrows(
      .5, row_positions[row_index] - .047, .5, row_positions[row_index + 1] + .047,
      length = .08
    )
    text(
      .7, (row_positions[row_index] + row_positions[row_index + 1]) / 2,
      paste("Excluded:", format(flow$excluded_since_previous[row_index + 1], big.mark = ",")),
      cex = .7
    )
  }
}
text(
  .5, .02,
  "All complete cases had an ascertainable 120-month outcome; no additional outcome exclusions.",
  cex = .7
)
dev.off()

# Summarize balance by the largest absolute SMD within each covariate.
design_objects <- readRDS("data/derived/design_objects.rds")
balance_data <- design_objects$balance
group_term <- function(term) {
  for (variable in c("age", "bmi", "pir")) {
    if (term == variable || grepl(paste0("ns(", variable, ","), term, fixed = TRUE)) {
      return(variable)
    }
  }
  for (variable in covars) {
    if (startsWith(term, variable)) {
      return(variable)
    }
  }
  term
}
balance_data$variable <- vapply(balance_data$term, group_term, character(1))
balance_data$absolute_smd <- abs(balance_data$smd)
balance_summary <- aggregate(absolute_smd ~ method + variable, balance_data, max)
outcsv(balance_summary, "balance_by_variable")
plot <- ggplot(
  balance_summary,
  aes(absolute_smd, reorder(variable, absolute_smd, max), color = method)
) +
  geom_point(size = 2.2) +
  geom_vline(xintercept = .1, linetype = 2, color = "#777777") +
  scale_color_manual(values = c(Survey = "#7C8A98", PATE = "#2166AC", PATO = "#C75B39")) +
  labs(
    x = "Maximum absolute SMD within covariate",
    y = NULL,
    color = NULL,
    title = "Balance after targeting the population"
  ) +
  theme(legend.position = "bottom")
ggsave("outputs/figures/love_plot_summary.png", plot, width = 7.8, height = 4.5, dpi = 200)

# Show propensity-score overlap before weighting.
analytic_data <- design_objects$data
plot <- ggplot(
  analytic_data,
  aes(ps, weight = MEC8YR, color = factor(A), fill = factor(A))
) +
  geom_density(alpha = .15, linewidth = .8, bounds = c(0, 1)) +
  scale_color_manual(values = c("#2166AC", "#C75B39"), labels = c("<8", ">=8")) +
  scale_fill_manual(values = c("#2166AC", "#C75B39"), labels = c("<8", ">=8")) +
  labs(
    x = "Propensity score",
    y = "Density within exposure arm",
    color = "Sessions/30 days",
    fill = "Sessions/30 days",
    title = "Covariate overlap before propensity weighting"
  ) +
  theme(legend.position = "bottom")
ggsave("outputs/figures/propensity_density.png", plot, width = 7.8, height = 3.7, dpi = 200)

# Count participants outside the common propensity-score range.
support_min <- max(tapply(analytic_data$ps, analytic_data$A, min))
support_max <- min(tapply(analytic_data$ps, analytic_data$A, max))
outside <- analytic_data$ps < support_min | analytic_data$ps > support_max
outcsv(
  data.frame(
    common_min = support_min,
    common_max = support_max,
    outside_n = sum(outside),
    outside_weighted_pct = 100 * wm(as.numeric(outside), analytic_data$MEC8YR)
  ),
  "common_support"
)

# Check balance and effective sample sizes after capping the PATE weights.
weight_multiplier <- ifelse(
  analytic_data$A == 1,
  1 / analytic_data$ps,
  1 / (1 - analytic_data$ps)
)
capped_weights <- analytic_data$MEC8YR * weight_multiplier
for (exposure in 0:1) {
  in_exposure_arm <- analytic_data$A == exposure
  capped_weights[in_exposure_arm] <- analytic_data$MEC8YR[in_exposure_arm] * pmin(
    weight_multiplier[in_exposure_arm],
    quantile(weight_multiplier[in_exposure_arm], .99, type = 1)
  )
}
outcsv(
  data.frame(
    method = "PATE capped",
    max_abs_smd = max(abs(balance(
      design_objects$X, analytic_data$A, analytic_data$MEC8YR, capped_weights
    )$smd)),
    ESS0 = ess(capped_weights[analytic_data$A == 0]),
    ESS1 = ess(capped_weights[analytic_data$A == 1])
  ),
  "capped_diagnostics"
)
cat("Result figures created.\n")
