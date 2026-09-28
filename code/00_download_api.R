# Run from the RStudio project root. Never put a key in this script.
download_cps_api <- function(root = normalizePath(".")) {
  env_file <- file.path(root, ".Renviron")
  if (file.exists(env_file)) readRenviron(env_file)
  if (!nzchar(Sys.getenv("IPUMS_API_KEY"))) {
    stop("Set IPUMS_API_KEY in your local .Renviron first. See README. Do not share the key.")
  }
  if (!requireNamespace("ipumsr", quietly = TRUE)) {
    stop('Install ipumsr first: install.packages("ipumsr")')
  }
  if (!requireNamespace("jsonlite", quietly = TRUE) ||
      !requireNamespace("digest", quietly = TRUE)) stop("Install jsonlite and digest first.")
  folder <- file.path(root, "data/raw/api")
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
  receipt <- file.path(folder, "receipt.json")
  if (file.exists(receipt)) {
    saved <- jsonlite::read_json(receipt, simplifyVector = TRUE)
    csv <- file.path(folder, saved$file)
    if (file.exists(csv) && identical(digest::digest(file = csv, algo = "sha256"), saved$sha256)) {
      message("Using verified cached API download.")
      return(invisible(csv))
    }
    stop("Cached API file is missing or changed. Restore it or move data/raw/api aside before retrying.")
  }
  # Save only the request number locally; reruns resume instead of submitting duplicates.
  number_file <- file.path(folder, "request_number.txt")
  if (file.exists(number_file)) {
    number <- trimws(readLines(number_file, warn = FALSE))
    stopifnot(length(number) == 1L, grepl("^[0-9]+$", number))
    request <- ipumsr::get_extract_info(paste0("cps:", number))
  } else {
    available <- ipumsr::get_sample_info("cps")
    expected <- unlist(lapply(2019:2024, function(y) paste0("IPUMS-CPS, ", month.name, " ", y)))
    if (!all(c("name", "description") %in% names(available)) ||
        !all(vapply(expected, function(x) sum(available$description == x), integer(1)) == 1L)) {
      stop("Metadata must identify exactly one Basic Monthly sample for each of the 72 months.")
    }
    samples <- available$name[match(expected, available$description)]
    stopifnot(length(unique(samples)) == 72L)
    definition <- ipumsr::define_extract_micro(
      collection = "cps",
      description = "Blog Post 3: Basic Monthly 2019-2024, age and labor-force participation",
      samples = samples,
      variables = c("YEAR", "MONTH", "AGE", "LABFORCE", "WTFINL", "ASECFLAG"),
      data_format = "csv", data_structure = "rectangular", rectangular_on = "P"
    )
    request <- ipumsr::submit_extract(definition)
    writeLines(as.character(request$number), number_file)
  }
  ready <- ipumsr::wait_for_extract(request, initial_delay_seconds = 10,
                                   max_delay_seconds = 30, timeout_seconds = 3600)
  # Share only reproducible selection settings, never authentication or download URLs.
  jsonlite::write_json(list(collection = "cps", samples = names(ready$samples),
    variables = names(ready$variables), data_format = "csv", data_structure = "rectangular",
    rectangular_on = "P", case_selection = "none"),
    file.path(root, "data/api_extract_definition.json"), auto_unbox = TRUE, pretty = TRUE)
  ipumsr::download_extract(ready, download_dir = folder, overwrite = TRUE)
  csv <- list.files(folder, pattern = "\\.csv\\.gz$", full.names = TRUE)
  if (length(csv) != 1L || file.info(csv)$size == 0) stop("Expected exactly one nonempty CSV.gz download.")
  # Write a completion receipt only after a successful download. No credentials or signed URLs.
  jsonlite::write_json(list(method = "IPUMS API", extract_number = as.character(ready$number),
    downloaded_on = as.character(Sys.Date()), file = basename(csv),
    sha256 = digest::digest(file = csv, algo = "sha256")), receipt, auto_unbox = TRUE, pretty = TRUE)
  message("API download complete. The analysis will now use this file.")
  invisible(csv)
}
ROOT <- normalizePath(".", mustWork = TRUE)
stopifnot(file.exists(file.path(ROOT, "blogpost3_all_process.Rproj")))
download_cps_api(ROOT)
