# Blog Post 3 — R project

How did U.S. labor-force participation change across age groups between 2019 and 2024, and what role did the changing age mix play in the overall comparison?

All data cleaning, weighted calculations, tables, figures and post generation are implemented in **R**. The post is a **Quarto** document. No Python installation is needed.

## Start in RStudio

1. Open `blogpost3_all_process.Rproj` in RStudio. This sets the project working directory.
2. Configure your personal IPUMS API key locally as described below. `run.R` now requests and downloads the data through the API before analysis. Raw microdata and credentials are excluded from Git.
3. If necessary, install these packages in the RStudio Console:

```r
install.packages(c("data.table", "ggplot2", "jsonlite", "digest", "rmarkdown", "knitr", "ipumsr"))
```

4. Run:

```r
source("run.R", encoding = "UTF-8")
```

5. Open `post/blogpost3.html` to read the finished post with embedded figures. The three PNG files are also in `figures/`.

Alternatively, open `post/blogpost3.qmd` and click **Render**. By default it recomputes the analysis from raw data before rendering. Quarto is required; this Mac uses the Quarto CLI bundled with RStudio. At a terminal, from the project root, run `Rscript run.R`.

To follow the analysis line by line, open `code/analyze.R`, set `ROOT <- normalizePath(".")` in the Console while in the project root, and execute code sections with Command+Enter (Mac) or Ctrl+Enter (Windows). Read the comments before each section. The raw-data read loads approximately 7.6 million rows, so allow a few minutes and adequate memory.

The introductory `code/01_import_check.R` script additionally uses `R.utils` to read gzip files directly. The complete `run.R` workflow uses base R decompression and does not require it.

## Personal API setup (local only)

Your IPUMS account must have access to CPS. Obtain your own key at
<https://account.ipums.org/api_keys>. Never paste a real key into an R script,
GitHub, a screenshot, or a chat.

In the project RStudio Console, open the local environment file:

```r
file.edit(".Renviron")
```

Add this line in the editor, replacing the placeholder with your actual key, and save:

```text
IPUMS_API_KEY=YOUR_PERSONAL_KEY
```

The downloader reads this file automatically, so no restart is required. It never
prints the key. `.Renviron` and its backups are ignored by Git.

Run `source("run.R", encoding = "UTF-8")` to submit the 72 Basic Monthly samples,
wait, download the CSV and codebook, then recompute and render. The new files go to
`data/raw/api/`; the original website download is preserved. The request number
is saved immediately, so an interrupted run can resume. A completion receipt
records the actual download date and SHA-256. Later runs reuse the verified API
file instead of making another extract. To intentionally request a new extract,
move `data/raw/api/` to a backup location first.

To download only: `source("code/00_download_api.R", encoding = "UTF-8")`.
Direct Quarto Render does not submit API requests: it uses the completed API
file if present, otherwise the original web download. The authenticated API extract was downloaded and the full analysis rerun on
September 27, 2026. All six aggregate tables matched the original web-download
results exactly. The original `data/extract_specification.json` describes the
September 24 web extract; the API receipt describes the subsequent download.
The Quarto blog reads the acquisition method and date from the analysis audit automatically. Republish only after verifying new results.

Official workflow: <https://tech.popdata.org/ipumsr/articles/ipums-api.html>.

## Files

```text
blogpost3_all_process.Rproj              RStudio project
run.R                       Run analysis and render the post
code/00_download_api.R      Authenticated API request and download
code/analyze.R              Read, filter, weight, aggregate and plot
post/blogpost3.qmd          Render-ready Quarto document
post/blogpost3.html          Generated self-contained HTML
data/raw/                   Original microdata, excluded from Git
data/processed/             Six generated aggregate CSV tables
data/extract_specification.json  Exact sample and variable selection
data/data_dictionary.md      Used variable definitions
figures/            Three PNG figures
data/processed/validation.json     Counts, validation checks and source hash
data/processed/sessionInfo.txt     R and package versions used
```

To change the prose, edit `post/blogpost3.qmd` and click Render, or run `run.R`. Inline R expressions keep numerical results synchronized with the data. The `post` folder contains only the editable Quarto source and the generated HTML webpage.

## Obtain the same data

