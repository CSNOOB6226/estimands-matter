# Reproducibility

## Environment and dependencies

The original analysis used R 4.5.2 on macOS, `survey` 4.5, `survival` 3.8-3, `foreign` 0.8-90, and `ggplot2` 4.0.2. The random seed is 20260923. The fitted models and JKn replicates are deterministic within a compatible numerical environment; package and platform changes can produce small numerical differences.

Install Python 3.10 or later and R, then run from the repository root:

```sh
python3 -m pip install -r requirements.txt
Rscript install_packages.R
```

`splines` and `stats` are part of R. Python uses `reportlab`, `pypdf`, and `Pillow` for report generation and inspection. The repository uses installed R packages rather than bundled platform-specific binaries. `BIOSTAT_REPORT_PYTHON` may select a separate Python interpreter containing the report dependencies.

## End-to-end execution

```sh
python3 run_project.py
```

The original public files are included. Add `--download` to fetch or validate the official originals before running. Use `--no-report` to run the statistical pipeline and checks without rebuilding reports.

The entry point verifies raw-file checksums and the publication-copy manifest, then runs each statistical stage in a separate R process. It rebuilds derived data, 27 numerical tables, and 10 figures. Both R test files run within the pipeline. Report generation reads the exported results and creates PDF and Markdown versions. A failed stage stops execution and identifies its log.

## Data and design integrity

The public NHANES component and 2019 mortality files were downloaded on 2026-09-23. `data/download_manifest.csv` records their URLs, UTC timestamps, byte counts, and SHA-256 checksums. Download validation checks file signatures and hashes and does not silently replace changed originals. Some documentation PDF endpoints returned HTTP 403 to direct downloads; their content was inspected through web retrieval. Only public-use mortality records were analyzed.

`docs/DESIGN_FROZEN.json` is the current integrity manifest for this publication copy. It is not the original sealed design archive. The historical design freeze occurred at 20260924T031318Z; the original archive remains in the working project. The scientific analysis parameters and results were retained. Public-document editing and portability updates to the entry points do not constitute a new outcome-blinded freeze. See [DESIGN_FREEZE.md](DESIGN_FREEZE.md).

To check the included raw files and publication manifest independently:

```sh
python3 analysis/verify_manifest.py
```

## Statistical checks

The pipeline runs `tests/test_design.R` after design diagnostics and `tests/test_results.R` after outcome estimation. After the corresponding derived outputs exist, they can also be run individually from the repository root:

```sh
Rscript tests/test_design.R
Rscript tests/test_results.R
```

The checks cover hand-calculated survey and propensity weights, 120-month boundary cases, unique joins, eligibility, outcome-free design data, covariate balance, and the weighted logistic score equations. Outcome checks independently parse the mortality files, verify exposure and event counts, check risk-difference and risk-ratio arithmetic, reconstruct JKn covariance from all 117 replicate vectors, compare survey means with direct weighted ratios, and compare Cox coefficients with a separate weighted fit.

The original complete rerun reproduced all 27 exported numerical tables byte for byte. PDF binary hashes can differ across builds because creation metadata can change. Reproduction checks validate computation; they do not establish causal identification or replace scientific review.

The replication model conditions on the frozen spline basis and propagates coefficient estimation, rather than covariate or specification selection. Original sampling weights do not correct item nonresponse. Missingness, linkage error, exposure measurement, synthetic follow-up times, and residual confounding remain interpretation limits.
