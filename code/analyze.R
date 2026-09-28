# Analysis and plots, entirely in R. ROOT is set by run.R or the R Markdown setup.
library(data.table)
library(ggplot2)
if (!exists("ROOT")) ROOT <- normalizePath(".")
input <- file.path(ROOT, "data/raw/cps_00001.csv.gz")
# Prefer only a completed API download; retain the original web extract as fallback
# for standalone Render until the first API download is complete.
receipt_file <- file.path(ROOT, "data/raw/api/receipt.json")
if (file.exists(receipt_file)) {
  receipt <- jsonlite::read_json(receipt_file, simplifyVector = TRUE)
  input <- file.path(ROOT, "data/raw/api", receipt$file)
  stopifnot(file.exists(input), identical(digest::digest(file = input, algo = "sha256"), receipt$sha256))
}
stopifnot(file.exists(input))
dir.create(file.path(ROOT, "data/processed"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(ROOT, "figures"), recursive = TRUE, showWarnings = FALSE)

# Read only required columns. fread's gzip support uses R.utils when available.
# Uncompress to a temporary file with base R to avoid an extra package dependency.
tmp <- tempfile(fileext = ".csv")
con_in <- gzfile(input, "rb")
con_out <- file(tmp, "wb")
repeat {
  block <- readBin(con_in, "raw", n = 1024L * 1024L)
  if (!length(block)) break
  writeBin(block, con_out)
}
close(con_in); close(con_out)
d <- fread(tmp, select = c("YEAR", "MONTH", "AGE", "LABFORCE", "WTFINL", "ASECFLAG"))
unlink(tmp)
stopifnot(!any(d$ASECFLAG == 1, na.rm = TRUE), all(d$MONTH %in% 1:12),
          all(d$AGE >= 0 & d$AGE <= 99), all(d$YEAR %in% 2019:2024))
audit <- list(input_rows = nrow(d), under_16 = sum(d$AGE < 16),
              invalid_status_age16plus = sum(d$AGE >= 16 & !d$LABFORCE %in% c(1, 2)),
              invalid_weight_eligible = sum(d$AGE >= 16 & d$LABFORCE %in% c(1, 2) &
                                           (!is.finite(d$WTFINL) | d$WTFINL <= 0)))
d <- d[AGE >= 16 & LABFORCE %in% c(1, 2) & is.finite(WTFINL) & WTFINL > 0]
audit$included_person_months <- nrow(d)
# Do not deduplicate across months: these are repeated cross-sectional estimates.
# CSV weights already have decimal places; do not divide by 10,000.
groups <- c("16–24", "25–34", "35–44", "45–54", "55–64", "65+")
fine_labels <- c("16–19", paste0(seq(20, 75, 5), "–", seq(24, 79, 5)), "80+")
d[, age_group := cut(AGE, c(16, 25, 35, 45, 55, 65, 100), labels = groups, right = FALSE)]
d[, fine_age := cut(AGE, c(16, seq(20, 80, 5), 100), labels = fine_labels, right = FALSE)]
d[, weighted_lf := WTFINL * (LABFORCE == 2)]
summarize_group <- function(column) {
  x <- d[, .(population = sum(WTFINL), labor_force = sum(weighted_lf), n = .N),
         by = c("YEAR", "MONTH", column)]
  setnames(x, column, "group")
  x[, group := as.character(group)]
  x[, lfpr_pct := 100 * labor_force / population]
  setorder(x, YEAR, MONTH, group)
  x
}
broad <- summarize_group("age_group")
fine <- summarize_group("fine_age")
rm(d); invisible(gc())
stopifnot(nrow(broad) == 72 * 6, nrow(fine) == 72 * 14,
          all(broad[, .N, by = .(YEAR, MONTH)]$N == 6),
          all(fine[, .N, by = .(YEAR, MONTH)]$N == 14),
          all(fine$population > 0), all(fine$lfpr_pct >= 0 & fine$lfpr_pct <= 100))
monthly <- broad[, .(population = sum(population), labor_force = sum(labor_force), n = sum(n)), by = .(YEAR, MONTH)]
check <- fine[, .(population = sum(population), labor_force = sum(labor_force), n = sum(n)), by = .(YEAR, MONTH)]
stopifnot(isTRUE(all.equal(monthly, check, tolerance = 1e-10)),
          all(monthly$population > 200e6 & monthly$population < 350e6))
monthly[, actual_pct := 100 * labor_force / population]
fine[, share := population / sum(population), by = .(YEAR, MONTH)]
base <- fine[YEAR == 2019, .(MONTH, group, share_2019 = share)]
fixed <- merge(fine, base, by = c("MONTH", "group"), all.x = TRUE)
fixed <- fixed[, .(fixed_age_pct = sum(share_2019 * lfpr_pct)), by = .(YEAR, MONTH)]
monthly <- merge(monthly, fixed, by = c("YEAR", "MONTH"))
old <- broad[group == "65+", .(YEAR, MONTH, old_population = population)]
monthly <- merge(monthly, old, by = c("YEAR", "MONTH"))
monthly[, share_65plus_pct := 100 * old_population / population]
monthly[, old_population := NULL]
stopifnot(max(abs(monthly[YEAR == 2019, actual_pct - fixed_age_pct])) < 1e-10)
annual <- broad[, .(lfpr_pct = mean(lfpr_pct), average_monthly_population = mean(population),
                    average_monthly_sample_n = mean(n)), by = .(YEAR, group)]
overall <- monthly[, lapply(.SD, mean), by = YEAR, .SDcols = setdiff(names(monthly), c("YEAR", "MONTH"))]
change <- dcast(annual, group ~ YEAR, value.var = "lfpr_pct")
change[, change_pp := `2024` - `2019`]
change <- change[match(groups, group)]
tables <- list(monthly_by_age = broad, monthly_fine_age = fine, annual_by_age = annual,
               monthly_overall = monthly, annual_overall = overall, changes_2019_2024 = change)
for (name in names(tables)) fwrite(tables[[name]], file.path(ROOT, "data/processed", paste0(name, ".csv")))
audit$months <- nrow(monthly)
audit$minimum_monthly_population <- min(monthly$population)
audit$maximum_monthly_population <- max(monthly$population)
audit$minimum_fine_band_sample_n <- min(fine$n)
audit$source_sha256 <- digest::digest(file = input, algo = "sha256")
audit$acquisition_method <- if (file.exists(receipt_file)) "IPUMS API" else "IPUMS website"
audit$download_date <- if (file.exists(receipt_file)) receipt$downloaded_on else "2026-09-24"
audit$R_version <- R.version.string
audit$checks <- "72 complete months; valid rates; broad/fine totals reconcile; 2019 standardization identity; plausible weight scale"
jsonlite::write_json(audit, file.path(ROOT, "data/processed/validation.json"), pretty = TRUE, auto_unbox = TRUE, digits = 15)

# Visualizations. Colors remain consistent across the age-group charts.
colors <- setNames(c("#007F87", "#2A5B9A", "#65549B", "#A75375", "#B56F27", "#486E3A"), groups)
source_note <- "Source: IPUMS CPS Basic Monthly, 2019–2024; calculations using WTFINL."
theme_set(theme_minimal(base_size = 12) + theme(
  panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
  plot.title = element_text(face = "bold", size = 18, color = "#172B3A"),
  plot.subtitle = element_text(size = 11, margin = margin(b = 16)),
  plot.caption = element_text(hjust = 0, size = 9, color = "#52606D", margin = margin(t = 15)),
  plot.title.position = "plot", plot.caption.position = "plot", legend.position = "bottom",
  plot.margin = margin(22, 25, 20, 22), strip.text = element_text(face = "bold", size = 12)))
annual[, group := factor(group, levels = groups)]
change[, group := factor(group, levels = groups)]
p1 <- ggplot(annual, aes(YEAR, lfpr_pct, color = group)) +
  geom_hline(data = annual[YEAR == 2019], aes(yintercept = lfpr_pct), color = "#B7C0C7", linetype = "dashed") +
  geom_line(linewidth = 1) + geom_point(size = 2.4) +
  geom_text(data = annual[YEAR == 2024], aes(label = sprintf("%.1f%%", lfpr_pct)), vjust = -1, show.legend = FALSE, size = 3.5) +
  facet_wrap(~group, scales = "free_y", ncol = 3, labeller = labeller(group = function(x) paste("Ages", x))) +
  scale_color_manual(values = colors, guide = "none") +
  scale_x_continuous(breaks = c(2019, 2021, 2024), expand = expansion(mult = c(.05, .13))) +
  scale_y_continuous(expand = expansion(mult = c(.15, .28))) +
  labs(title = "Labor-force participation recovered unevenly across ages",
       subtitle = "Annual mean of monthly weighted rates • U.S. civilian noninstitutional population",
       x = NULL, y = "Labor-force participation (%)",
       caption = paste("Panels use different vertical scales. Dashed lines mark 2019 rates. Not seasonally adjusted.", source_note, sep = "\n"))
p2 <- ggplot(change, aes(change_pp, group, fill = group)) + geom_col(width = .6) +
  geom_vline(xintercept = 0, color = "#52606D") +
  geom_text(aes(label = sprintf("%+.2f", change_pp), hjust = ifelse(change_pp >= 0, -.2, 1.2)), size = 4) +
  scale_fill_manual(values = colors, guide = "none") + scale_y_discrete(limits = rev(groups)) +
  scale_x_continuous(expand = expansion(mult = .20)) +
  labs(title = "Who was above the pre-pandemic baseline in 2024?", subtitle = "Changes in annual mean weighted rates, by age group",
       x = "Change in participation rate, 2019 to 2024 (percentage points)", y = "Age group",
       caption = paste("Descriptive point estimates; no confidence intervals or significance claims.", source_note, sep = "\n")) +
  theme(panel.grid.major.x = element_line(color = "#E8EDF1"), panel.grid.major.y = element_blank())
long <- melt(overall, id.vars = "YEAR", measure.vars = c("actual_pct", "fixed_age_pct"), variable.name = "series", value.name = "rate")
p3a <- ggplot(long, aes(YEAR, rate, color = series)) + geom_line(linewidth = 1.2) + geom_point(size = 2.5) +
  geom_text(data = long[YEAR == 2024], aes(label = sprintf("%.2f%%", rate)), vjust = -1, show.legend = FALSE) +
  scale_color_manual(values = c(actual_pct = "#2A5B9A", fixed_age_pct = "#007F87"),
                     labels = c(actual_pct = "Actual age mix", fixed_age_pct = "2019 age mix"), name = NULL) +
  scale_x_continuous(breaks = 2019:2024, expand = expansion(mult = c(.06, .16))) +
  scale_y_continuous(expand = expansion(mult = c(.1, .25))) +
  labs(title = "Participation with and without the age shift", x = NULL, y = "Participation (%)") +
  theme(plot.title = element_text(size = 13, face = "bold"), plot.margin = margin(10, 15, 10, 10))
p3b <- ggplot(overall, aes(YEAR, share_65plus_pct)) + geom_line(color = "#486E3A", linewidth = 1.2) +
  geom_point(color = "#486E3A", size = 2.5) +
  geom_text(data = overall[YEAR %in% c(2019, 2024)], aes(label = sprintf("%.1f%%", share_65plus_pct)), vjust = -1, color = "#486E3A") +
  scale_x_continuous(breaks = c(2019, 2021, 2024), expand = expansion(mult = c(.15, .16))) +
  scale_y_continuous(expand = expansion(mult = c(.1, .25))) +
  labs(title = "The population share aged 65+ grew", x = NULL, y = "Share of population aged 16+ (%)") +
  theme(plot.title = element_text(size = 13, face = "bold"), plot.margin = margin(10, 15, 10, 10))
figdir <- file.path(ROOT, "figures")
for (ext in "png") {
  ggsave(file.path(figdir, paste0("figure1_age_trends.", ext)), p1, width = 12, height = 7.6, dpi = 200, bg = "white")
  ggsave(file.path(figdir, paste0("figure2_changes.", ext)), p2, width = 11, height = 6.5, dpi = 200, bg = "white")
  name <- file.path(figdir, paste0("figure3_age_composition.", ext))
  png(name, width = 2400, height = 1300, res = 200)
  grid::grid.newpage()
  grid::grid.text("An older population weighs on overall participation", x = .035, y = .95, just = "left",
                  gp = grid::gpar(fontsize = 19, fontface = "bold", col = "#172B3A"))
  grid::grid.text("Adults aged 16+ • Annual means of monthly weighted estimates", x = .035, y = .89, just = "left", gp = grid::gpar(fontsize = 11))
  print(p3a, vp = grid::viewport(x = .31, y = .51, width = .58, height = .67))
  print(p3b, vp = grid::viewport(x = .79, y = .51, width = .40, height = .67))
  note <- paste("Fixed-age series uses 2019 shares for the same calendar month across 14 age bands (16–19, five-year bands, 80+).",
    "An accounting comparison, not a causal estimate. Vertical axes are truncated. Not seasonally adjusted.", source_note, sep = "\n")
  grid::grid.text(note, x = .035, y = .065, just = "left", gp = grid::gpar(fontsize = 9, col = "#52606D", lineheight = 1.4))
  dev.off()
}
print(overall[, .(YEAR, actual_pct, fixed_age_pct, share_65plus_pct)])
print(change[, .(group, `2019`, `2024`, change_pp)])
