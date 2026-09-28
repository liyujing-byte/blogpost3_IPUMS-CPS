# Blog Post 3 — U.S. Labor-Force Participation

In this project, I investigate how U.S. labor-force participation changed across age groups between 2019 and 2024, and how the changing age mix affects the national comparison. I use **R** for data cleaning, weighted calculations and visualization, and **Quarto** to generate my blog post.

- [Read my blog post](https://liyujing-byte.github.io/website/blog/posts/post3/)
- [View my analysis repository](https://github.com/liyujing-byte/blogpost3_IPUMS-CPS)

## My data and API workflow

I used my personal IPUMS API key, stored locally in the `IPUMS_API_KEY` environment variable, to authenticate requests and download CPS data with the `ipumsr` package in R. On September 27, 2026, I requested and downloaded all 72 **Basic Monthly** samples from January 2019 through December 2024, excluding ASEC samples.

I selected `YEAR`, `MONTH`, `AGE`, `LABFORCE`, `WTFINL` and `ASECFLAG`, with rectangular person records, CSV output and no case restrictions. The reproducible request settings are recorded in `data/api_extract_definition.json`.

I first downloaded the same data through the IPUMS website on September 24. After switching to the API, I reran the analysis and confirmed that all six aggregate tables matched the earlier results exactly. The original download is documented in `data/extract_specification.json`; the API download receipt is stored locally in `data/raw/api/receipt.json`. The analysis audit records the acquisition method, download date and source-file hash.

My API key and raw microdata are excluded from Git. The repository contains code, aggregate results and replication instructions. Replication requires a separate IPUMS account with CPS access and a personal API key. See the [IPUMS data-use terms](https://cps.ipums.org/cps/terms.shtml) and [official R API workflow](https://tech.popdata.org/ipumsr/articles/ipums-api.html).

## Reproduce the analysis

1. Open `blogpost3_all_process.Rproj` in RStudio.
2. Install the required R packages:

```r
install.packages(c("data.table", "ggplot2", "jsonlite", "digest", "rmarkdown", "knitr", "ipumsr"))
```

3. Obtain a personal key from the [IPUMS account page](https://account.ipums.org/api_keys). Open the project-local environment file:

```r
file.edit(".Renviron")
```

Add the following line, replace the placeholder with the actual key, and save the file without running it as R code:

```text
IPUMS_API_KEY=YOUR_PERSONAL_KEY
```

The downloader reads this file automatically. `.Renviron` and its backups are ignored by Git; real keys must not be committed.

4. Run the complete workflow:

```r
source("run.R", encoding = "UTF-8")
```

This submits the extract request, waits for completion, downloads the CSV and codebook, runs the analysis, and renders `post/blogpost3.html`. Quarto must be installed; `run.R` checks the system path and the Mac RStudio bundled location.

The request number is saved locally so interrupted downloads can resume. Later runs reuse the verified API download rather than submitting another request. To request a fresh extract, first move `data/raw/api/` to a backup location. To download without rendering, run `source("code/00_download_api.R", encoding = "UTF-8")`.

Opening `post/blogpost3.qmd` and clicking **Render** recomputes the analysis without submitting an API request. It uses the completed API download if available, otherwise the original web-downloaded file at `data/raw/cps_00001.csv.gz`. The blog's numerical results, acquisition method and download date are populated from the analysis outputs.

The optional introductory script `code/01_import_check.R` checks the original web download and additionally requires `R.utils`. The complete workflow uses base R decompression instead.

## Repository structure

```text
blogpost3_all_process.Rproj       RStudio project
run.R                            Download, analyze and render
code/00_download_api.R            API authentication and download
code/analyze.R                    Weighted analysis and figures
code/01_import_check.R            Original-data import checks
post/blogpost3.qmd                Editable Quarto blog post
post/blogpost3.html               Generated standalone post
data/api_extract_definition.json  API sample and variable settings
data/extract_specification.json   Original web-extract documentation
data/data_dictionary.md          Variable definitions
data/processed/                  Aggregate tables, checks and R session information
data/raw/                        Local microdata and receipt; excluded from Git
figures/                         Three generated PNG figures
```

## My estimation method

I restrict the sample to people aged 16 or older with valid labor-force status and positive, finite `WTFINL` weights. `LABFORCE = 1` means outside the labor force and `LABFORCE = 2` means in the labor force. I reject ASEC observations. The target population is the U.S. civilian noninstitutional population aged 16+. The CSV weights are already decimal-adjusted.

For each month and age group, I calculate:

```r
100 * sum(WTFINL * (LABFORCE == 2)) / sum(WTFINL)
```

I average the twelve monthly rates to obtain each annual estimate. Annual population columns likewise contain monthly averages, not sums. I retain repeated interviews across months because these are repeated cross sections; the combined sample counts person-months, not distinct individuals.

For Figures 1 and 2, I use ages 16–24, 25–34, 35–44, 45–54, 55–64 and 65+. Figure 1 shows annual trends with separate vertical scales; Figure 2 shows changes from 2019 to 2024 in percentage points.

For Figure 3, I use fourteen narrower bands: 16–19, five-year bands from 20–24 through 75–79, and 80+. I combine each month's age-specific participation rates with population shares from the same calendar month in 2019, then average the twelve standardized rates. Actual and standardized participation therefore agree in 2019. This is an accounting comparison, not a causal estimate of population aging or a seasonal adjustment.

## My findings and checks

The raw data contain 7,582,963 person-month records. I exclude 1,411,288 records under age 16 and 25,129 age-eligible records outside the labor-force-status universe, leaving 6,146,546 observations. No further eligible records have invalid or nonpositive weights.

I find that overall participation fell from **63.40% in 2019 to 62.86% in 2024**. Holding the 2019 age mix fixed, the 2024 estimate is **63.96%**. The population share aged 65+ rose from **20.40% to 22.23%**. These results show why age-specific recovery can coexist with a lower national participation rate.

My script checks coverage of all 72 months, valid rate ranges, agreement between broad and narrow age-group totals, plausible population totals and the 2019 standardization identity. I also verified that the API-based aggregate tables matched the original analysis. Validation results and package versions are saved in `data/processed/`.

My analysis is descriptive. It does not follow a fixed cohort or identify individual retirement decisions. Within-band composition changes, population-control updates, pandemic nonresponse and repeated interviews limit interpretation. I do not report naive confidence intervals or significance claims. The estimates use `WTFINL` and are not seasonally adjusted; exact replication of published BLS estimates instead uses composite weights.

## Sources

I use IPUMS CPS, University of Minnesota, Basic Monthly microdata for January 2019–December 2024, downloaded through the API on September 27, 2026. The underlying CPS data are provided by the U.S. Census Bureau and Bureau of Labor Statistics.

- [IPUMS CPS](https://cps.ipums.org/cps/)
- [WTFINL](https://cps.ipums.org/cps-action/variables/WTFINL)
- [LABFORCE](https://cps.ipums.org/cps-action/variables/LABFORCE)
- [AGE and topcoding](https://cps.ipums.org/cps-action/variables/AGE)
- [COMPWT and BLS replication](https://cps.ipums.org/cps-action/variables/COMPWT)
- [Pandemic data collection](https://cps.ipums.org/cps/covid19.shtml)
- [Citation guidance](https://cps.ipums.org/cps/citation.shtml)
