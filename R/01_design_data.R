# Read only participant IDs and linkage eligibility from the mortality files.
source("R/00_common.R")

# List the variables needed from each NHANES component.
spec <- list(
  DEMO = c(
    "SDDSRVYR", "RIDSTATR", "RIDAGEYR", "RIAGENDR", "RIDRETH1", "DMDEDUC2",
    "INDFMPIR", "WTMEC2YR", "WTMEC4YR", "SDMVSTRA", "SDMVPSU"
  ),
  PAQ = c("PAD440", "PAD460", "PAD200", "PAD320"),
  BMX = "BMXBMI",
  SMQ = c("SMQ020", "SMQ040"),
  ALQ = c("ALQ100", "ALD100", "ALQ101", "ALQ110", "ALQ120Q", "ALQ120U", "ALQ130"),
  HUQ = "HUQ010",
  DIQ = "DIQ010",
  BPQ = "BPQ020",
  MCQ = c("MCQ160B", "MCQ160C", "MCQ160D", "MCQ160E", "MCQ160F", "MCQ220")
)
availability <- list()
cycle_data <- list()
checks <- list()

# Join components within each cycle and record variable availability.
for (cycle_index in 1:4) {
  year <- c(1999, 2001, 2003, 2005)[cycle_index]
  suffix <- c("", "_B", "_C", "_D")[cycle_index]
  for (comp in names(spec)) {
    path <- paste0("data/raw/", comp, suffix, ".xpt")
    component_data <- read.xport(path)
    stopifnot(!anyDuplicated(component_data$SEQN))
    wanted <- spec[[comp]]
    for (variable in wanted) {
      availability[[length(availability) + 1]] <- data.frame(
        cycle = paste0(year, "-", year + 1),
        component = comp,
        variable = variable,
        present = variable %in% names(component_data),
        file = path
      )
    }
    component_data <- component_data[
      , c("SEQN", intersect(wanted, names(component_data))), drop = FALSE
    ]
    for (variable in setdiff(wanted, names(component_data))) {
      component_data[[variable]] <- NA_real_
    }
    if (comp == "DEMO") {
      analytic_data <- component_data
    } else {
      stopifnot(all(component_data$SEQN %in% analytic_data$SEQN))
      before <- nrow(analytic_data)
      analytic_data <- merge(
        analytic_data, component_data, by = "SEQN", all.x = TRUE, sort = FALSE
      )
      stopifnot(nrow(analytic_data) == before)
    }
  }

  # Add linkage eligibility and calculate the combined eight-year survey weight.
  lines <- readLines(paste0("data/raw/NHANES_", year, "_", year + 1, "_MORT_2019_PUBLIC.dat"))
  eligibility <- data.frame(
    SEQN = as.integer(substr(lines, 1, 6)),
    ELIGSTAT = as.integer(substr(lines, 15, 15))
  )
  rm(lines)
  stopifnot(
    !anyDuplicated(eligibility$SEQN),
    setequal(eligibility$SEQN, analytic_data$SEQN)
  )
  analytic_data <- merge(
    analytic_data, eligibility, by = "SEQN", all.x = TRUE, sort = FALSE
  )
  stopifnot(all(analytic_data$SDDSRVYR == cycle_index))
  analytic_data$cycle <- factor(paste0(year, "-", year + 1))
  analytic_data$MEC8YR <- if (cycle_index <= 2) {
    analytic_data$WTMEC4YR / 2
  } else {
    analytic_data$WTMEC2YR / 4
  }
  analytic_data$ALC_LEAD <- if (cycle_index == 1) {
    analytic_data$ALQ100
  } else if (cycle_index == 2) {
    analytic_data$ALD100
  } else {
    analytic_data$ALQ101
  }
  cycle_data[[cycle_index]] <- analytic_data
  checks[[cycle_index]] <- data.frame(
    cycle = as.character(analytic_data$cycle[1]),
    n = nrow(analytic_data),
    adult = sum(analytic_data$RIDAGEYR >= 20),
    mec_sum = sum(analytic_data$MEC8YR),
    adult_mec_sum = sum(analytic_data$MEC8YR[analytic_data$RIDAGEYR >= 20]),
    strata_min = min(analytic_data$SDMVSTRA),
    strata_max = max(analytic_data$SDMVSTRA)
  )
}

