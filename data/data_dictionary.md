# Analysis data dictionary

This is a project-specific summary, not the original IPUMS DDI. The original CSV header contains twelve variables; six are read by the analysis.

| Variable | Meaning | Use |
|---|---|---|
| YEAR | Survey year | Restrict to 2019–2024 |
| MONTH | Calendar month, 1–12 | Calculate each month separately; check 72-month coverage |
| AGE | Age at last birthday | Restrict to 16+; construct broad and fine age bands |
| LABFORCE | 0 = not in universe; 1 = not in labor force; 2 = in labor force | Keep 1 or 2; count code 2 in numerator |
| WTFINL | Final Basic person weight | Weight all population rates and shares |
| ASECFLAG | 1 = ASEC; 2 = March Basic Monthly; blank outside applicable samples | Reject any ASEC records |

Other automatically included variables (`SERIAL`, `HWTFINL`, `CPSID`, `PERNUM`, `CPSIDP`, `CPSIDV`) are preserved in the original download but not used in the calculations. `HWTFINL` is a household weight and is not substituted for the person weight.

The CSV records already contain decimal-adjusted weights, e.g., a value of 1882.8985 represents that many people. A record is one person in one month's survey, not a unique person over the six-year period.

For these years, ages 80–84 are coded 80 and ages 85+ are coded 85. The 80+ fine band and 65+ broad band accommodate both values.

Official documentation:

- https://cps.ipums.org/cps-action/variables/YEAR
- https://cps.ipums.org/cps-action/variables/MONTH
- https://cps.ipums.org/cps-action/variables/AGE
- https://cps.ipums.org/cps-action/variables/LABFORCE
- https://cps.ipums.org/cps-action/variables/WTFINL
- https://cps.ipums.org/cps-action/variables/ASECFLAG
