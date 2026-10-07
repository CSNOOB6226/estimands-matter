# Estimands Matter

A reproducible methodological reanalysis of baseline muscle-strengthening activity and 10-year all-cause mortality in NHANES 1999–2006, linked to the public 2019 mortality files. The analysis compares population-average (PATE) and overlap-population (PATO) associations using survey and propensity weights.

The complete-case sample contains 15,091 adults and 1,980 ten-year deaths. Both adjusted risk differences are close to zero, with intervals compatible with lower or higher mortality. The two weighting approaches describe different covariate distributions and produce different absolute risks. See [the research report](report/Estimands_Matter_Report.md), [the protocol](docs/PROTOCOL.md), and [the analysis plan](docs/ANALYSIS_PLAN.md).

## Run the analysis

Install Python 3.10 or later, R, and the project dependencies, then run these commands from the repository root:

```sh
python3 -m pip install -r requirements.txt
Rscript install_packages.R
python3 run_project.py
```

The original public data files are included in `data/raw`. To download or validate the official originals before running, use `python3 run_project.py --download`. To run the statistical analysis and checks without rebuilding the reports, use `python3 run_project.py --no-report`.

R packages: `survey`, `survival`, `foreign`, and `ggplot2`; `splines` and `stats` are supplied with R. Python report dependencies: `reportlab`, `pypdf`, and `Pillow`. Installation and validation details are in [REPRODUCIBILITY.md](REPRODUCIBILITY.md).

## Repository contents

- `R/` and `run_all.R`: data preparation, design diagnostics, risk estimation, Cox models, and figures.
- `analysis/` and `run_project.py`: public-data downloads, integrity checks, and report generation.
- `data/raw/` and `data/download_manifest.csv`: original public data, source URLs, sizes, and SHA-256 checksums.
- `outputs/tables/` and `outputs/figures/`: 27 result tables and 10 figures, including sample flow, balance, weights, risks, and sensitivity analyses.
- `report/`: research report in editable Markdown and PDF.
- `docs/`, [VARIABLE_DICTIONARY.md](VARIABLE_DICTIONARY.md), and [MISSING_DATA_PLAN.md](MISSING_DATA_PLAN.md): study design, variable definitions, and interpretation limits.
- [SOURCE_LOG.md](SOURCE_LOG.md): official data documentation and original methodological and clinical references.
- `tests/`: separate design and outcome checks.

## Interpretation

These estimates describe adjusted associations with a baseline report of activity. PATE refers to the survey-weighted complete-case response domain; PATO further emphasizes covariate profiles with exposure overlap. Complete-case selection, exclusion of people reporting inability, broad behavioural measures, reverse causation, unmeasured confounding, and synthetic follow-up times limit interpretation. The analysis does not identify the effect of sustained training or establish that activity has no mortality benefit.

The historical design freeze and the current publication-copy integrity manifest are described in [DESIGN_FREEZE.md](DESIGN_FREEZE.md).
