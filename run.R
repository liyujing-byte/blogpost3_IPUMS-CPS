# Open blogpost3_all_process.Rproj in RStudio, then run: source("run.R")
ROOT <- normalizePath(".", mustWork = TRUE)
stopifnot(file.exists(file.path(ROOT, "blogpost3_all_process.Rproj")))
needed <- c("data.table", "ggplot2", "jsonlite", "digest", "rmarkdown", "knitr")
missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install packages first: install.packages(c(",
  paste(sprintf('"%s"', missing), collapse = ", "), "))")
source(file.path(ROOT, "code/00_download_api.R"), encoding = "UTF-8")
# Use Quarto from PATH or the copy bundled with RStudio.
quarto_bin <- Sys.which("quarto")
if (!nzchar(quarto_bin)) {
  quarto_bin <- "/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto"
}
if (!file.exists(quarto_bin)) stop("Quarto was not found. Install Quarto or render the .qmd in RStudio.")
status <- system2(quarto_bin, c("render", "post/blogpost3.qmd", "--to", "html"))
if (status != 0L) stop("Quarto rendering failed; see the output above.")
writeLines(capture.output(sessionInfo()), file.path(ROOT, "data/processed/sessionInfo.txt"))
message("Finished: post/blogpost3.html; three figures; six aggregate CSV tables.")
