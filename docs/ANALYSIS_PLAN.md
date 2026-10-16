# Estimands Matter — analysis plan

**Implemented analysis specification.** This plan describes the supplied code and reference results.

## 1. Research question and population
Compare baseline muscle-strengthening activity >=8 versus 0–7 sessions in the previous 30 days with 10-year all-cause mortality in NHANES 1999–2006 linked to the public 2019 mortality files. This independent research project reanalyzes an established health question to compare population-average and overlap-population targets. The comparison examines how weighting changes population profiles, covariate balance, effective sample sizes, absolute risks, and uncertainty.

Include adults >=20, linkage eligible, with interpretable PAD440/PAD460, positive MEC weight and complete covariates. Exclude self-reported inability to perform strength activity. The complete-case response domain contains 15,091 adults; 17.37% of otherwise eligible examined participants lack one or more covariates. Its survey-weighted population differs from excluded respondents. PATE therefore refers to this restricted domain, and PATO further emphasizes covariate profiles with exposure equipoise.

Time zero is the MEC examination. Define death10=1 for MORTSTAT=1 and PERMTH_EXM<=120, otherwise 0 only with at least 120 months observed. Examine missing, invalid, zero-month and boundary times before modeling. Synthetic follow-up values in selected public records limit exact event timing. The latest enrollment cycle has sufficient potential follow-up through 2019. Exposure is a baseline report, not assignment to sustained activity.

## 2. Design and confounding adjustment
Use MEC8YR=WTMEC4YR/2 for 1999–2002 and WTMEC2YR/4 for 2003–2006. Construct survey design on all positive-weight records before analytic-domain restriction; use original SDMVSTRA and nested SDMVPSU. There are 58 strata and 117 PSUs. Fail and investigate if a singleton PSU appears. Do not relabel shared PSU numbers without nesting.

Specified variables: age, sex, race/ethnicity, education, income/poverty ratio, smoking, alcohol, BMI, broad aerobic activity, self-rated health, diabetes, hypertension, CVD, cancer and cycle. Age uses a natural spline with 4 df; BMI and poverty ratio use 3 df each. Other variables are factors. Data dictionary and DAG explain temporal ambiguities and prior-activity mediation. The implementation uses no univariate p-value selection, missing categories, imputation, additional thresholds or subgroup analyses.

Fit survey-weighted logistic PS e(X). Compare composite-weight balance and ESS with the same unweighted specification; use weighted PS for estimation. These diagnostics use exposure and covariates rather than mortality outcomes. For ATE use d/e for A=1 and d/(1-e) for A=0. For overlap use d(1-e) and de. Normalize within exposure arms when calculating risk. Diagnose all model terms and raw continuous covariates with a fixed preweighting survey-population pooled-SD denominator; target |SMD|<.10. Observed maxima are .0362 for PATE and approximately zero for PATO. Report distributional overlap, weight quantiles and arm-specific Kish ESS; these do not establish exchangeability.

## 3. Estimation and uncertainty
Primary contrasts are separate-arm weighted 10-year marginal risks, R1-R0, and R1/R0 for both targets. Also show unadjusted survey risks and conventional survey logistic standardization with the same covariate basis. Primary uncertainty uses stratified delete-one-PSU JKn replicates, retaining the domain structure and re-estimating PS coefficients in every replicate. Knots and basis remain fixed. Re-estimate the outcome regression and averaging distribution for standardized-reference replicates. Apply generated replicate scaling, mse=TRUE and design df (59 in primary analysis). Use logit risk CIs, direct RD CIs and log RR CIs. Report fixed-PS Taylor variance as a comparator; ordinary glm standard errors do not support inference.

Fit a survey-weighted adjusted Cox model through month120, with Breslow ties and the same covariate basis. Treat HR as a conditional benchmark. Examine weighted Schoenfeld residuals (exploratory, with non-design-adjusted cox.zph p-values labeled) and a design-based A-by-period interaction split at month60. Fixed-horizon risks remain the main endpoints; PH tests concern the Cox benchmark.

## 4. Sensitivity, reproducibility and interpretation
Included sensitivities: (i) exclude deaths through month24 and refit PS, labeling the endpoint an eight-year landmark risk conditional on survival to month24; (ii) exclude baseline cancer/CVD, refit the same basis and drop only constant columns; (iii) if maximum ATE multiplier>20 or exposed ESS drops >40% from survey-only ESS, cap the multiplier once at within-arm 99th percentile and repeat estimation. This trigger is met. Capped estimates are a robustness check with imperfect PATE targeting, not an alternative preferred answer.

Raw originals remain unchanged, with URLs and hashes. Validate unique IDs, cycle labels, skips, special missing codes, denominators, weights, outcomes, risk arithmetic and output consistency. Check PS estimates and weighted risk ratios using separate calculations; compare complete pipeline runs. The report, figures, tables, and reproducibility instructions describe the implemented analysis. DESIGN_FREEZE.md explains the specification and file-integrity record; the README summarizes project scope.

Interpretation is limited by the restricted complete-case target, inability exclusions, coarsened activity/alcohol measures, reverse causation, unmeasured confounding, uncertain prior-activity pathways, and imperfect synthetic event times. Baseline associations cannot identify a sustained 10-year training effect.
