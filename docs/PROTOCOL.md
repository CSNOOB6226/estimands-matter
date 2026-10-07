# Outcome-blinded protocol

Version 1; 2026-09-23; independent methodological reanalysis. No outcome data accessed before the design snapshot. This protocol fixes analyses rather than asserting exchangeability or a well-defined long-term intervention.

## Question and target-trial-informed specification
| Component | Specification and observational limitation |
|---|---|
| Eligibility | NHANES 1999–2006, age >=20, ELIGSTAT=1, interpretable strength exposure, positive MEC weight, complete prespecified covariates. PAD440=3 (unable) excluded; this narrows the target to people without reported inability. |
| Time zero | MEC examination; baseline interview measurements can precede this date. |
| Ideal strategies | Sustained muscle-strengthening activity at least twice weekly versus less; this ideal cannot be recovered from these data. |
| Observed exposure | A=1 if PAD440=1 and valid PAD460>=8; A=0 if PAD440=2 or valid PAD460=1–7. Counts are sessions in 30 days, not distinct days, intensity or sustained adherence. |
| Assignment | Observational; account for measured baseline variables using propensity weighting. |
| Follow-up | 120 months from MEC, through public-use 2019 mortality linkage. Latest included cycle ends 2006, allowing at least 13 calendar years of potential follow-up. |
| Outcome | MORTSTAT=1 and PERMTH_EXM<=120; otherwise zero only if follow-up reaches 120. Public-use time may be synthetic. |
| Contrast | Marginal 10-year risk difference R1-R0 and risk ratio R1/R0. Adjusted associations; causal interpretation requires consistency, exchangeability, positivity and valid selection/measurement assumptions that are not established. |
| Target | Survey-weighted complete-case, exposure-eligible adult response domain. PATE uses its full covariate distribution; PATO tilts that distribution by e(X)[1-e(X)]. Neither automatically describes all contemporary US adults. |

## Covariates and forms
Age (natural cubic spline, 4 df), BMI and income/poverty ratio (each natural spline, 3 df), sex, race/ethnicity, education, smoking, alcohol, broad aerobic activity, self-rated health, diabetes, hypertension, cardiovascular disease, cancer and survey cycle. The core set is retained regardless of individual p-values. Formula and realized spline knots are stored in design_objects.rds. No interactions were needed after balance diagnostics; no outcome-driven specification search.

Alcohol uses lifetime <12 drinks, no past-year drinking, and past-year drinking. This transparent cross-cycle variable does not fully capture dose. Aerobic activity is neither, moderate only, vigorous only or both, based on any >=10-minute bout in the prior 30 days; it does not measure aerobic volume or guideline adherence. PAD200/PAD320 inability codes count as no reported activity; PAD440 inability is excluded from exposure eligibility. These distinctions must appear in the limitations.

## Design and estimands
MEC8YR=WTMEC4YR/2 in 1999–2002; WTMEC2YR/4 in 2003–2006. All selected variables are household or MEC measures, without special subsample weights. Use original SDMVSTRA and nested SDMVPSU; retain all positive-weight sampled persons before subsetting domains. The 58 strata are already distinct across cycles. There are 117 PSUs (stratum 1 has three); do not impose a two-PSU design. Lonely PSU option is 'fail'; investigate any occurrence instead of applying an arbitrary adjustment. No FPC is supplied; use the public masked-PSU design approximation.

Estimate e(X)=Pr(A=1|X) with survey-weighted logistic regression. With sampling weight d, PATE composite weights are d[A/e+(1-A)/(1-e)]; PATO weights are d[A(1-e)+(1-A)e]. Estimate each risk by a separate-arm Hajek ratio. Multiplying an arm's weights by a constant does not change its risk. ESS=(sum w)^2/sum(w^2) is a weight-dispersion diagnostic, not the design degrees of freedom.

The spline survey-PS specification is selected over an unweighted PS because it targets population balance and produces smaller maximum composite-weight SMDs. SMDs use the fixed survey-weighted pooled within-arm SD before propensity weighting; all dummy variables, spline columns and raw continuous covariates are assessed. The diagnostic threshold was |SMD|<0.10 in R/02_design_diagnostics.R before the first diagnostic run. It is a descriptive criterion, not a proof of absence of confounding. PATO exact mean balance follows from the weighted logistic score equations; it is partly an algebraic property.

## Uncertainty and benchmark
Primary uncertainty: delete-one-PSU stratified JKn replicates from the full positive-MEC-weight survey design, then subset the analytic domain. Refit the selected propensity model in every replicate using the fixed design matrix (same knots/forms); recompute composite weights and risk ratios. Use survey::svrVar with the generated scale/rscales and mse=TRUE. Use t critical values with full domain design df (59 for the main analysis). Confidence intervals use logit risk, untransformed RD, and log RR. Refit both the outcome model and standardization population in replicates for the conventional survey-weighted logistic standardization reference. For comparison, report fixed-propensity Taylor variance and directly validate point estimates by survey means and simple weighted sums. No iid glm standard errors are used for conclusions. JKn propagates PS coefficient estimation but not design specification choice, item nonresponse, linkage error or synthetic follow-up perturbation.

Cox benchmark: survey-weighted adjusted Cox model through 120 months with the same covariate basis, using Breslow ties. Cox HR is conditional and is not a ten-year RR. Examine weighted Schoenfeld residual plots; ordinary cox.zph p-values are explicitly exploratory because they do not fully reflect survey design. Also fit a prespecified A-by-follow-up-period (0–60 versus >60–120 months) interaction in the survey Cox counting-process model and test it using design-based variance. This tests one departure from proportional hazards, not every possible time-varying effect.

## Sensitivity analyses fixed before outcomes
1. Exclude deaths in the first 24 months; refit PS among survivors to 24 months. Interpret remaining deaths through month 120 as an eight-year landmark risk conditional on 24-month survival. This changes the population and can introduce survivor selection; it cannot prove reverse causation absent.
2. Exclude baseline cancer or major CVD (heart failure, coronary disease, angina, myocardial infarction or stroke); refit PS with the same basis and omit constant columns.
3. Cap the ATE propensity multiplier at its within-exposure-arm unweighted 99th percentile; retain original sampling weights and recompute cutoffs in each JKn replicate. Trigger this stability analysis if pre-outcome maximum propensity multiplier exceeds 20 or exposed-arm ESS falls >40% relative to sampling weights alone. Both are true here (45.42; 40.7%). Only this single cap is used. Capping sacrifices exact PATE targeting, so label it a robustness check, not another unbiased PATE estimate.

Unplanned subgroups, thresholds, machine-learning estimators, and stable balancing weights were outside the specified analysis. Post-freeze implementation changes were limited to coding corrections rather than outcome-driven model selection.

## Interpretation limits
Complete-case generalizability, inability exclusion, broad aerobic/alcohol measures, baseline health as a possible prior-activity mediator, and the jackknife approximation limit interpretation. Balance does not establish exchangeability, and the baseline measurements do not identify the effect of sustained training.
