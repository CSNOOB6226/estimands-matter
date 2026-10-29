source("R/00_common.R")

# Check the design files before reading the mortality outcomes.
stopifnot(file.exists("docs/DESIGN_FROZEN.json"), file.exists("DESIGN_FREEZE.md"))
design_objects <- readRDS("data/derived/design_objects.rds")
analytic_data <- design_objects$data
read_num <- function(field) {
  field <- trimws(field)
  field[field %in% c("", ".")] <- NA_character_
  as.integer(field)
}
mort <- do.call(rbind, lapply(c(1999, 2001, 2003, 2005), function(cycle_start) {
  mortality_lines <- readLines(paste0(
    "data/raw/NHANES_", cycle_start, "_", cycle_start + 1, "_MORT_2019_PUBLIC.dat"
  ))
  # Public files omit trailing blanks, so the last field can end at column 46 or 47.
  stopifnot(all(nchar(mortality_lines) >= 46 & nchar(mortality_lines) <= 48))
  data.frame(
    SEQN = read_num(substr(mortality_lines, 1, 6)),
    ELIGSTAT_check = read_num(substr(mortality_lines, 15, 15)),
    MORTSTAT = read_num(substr(mortality_lines, 16, 16)),
    PERMTH_EXM = read_num(substr(mortality_lines, 46, 48))
  )
}))

# Match mortality records and define death by 120 months.
stopifnot(!anyDuplicated(mort$SEQN), all(analytic_data$SEQN %in% mort$SEQN))
mm <- mort[match(analytic_data$SEQN, mort$SEQN), ]
stopifnot(identical(analytic_data$SEQN, as.numeric(mm$SEQN)), all(mm$ELIGSTAT_check == 1))
analytic_data$MORTSTAT <- mm$MORTSTAT
analytic_data$PERMTH_EXM <- mm$PERMTH_EXM
stopifnot(
  all(analytic_data$MORTSTAT %in% c(0, 1)),
  !anyNA(analytic_data$PERMTH_EXM),
  all(analytic_data$PERMTH_EXM >= 0)
)
analytic_data$death10 <- death_at_120(analytic_data$MORTSTAT, analytic_data$PERMTH_EXM)
stopifnot(
  !anyNA(analytic_data$death10),
  all(analytic_data$PERMTH_EXM[analytic_data$MORTSTAT == 0] >= 120)
)
analytic_data$time <- pmin(120, pmax(.5, analytic_data$PERMTH_EXM))
outcsv(
  data.frame(
    n = nrow(analytic_data),
    deaths10 = sum(analytic_data$death10),
    deaths_24 = sum(analytic_data$MORTSTAT == 1 & analytic_data$PERMTH_EXM <= 24),
    zero_months = sum(analytic_data$PERMTH_EXM == 0),
    min_alive_followup = min(analytic_data$PERMTH_EXM[analytic_data$MORTSTAT == 0]),
    missing_outcomes = sum(is.na(analytic_data$death10))
  ),
  "outcome_audit"
)
outcsv(
  aggregate(
    cbind(n = rep(1, nrow(analytic_data)), deaths10 = analytic_data$death10) ~ A + cycle,
    data = analytic_data,
    sum
  ),
  "events_by_cycle_exposure"
)
saveRDS(analytic_data, "data/derived/outcome_data.rds", version = 3)
cat(
  "Outcomes validated after design diagnostics:", nrow(analytic_data), "participants;",
  sum(analytic_data$death10), "deaths by120 months.\n"
)

# Create replicates before restricting the domain, keeping all masked PSUs.
all <- readRDS("data/derived/design_data.rds")
full <- make_design(subset(all, MEC8YR > 0))
repf <- as.svrepdesign(full, type = "JKn", mse = TRUE)
repd <- subset(repf, complete)
stopifnot(identical(repd$variables$SEQN, analytic_data$SEQN))
rw <- as.matrix(weights(repd, type = "analysis"))
basew <- analytic_data$MEC8YR
ps_matrix <- model.matrix(design_objects$ps)
stopifnot(nrow(ps_matrix) == nrow(analytic_data))

