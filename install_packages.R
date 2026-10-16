# Install missing R dependencies from CRAN.
packages <- c("survey", "survival", "foreign", "ggplot2")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly=TRUE)]
if (length(missing)) install.packages(missing, repos="https://cloud.r-project.org")
cat("R dependencies are available.\n")
