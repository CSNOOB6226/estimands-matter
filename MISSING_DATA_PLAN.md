# Missing-data plan — frozen with design snapshot

2026-09-23; chosen before inspecting mortality outcomes. Primary analysis: complete cases of the 15 prespecified covariates, among exposure-eligible linkage-eligible adults with positive MEC weights. No missing-category imputation and no model-selection p-values.

Of 18,264 otherwise eligible adults, 15,091 (82.63%) are complete and 3,173 (17.37%) are excluded. The largest missing proportions are alcohol 8.01%, income/poverty ratio 7.63%, and BMI 2.58%. These overlap. Full variable-level denominators and missingness by cycle and exposure are in outputs/tables/missingness.csv. Structural smoking/alcohol/exposure skips were resolved using their screening variables; unknown/refused values remain missing.

Selection is not ignorable by default. Included versus excluded survey-weighted characteristics: mean age 45.72 versus 46.36; income/poverty ratio 3.07 versus 2.57 among observed values; fair health 12.58% versus 15.20%; poor health 2.69% versus 3.75%; strength-exposure prevalence 21.37% versus 18.77%. All available-value denominators are exported. Original MEC weights address sampling and exam nonresponse but not this item-nonresponse restriction.

Therefore the PATE target is explicitly the survey-weighted complete-response analytic domain, not an unqualified national adult average. PATO is a further tilt of this domain. The response-domain target is less scientifically transportable than a complete population estimand, and selection can bias causal or association interpretations relative to broader populations.

The 17.37% complete-case loss is a substantive limitation. Multiple imputation or response-selection weights may be useful extensions, but require reliable handling of survey design, propensity estimation, and variance. Neither was implemented in this analysis. Complete-case analysis is not assumed to be unbiased, missing completely at random, or representative of excluded adults.
