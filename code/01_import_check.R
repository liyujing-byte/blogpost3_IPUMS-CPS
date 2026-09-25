# Run from the blogpost3_all_process RStudio project.
# Counts are sample diagnostics, not weighted population estimates.
library(data.table)
input_file <- "data/raw/cps_00001.csv.gz"
stopifnot(file.exists(input_file))
cps <- fread(input_file, select = c("YEAR", "MONTH", "AGE", "LABFORCE", "WTFINL", "ASECFLAG"))
stopifnot(!any(cps$ASECFLAG == 1, na.rm = TRUE))
coverage <- cps[, .(sample_rows = .N), by = .(YEAR, MONTH)][order(YEAR, MONTH)]
stopifnot(nrow(coverage) == 72L, setequal(coverage$YEAR, 2019:2024),
          all(coverage[, .N, by = YEAR]$N == 12L), all(coverage$MONTH %in% 1:12))
# LABFORCE: 0 = NIU, 1 = not in labor force, 2 = in labor force.
cps_clean <- cps[!is.na(AGE) & AGE >= 16 & LABFORCE %in% c(1, 2) &
                   is.finite(WTFINL) & WTFINL > 0]
cps_clean[, in_labor_force := as.integer(LABFORCE == 2)]
cps_clean[, age_group := cut(AGE, breaks = c(16, 25, 35, 45, 55, 65, Inf),
                             right = FALSE,
                             labels = c("16-24", "25-34", "35-44", "45-54", "55-64", "65+"))]
stopifnot(!anyNA(cps_clean$age_group))
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
fwrite(coverage, "data/processed/sample_coverage.csv")
checks <- data.table(check = c("Raw person-month rows", "Analysis person-month rows", "Monthly samples"),
                     value = c(nrow(cps), nrow(cps_clean), nrow(coverage)))
fwrite(checks, "data/processed/data_checks.csv")
print(checks)
print(coverage[, .(months = .N, sample_rows = sum(sample_rows)), by = YEAR])
cat("\nChecks passed. cps_clean is ready for weighted analysis.\n")
