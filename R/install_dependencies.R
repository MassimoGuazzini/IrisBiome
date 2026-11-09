# Install dependencies used by the public reporter and unchanged DADA2 script.
cran_packages <- c("optparse", "openxlsx", "vegan", "ggplot2", "data.table", "gridExtra", "officer", "flextable", "magick", "jsonlite")
bioc_packages <- c("dada2", "ShortRead", "Biostrings")
missing <- function(packages) packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing(cran_packages))) install.packages(missing(cran_packages), repos = "https://cloud.r-project.org")
if (length(missing(bioc_packages))) {
  if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager", repos = "https://cloud.r-project.org")
  BiocManager::install(missing(bioc_packages), ask = FALSE, update = FALSE)
}
still_missing <- missing(c(cran_packages, bioc_packages))
if (length(still_missing)) stop("IrisBiome dependencies incomplete. Missing: ", paste(still_missing, collapse = ", "))
cat("IrisBiome public dependencies available.\n")