# Refit the propensity model for each set of survey weights.
fit_ps <- function(design_matrix, exposure, analysis_weights) {
  fit <- glm.fit(
    x = design_matrix,
    y = exposure,
    weights = analysis_weights / mean(analysis_weights),
    family = quasibinomial(),
    control = glm.control(epsilon = 1e-10, maxit = 100)
  )
  stopifnot(fit$converged)
  coefficients <- fit$coefficients
  coefficients[is.na(coefficients)] <- 0
  ps_values <- plogis(drop(design_matrix %*% coefficients))
  stopifnot(all(ps_values > 0 & ps_values < 1))
  ps_values
}
vector_risks <- function(r0, r1) {
  c(
    risk0 = r0,
    risk1 = r1,
    RD = r1 - r0,
    logRR = log(r1 / r0),
    logit0 = qlogis(r0),
    logit1 = qlogis(r1)
  )
}
weighted_quantile <- function(values, analysis_weights, probability = .99) {
  sorted_indices <- order(values)
  values[sorted_indices][
    which(cumsum(analysis_weights[sorted_indices]) / sum(analysis_weights) >= probability)[1]
  ]
}

# Estimate each risk contrast using the same data and survey weights.
estimate <- function(sw, dd, xx, methods, originalw) {
  exposure <- dd$A
  death10 <- dd$death10
  ps_values <- fit_ps(xx, exposure, sw)
  ans <- list()
  for (method in methods) {
    if (method == "Standardized logistic") {
      ox <- cbind(xx, A = exposure)
      fit <- glm.fit(
        ox,
        death10,
        weights = sw / mean(sw),
        family = quasibinomial(),
        control = glm.control(epsilon = 1e-10, maxit = 100)
      )
      stopifnot(fit$converged)
      coefficients <- fit$coefficients
      coefficients[is.na(coefficients)] <- 0
      risks <- sapply(0:1, function(exposure_level) {
        px <- ox
        px[, "A"] <- exposure_level
        wm(plogis(drop(px %*% coefficients)), sw)
      })
    } else {
      analysis_weights <- composite(
        exposure, ps_values, sw, if (method == "PATE capped") "PATE" else method
      )
      if (method == "PATE capped") {
        mult <- ifelse(exposure == 1, 1 / ps_values, 1 / (1 - ps_values))
        rf <- sw / originalw
        for (exposure_level in 0:1) {
          idx <- exposure == exposure_level
          cap <- weighted_quantile(mult[idx], rf[idx])
          analysis_weights[idx] <- sw[idx] * pmin(mult[idx], cap)
        }
      }
      risks <- sapply(0:1, function(exposure_level) {
        wm(death10[exposure == exposure_level], analysis_weights[exposure == exposure_level])
      })
    }
    ans[[method]] <- vector_risks(risks[1], risks[2])
  }
  unlist(ans)
}

# Form confidence intervals from the replicate covariance matrix.
summarize_est <- function(theta, covariance, methods, scenario, df, n, events) {
  critical <- qt(.975, df)
  rows <- list()
  for (method in methods) {
    nm <- paste0(method, ".", c("risk0", "risk1", "RD", "logRR", "logit0", "logit1"))
    estimates <- theta[nm]
    se <- sqrt(pmax(0, diag(covariance)[nm]))
    ci0 <- plogis(estimates[5] + c(-1, 1) * critical * se[5])
    ci1 <- plogis(estimates[6] + c(-1, 1) * critical * se[6])
    cird <- estimates[3] + c(-1, 1) * critical * se[3]
    cirr <- exp(estimates[4] + c(-1, 1) * critical * se[4])
    rows[[method]] <- data.frame(
      scenario = scenario,
      method = method,
      n = n,
      events = events,
      df = df,
      risk0 = estimates[1],
      risk0_low = ci0[1],
      risk0_high = ci0[2],
      risk1 = estimates[2],
      risk1_low = ci1[1],
      risk1_high = ci1[2],
      RD = estimates[3],
      RD_low = cird[1],
      RD_high = cird[2],
      RR = exp(estimates[4]),
      RR_low = cirr[1],
      RR_high = cirr[2],
      SE_RD = se[3],
      SE_logRR = se[4],
      row.names = NULL
    )
  }
  do.call(rbind, rows)
}

# Repeat the full estimation within each jackknife replicate.
run_scenario <- function(idx, methods, label) {
  dd <- analytic_data[idx, ]
  xx <- ps_matrix[idx, , drop = FALSE]
  analysis_weights <- basew[idx]
  wr <- rw[idx, , drop = FALSE]
  theta <- estimate(analysis_weights, dd, xx, methods, analysis_weights)
  rr <- matrix(NA_real_, ncol(wr), length(theta), dimnames = list(NULL, names(theta)))
  for (replicate_index in seq_len(ncol(wr))) {
    rr[replicate_index, ] <- estimate(wr[, replicate_index], dd, xx, methods, analysis_weights)
    if (replicate_index %% 30 == 0) {
      cat(label, ":", replicate_index, "/", ncol(wr), "replicates\n")
    }
  }
  stopifnot(all(is.finite(rr)))
  covariance <- survey::svrVar(
    rr,
    scale = repd$scale, rscales = repd$rscales, mse = TRUE, coef = theta
  )
  dimnames(covariance) <- list(names(theta), names(theta))
  df <- degf(subset(repd, idx))
  list(
    theta = theta,
    variance = covariance,
    replicates = rr,
    summary = summarize_est(theta, covariance, methods, label, df, nrow(dd), sum(dd$death10))
  )
}

