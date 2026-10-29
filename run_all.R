# Run from the project root. Raw downloads are handled by run_project.py.
stopifnot(file.exists("docs/PROTOCOL.md"), file.exists("docs/DESIGN_FROZEN.json"))

# Create the folders used by the analysis stages.
for (path in c("data/derived", "outputs/tables", "outputs/figures", "logs")) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
}
stages <- c(
  "R/01_design_data.R",
  "R/02_design_diagnostics.R",
  "tests/test_design.R",
  "R/03_outcomes.R",
  "R/04_cox.R",
  "R/05_result_figures.R",
  "tests/test_results.R"
)

# Run each stage separately and keep its output for checking failures.
for (stage in stages) {
  cat("Running", stage, "\n")
  log_path <- file.path("logs", paste0("rerun_", sub("\\.R$", "", basename(stage)), ".log"))
  status <- system2(
    file.path(R.home("bin"), "Rscript"), stage,
    stdout = log_path, stderr = log_path
  )
  if (status != 0) {
    stop("Stage failed: ", stage, "; inspect ", log_path)
  }
}
cat("All statistical stages passed.\n")
