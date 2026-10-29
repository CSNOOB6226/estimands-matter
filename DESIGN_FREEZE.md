# Analysis specification and reproducibility

This document records the definitions, model settings, and file checks for the included NHANES analysis. Use the same settings when reproducing the reference outputs. It describes the implemented analysis and is not a public preregistration.

The analysis is documented in [docs/PROTOCOL.md](docs/PROTOCOL.md), [docs/DAG.md](docs/DAG.md), [docs/ANALYSIS_PLAN.md](docs/ANALYSIS_PLAN.md), [MISSING_DATA_PLAN.md](MISSING_DATA_PLAN.md), and [VARIABLE_DICTIONARY.md](VARIABLE_DICTIONARY.md). The design stages produce `data/derived/design_objects.rds`, containing the propensity-score formula and spline basis.

The main sample contains 15,091 complete-case, exposure-eligible adults. The specification includes population-average and overlap-population composite weights, stratified jackknife uncertainty with propensity-model refitting, a Cox benchmark, proportional-hazards checks, and three sensitivity analyses.

The workflow separates exposure/covariate preparation and balance diagnostics from mortality estimation. The first stages produce the analysis sample, propensity model, and diagnostics; the outcome stages use these objects to estimate risks and fit the Cox benchmark.

`docs/DESIGN_FROZEN.json` records SHA-256 checksums of the distributed files and 27 reference result tables. `python3 analysis/verify_manifest.py` checks them alongside the original public-data checksums. A checksum detects a changed file relative to this record. Documentation revisions update the relevant checksums while retaining the numerical reference tables.

Scientific and interpretation limits are described in the protocol and missing-data plan. Project scope is summarized in the README.