# Save the primary analysis and the two sensitivity analyses.
main <- run_scenario(
  rep(TRUE, nrow(analytic_data)),
  c("Survey", "Standardized logistic", "PATE", "PATO", "PATE capped"),
  "Primary"
)
saveRDS(main, "data/derived/main_results.rds", version = 3)
outcsv(main$summary, "main_results")
print(main$summary)
sens1 <- run_scenario(
  !(analytic_data$MORTSTAT == 1 & analytic_data$PERMTH_EXM <= 24),
  c("PATE", "PATO"),
  "24-month survivor landmark"
)
sens2 <- run_scenario(
  analytic_data$cancer == "No" & analytic_data$cvd == "No",
  c("PATE", "PATO"),
  "Exclude baseline cancer/CVD"
)
outcsv(rbind(sens1$summary, sens2$summary), "sensitivity_results")
saveRDS(
  list(
    main = main,
    landmark = sens1,
    no_disease = sens2,
    scale = repd$scale,
    rscales = repd$rscales,
    replicate_count = ncol(rw)
  ),
  "data/derived/all_risk_results.rds",
  version = 3
)

# Check point estimates directly and calculate fixed-PS Taylor standard errors.
checks <- list()
for (method in c("Survey", "PATE", "PATO")) {
  dd <- analytic_data
  dd$MEC8YR <- composite(dd$A, dd$ps, dd$MEC8YR, method)
  ds <- make_design(dd)
  means <- svyby(~death10, ~A, ds, svymean, covmat = TRUE)
  risks <- coef(means)
  covariance <- vcov(means)
  gradient <- c(-1 / risks[1], 1 / risks[2])
  manual <- sapply(0:1, function(exposure) {
    with(dd[dd$A == exposure, ], sum(MEC8YR * death10) / sum(MEC8YR))
  })
  stopifnot(
    max(abs(risks - manual)) < 1e-10,
    max(abs(manual - main$theta[paste0(method, c(".risk0", ".risk1"))])) < 1e-9
  )
  checks[[method]] <- data.frame(
    method = method,
    risk0 = risks[1],
    risk1 = risks[2],
    SE_RD_fixedPS = sqrt(drop(c(-1, 1) %*% covariance %*% c(-1, 1))),
    SE_logRR_fixedPS = sqrt(drop(gradient %*% covariance %*% gradient)),
    max_point_difference = max(abs(risks - manual)),
    row.names = NULL
  )
}
outcsv(do.call(rbind, checks), "independent_risk_validation")

# Check balance after refitting propensity scores within each sensitivity sample.
diagnostics <- list()
for (scenario_label in c("Primary", "Landmark", "No cancer/CVD")) {
  idx <- if (scenario_label == "Primary") {
    rep(TRUE, nrow(analytic_data))
  } else if (scenario_label == "Landmark") {
    !(analytic_data$MORTSTAT == 1 & analytic_data$PERMTH_EXM <= 24)
  } else {
    analytic_data$cancer == "No" & analytic_data$cvd == "No"
  }
  dd <- analytic_data[idx, ]
  ee <- fit_ps(ps_matrix[idx, , drop = FALSE], dd$A, dd$MEC8YR)
  for (method in c("PATE", "PATO")) {
    analysis_weights <- composite(dd$A, ee, dd$MEC8YR, method)
    diagnostics[[length(diagnostics) + 1]] <- data.frame(
      scenario = scenario_label,
      method = method,
      max_abs_smd = max(abs(balance(
        design_objects$X[idx, , drop = FALSE], dd$A, dd$MEC8YR, analysis_weights
      )$smd)),
      ESS0 = ess(analysis_weights[dd$A == 0]),
      ESS1 = ess(analysis_weights[dd$A == 1])
    )
  }
}
outcsv(do.call(rbind, diagnostics), "sensitivity_design_diagnostics")
capture.output(sessionInfo(), file = "logs/sessionInfo_outcomes.txt")
cat("All risk analyses and independent point checks complete.\n")