# Combine the cycles and check identifiers, ages, and survey fields.
analytic_data <- do.call(rbind, cycle_data)
stopifnot(!anyDuplicated(analytic_data$SEQN))
stopifnot(
  all(analytic_data$RIDAGEYR >= 0 & analytic_data$RIDAGEYR <= 85),
  all(analytic_data$MEC8YR >= 0),
  !anyNA(analytic_data[c("SDMVSTRA", "SDMVPSU", "MEC8YR", "ELIGSTAT")])
)
outcsv(do.call(rbind, availability), "variable_availability")
outcsv(do.call(rbind, checks), "cycle_weight_check")

# Check the original strength-training codes before defining exposure.
outcsv(
  as.data.frame(with(
    subset(analytic_data, RIDAGEYR >= 20),
    table(cycle, PAD440, useNA = "ifany")
  )),
  "exposure_codes_by_cycle"
)
stopifnot(!any(analytic_data$PAD440 %in% c(2, 3) & !is.na(analytic_data$PAD460)))
valid_count <- !is.na(analytic_data$PAD460) &
  analytic_data$PAD460 >= 1 & analytic_data$PAD460 <= 300
analytic_data$strength_count <- ifelse(
  analytic_data$PAD440 == 2,
  0,
  ifelse(analytic_data$PAD440 == 1 & valid_count, analytic_data$PAD460, NA_real_)
)
analytic_data$A <- ifelse(
  is.na(analytic_data$strength_count),
  NA_integer_,
  as.integer(analytic_data$strength_count >= 8)
)

# Recode demographic variables and smoking, keeping unknown responses missing.
valid <- function(value, range) ifelse(value %in% range, value, NA_real_)
yn <- function(value) {
  factor(ifelse(value == 1, "Yes", ifelse(value == 2, "No", NA)), levels = c("No", "Yes"))
}
analytic_data$age <- analytic_data$RIDAGEYR
analytic_data$sex <- factor(
  valid(analytic_data$RIAGENDR, 1:2), levels = 1:2, labels = c("Male", "Female")
)
analytic_data$race <- factor(
  valid(analytic_data$RIDRETH1, 1:5),
  levels = 1:5,
  labels = c(
    "Mexican American", "Other Hispanic", "Non-Hispanic White",
    "Non-Hispanic Black", "Other or multiracial"
  )
)
analytic_data$education <- factor(
  valid(analytic_data$DMDEDUC2, 1:5),
  levels = 1:5,
  labels = c(
    "<9th grade", "9th-11th grade", "High school/GED",
    "Some college/AA", "College graduate"
  )
)
analytic_data$pir <- ifelse(
  analytic_data$INDFMPIR >= 0 & analytic_data$INDFMPIR <= 5,
  analytic_data$INDFMPIR,
  NA_real_
)
analytic_data$bmi <- analytic_data$BMXBMI
stopifnot(all(analytic_data$bmi[!is.na(analytic_data$bmi)] > 0))
analytic_data$smoking <- factor(
  ifelse(
    analytic_data$SMQ020 == 2,
    "Never",
    ifelse(
      analytic_data$SMQ020 == 1 & analytic_data$SMQ040 == 3,
      "Former",
      ifelse(
        analytic_data$SMQ020 == 1 & analytic_data$SMQ040 %in% c(1, 2),
        "Current",
        NA
      )
    )
  ),
  levels = c("Never", "Former", "Current")
)

# Use lifetime screening responses to resolve alcohol-question skips.
never <- analytic_data$ALC_LEAD == 2 & analytic_data$ALQ110 == 2
drinking_frequency <- analytic_data$ALQ120Q
validq <- !is.na(drinking_frequency) & drinking_frequency >= 0 & drinking_frequency <= 366
analytic_data$alcohol <- ifelse(never, "Lifetime <12 drinks", NA_character_)
analytic_data$alcohol[which(validq & drinking_frequency == 0)] <- "No past-year drinking"
analytic_data$alcohol[which(validq & drinking_frequency > 0)] <- "Past-year drinking"
analytic_data$alcohol <- factor(
  analytic_data$alcohol,
  levels = c("Lifetime <12 drinks", "No past-year drinking", "Past-year drinking")
)

