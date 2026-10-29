# Check which analysis packages are missing.
packages <- c("survey", "survival", "foreign", "ggplot2")
missing_packages <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]

# Install only the missing packages from CRAN.
if (length(missing_packages)) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}
cat("R dependencies are available.\n")