Use a registered [IPUMS CPS](https://cps.ipums.org/cps/) account. Deselect default samples; choose **cross-sectional Basic Monthly**, all twelve months for **2019–2024**, and **zero ASEC** samples. Add `AGE` and `LABFORCE`; confirm `YEAR`, `MONTH`, `WTFINL` and `ASECFLAG` are included. Choose rectangular person records and CSV format with no case restrictions. The default identifier and household-weight variables can remain. Save the gzip-compressed file under the input filename above.

The source hash and exact extract settings are in `data/extract_specification.json`. A later IPUMS revision may change the file hash or estimates. The original XML download was blocked by the in-app browser and is not required to analyze the CSV; official variable definitions are linked in the included data dictionary.

Raw respondent-level data are excluded from Git under [IPUMS redistribution terms](https://cps.ipums.org/cps/terms.shtml). Other users obtain their own extract. The repository includes aggregate results, code and extraction instructions.

## Estimation

Retain people aged 16+ with `LABFORCE` equal to 1 or 2 and finite positive `WTFINL`. Code 1 is not in the labor force; code 2 is in the labor force. ASEC observations are rejected. The target population is the U.S. civilian noninstitutional population aged 16+. The CSV weights already have decimal places and must not be divided by 10,000.

For each age group and each month:

```r
100 * sum(WTFINL * (LABFORCE == 2)) / sum(WTFINL)
```

Annual estimates are arithmetic means of twelve monthly weighted rates. Annual population columns are means of monthly weighted populations, not sums. This estimator differs slightly from the ratio of annual mean counts. Unweighted sample counts are diagnostic only. Do not deduplicate people across months: repeat interviews are legitimate repeated cross sections, and the combined sample is a count of person-months rather than distinct people.

**Figures 1 and 2:** use groups 16–24, 25–34, 35–44, 45–54, 55–64 and 65+. Figure 1 uses explicitly noted separate vertical scales; Figure 2 compares 2024 minus 2019 in percentage points.

**Figure 3:** use 14 narrower bands: 16–19; five-year bands 20–24 through 75–79; and 80+. The last band accommodates CPS topcoding. For each month, multiply that year's band-specific rates by the population shares from the **same calendar month in 2019**, sum over bands, and average the twelve standardized monthly rates. Thus actual and fixed-age estimates agree exactly in 2019. This is not seasonal adjustment.

The 2024 standardized-minus-actual gap evaluates the age-share difference at 2024 age-specific rates. It is an accounting comparison, not a causal estimate or a uniquely defined aging effect. Other reference years, band widths or decomposition orderings can give different contributions.

## Results, checks and limitations

The raw file contains 7,582,963 rows. The analytic sample has 6,146,546 person-months: exclude 1,411,288 people under 16 and 25,129 age-eligible observations outside the labor-force-status universe. No further eligible records have invalid or nonpositive weights.

Actual annual participation is 63.40% in 2019 and 62.86% in 2024. At the 2019 age mix, the 2024 estimate is 63.96%. The population share aged 65+ rises from 20.40% to 22.23%.

The script checks complete age-band coverage in all 72 months, valid rate ranges, agreement between broad and fine totals, plausible population scale, and the 2019 standardization identity. All six R-generated aggregate tables were independently compared with the previous implementation and agreed within floating-point tolerance. Figures were visually reviewed. R/package versions are saved in `data/processed/sessionInfo.txt`.

This is descriptive analysis. It does not follow a fixed cohort or identify retirement decisions. Within-band composition changes, annual population-control updates, pandemic nonresponse and repeated interviews limit interpretation. No naive confidence intervals or significance claims are made. Exact replication of BLS published labor-force estimates uses `COMPWT`; `WTFINL` is appropriate for this Basic Monthly person-level descriptive analysis. The series are not seasonally adjusted.

## Sources

IPUMS CPS, University of Minnesota, https://cps.ipums.org/cps/ . Basic Monthly microdata, January 2019–December 2024, downloaded September 24, 2026. Underlying CPS data are provided by the U.S. Census Bureau and Bureau of Labor Statistics.

- [WTFINL](https://cps.ipums.org/cps-action/variables/WTFINL)
- [LABFORCE](https://cps.ipums.org/cps-action/variables/LABFORCE)
- [AGE and topcoding](https://cps.ipums.org/cps-action/variables/AGE)
- [COMPWT and BLS replication](https://cps.ipums.org/cps-action/variables/COMPWT)
- [Pandemic data collection](https://cps.ipums.org/cps/covid19.shtml)
- [Citation guidance](https://cps.ipums.org/cps/citation.shtml)

## Submission

Submit the published blog URL together with this repository: https://github.com/liyujing-byte/blogpost3_IPUMS-CPS. The rendered HTML in this repository is a standalone copy; website publication is a separate step.