# Record broad aerobic activity and self-reported health conditions.
vig <- ifelse(
  analytic_data$PAD200 == 1, 1, ifelse(analytic_data$PAD200 %in% c(2, 3), 0, NA)
)
mod <- ifelse(
  analytic_data$PAD320 == 1, 1, ifelse(analytic_data$PAD320 %in% c(2, 3), 0, NA)
)
analytic_data$aerobic <- factor(
  mod + 2 * vig,
  levels = 0:3,
  labels = c("Neither", "Moderate only", "Vigorous only", "Both")
)
analytic_data$health <- factor(
  valid(analytic_data$HUQ010, 1:5),
  levels = 1:5,
  labels = c("Excellent", "Very good", "Good", "Fair", "Poor")
)
analytic_data$diabetes <- factor(
  valid(analytic_data$DIQ010, 1:3), levels = c(2, 3, 1), labels = c("No", "Borderline", "Yes")
)
analytic_data$hypertension <- yn(analytic_data$BPQ020)
cv <- analytic_data[, paste0("MCQ160", LETTERS[2:6])]
analytic_data$cvd <- factor(
  ifelse(
    rowSums(cv == 1, na.rm = TRUE) > 0,
    "Yes",
    ifelse(rowSums(cv == 2, na.rm = TRUE) == 5, "No", NA)
  ),
  levels = c("No", "Yes")
)
analytic_data$cancer <- yn(analytic_data$MCQ220)

# Mark each sample restriction and save the design variables.
analytic_data$adult <- analytic_data$age >= 20
analytic_data$linkage <- analytic_data$adult & analytic_data$ELIGSTAT == 1
analytic_data$exposure_eligible <- analytic_data$linkage & !is.na(analytic_data$A)
analytic_data$design_eligible <- analytic_data$exposure_eligible & analytic_data$MEC8YR > 0
analytic_data$complete <- analytic_data$design_eligible & complete.cases(analytic_data[, covars])
keep <- c(
  "SEQN", "ELIGSTAT", "SDMVSTRA", "SDMVPSU", "MEC8YR", "A", "strength_count", covars,
  "PAD440", "PAD460", "adult", "linkage", "exposure_eligible", "design_eligible", "complete"
)
analytic_data <- analytic_data[, unique(keep)]
stopifnot(!any(c("MORTSTAT", "PERMTH_EXM", "death10") %in% names(analytic_data)))
saveRDS(analytic_data, "data/derived/design_data.rds", version = 3)

# Summarize exclusions at each stage.
flow <- data.frame(
  stage = c(
    "All NHANES participants", "Adults age 20+", "Mortality linkage eligible",
    "Interpretable strength exposure", "Positive MEC weight", "Covariate-complete analytic sample"
  ),
  n = c(
    nrow(analytic_data), sum(analytic_data$adult), sum(analytic_data$linkage),
    sum(analytic_data$exposure_eligible), sum(analytic_data$design_eligible),
    sum(analytic_data$complete)
  )
)
flow$excluded_since_previous <- c(NA, -diff(flow$n))
outcsv(flow, "participant_flow_design")
print(flow)

# Count missing covariates overall, by cycle, and by exposure group.
missing <- list()
eligible_data <- subset(analytic_data, design_eligible)
for (group in c("Overall", levels(eligible_data$cycle), "A=0", "A=1")) {
  group_data <- if (group == "Overall") {
    eligible_data
  } else if (grepl("A=", group)) {
    eligible_data[eligible_data$A == as.integer(substr(group, 3, 3)), ]
  } else {
    eligible_data[eligible_data$cycle == group, ]
  }
  for (variable in covars) {
    missing[[length(missing) + 1]] <- data.frame(
      group = group,
      variable = variable,
      n = nrow(group_data),
      missing = sum(is.na(group_data[[variable]])),
      pct = 100 * mean(is.na(group_data[[variable]]))
    )
  }
}
outcsv(do.call(rbind, missing), "missingness")
cat("Complete cases:", sum(analytic_data$complete), "/", sum(analytic_data$design_eligible), "\n")
