# FX Time Range Breakout

Historical FX backtest analysis with **Python, pandas, MySQL, Power BI and DAX**.

This repository accompanies the 14-page report with the processed study inputs,
a Python walkthrough, MySQL scripts, and the Power BI model diagram and DAX.

[Read the case study](https://alex-karam.github.io/projects/fx-time-range-breakout/index.html)
· [View the report](https://alex-karam.github.io/projects/fx-time-range-breakout/fx-time-range-breakout-report.pdf)

## Research question

Do JPY-linked currency pairs show broader and more locally consistent historical
breakout profitability than other pairs?

This personal research project examines regions of parameter behaviour, including
losing configurations, rather than selecting a single highest-profit backtest.

## Workflow and tool contributions

1. **MT5:** generate optimization exports for alternative strategy configurations.
2. **Python / pandas:** parse XML, verify source hashes and parameter grids,
   preserve missing values, prepare import files and generate analysis figures.
3. **MySQL:** store scan metadata and results in related tables, validate control
   totals, and query pair groups, reporting metrics and neighbouring settings.
4. **Power BI / DAX:** import MySQL results, build relationships and measures,
   create native comparison visuals, and assemble the report with Python figures.
5. **Validation:** reconcile selected Python, SQL and reporting outputs and check
   the exported PDF's tables, figures and captions.

The heatmaps are Python-generated images embedded in Power BI. The Power BI model,
DAX measures and native visuals provide separate evidence of the reporting work.

## Study design

### Original 28-pair study

- **Universe:** 28 FX pairs: seven JPY-linked pairs and 21 non-JPY pairs.
- **Date inputs:** 1 May 2018 to 31 August 2026.
- **Environment:** CapitalPointTrading-MT5-4; 1-minute OHLC modelling; EUR account basis.
- **Strategy:** stop loss at 100% of the range; both breakout modes.
- **Grid:** range starts, durations and scheduled exits varied in 30-minute steps.
- **Control totals:** 318,136 optimization rows; 286,832 eligible configurations;
  49,920 profitable configurations, giving 17.40% profitable-setting coverage.

Eligibility requires at least 120 scheduled minutes between range end and exit,
and at least one trade. Each row represents an alternative configuration, not a
trade or an independent observation. Scheduled times use the broker clock.

### Separate USDJPY fine-grid extension

Range starts and durations vary in five-minute steps in two-signal mode, with
fixed exits at 17:00, 20:00 and 23:00. Each scan contains 14,497 settings, and
10,927 settings are timing-valid at all three exits. Scans are matched by range
start and duration, not optimization pass ID.

The extension uses the same historical period and modelling. Its results are
analysed separately from the original 28-pair dataset. Heatmaps display actual
every-second-row/column samples at ten-minute spacing; statistics and shared
colour limits use the full five-minute grid. Changing the exit also changes the
entry cutoff and available entry opportunities.

## Selected findings

- Mean profitable-setting coverage was **54.15% for JPY pairs** and **5.16% for
  non-JPY pairs**, with equal weight per pair.
- In two-signal mode, mean neighbourhood-supported coverage was **44.55% for JPY
  pairs** and **1.95% for non-JPY pairs**. Removing USDJPY and CADJPY left a JPY
  mean of **27.53%**.
- Across the common USDJPY fine-grid settings, the three exit times show different
  trade-offs:

| Exit | Median profit | Median RF | Median PF | Median raw R |
| --- | ---: | ---: | ---: | ---: |
| 17:00 | €234.45 | 3.0364 | 1.1453 | 0.9449 |
| 20:00 | €406.39 | 4.4153 | 1.1774 | 0.9594 |
| 23:00 | €323.22 | 3.7358 | 1.1283 | 0.9660 |

These medians use all 10,927 matched settings, without filtering to profitable
configurations. The 20:00 exit leads on median profit, RF and PF among these three
exits; 23:00 has the highest median R. This does not establish an optimal exit
outside the studied sample.

## Metric definitions

- **Profitable-setting coverage:** the share of eligible configurations with
  positive net profit; it is not the winning-trade percentage.
- **Profit factor (PF):** gross winning profits divided by absolute gross losing losses.
- **Recovery factor (RF):** net profit divided by monetary maximum balance drawdown.
- **Custom R:** Pearson correlation between trade number and cumulative net profit
  normalized per lot. It describes historical path linearity, not predictive power.
- **Neighbourhood support:** a profitable configuration whose six neighbours are
  also profitable; each neighbour changes one timing input by 30 minutes.

Fisher z(R) is used for visual contrast in selected figures. Numerical R summaries
use the original R values. Equity drawdown percentage is a different statistic
from the monetary balance drawdown used in RF.

## Technical evidence and reproduction

The [SQL storage model](sql/01_schema.sql) contains the three
related research tables and the intermediate import-staging table. The release
makes InnoDB explicit while preserving the study's columns, keys and constraints.
The schema, import, reporting view, validation checks and analysis queries were
tested in a newly created schema on the same MySQL server on 11 November 2026.
[Reproduction results](docs/VALIDATION.md)

The [reporting view](sql/02_reporting_view.sql) preserves
the study's joins, timing calculations, eligibility flags and ordered outcome
classification. The view retains invalid rows for audit and filters to the
original `TRB06_SL100` cohort.

The [read-only validation queries](sql/03_validation.sql) cover source coverage,
raw imports, per-scan totals and reporting outcomes. Their
[expected controls](docs/VALIDATION.md) document the counts reconciled in the study.

The [analysis queries](sql/04_analysis.sql) produce coverage by pair, the
equal-weight JPY comparison and neighbourhood support by pair.

The import procedure loads the original study from its two processed CSVs
and reconciles staging before inserting the final rows.
[Import instructions](docs/IMPORT.md) · [Verified CSV archive](data/TRB06_SL100_inputs.zip)

The [Python walkthrough](fx_breakout_walkthrough.ipynb) reads both CSVs from the
packaged ZIP. It reproduces the timing counts and profitable-setting coverage,
compares the JPY and non-JPY groups, and plots one USDJPY profit heatmap from
the original 30-minute grid. The notebook includes its saved outputs.

To reproduce them, open the notebook from the repository root in JupyterLab
with a Python kernel that has pandas and Matplotlib installed, then run all
cells. The notebook reads the archive at `data/TRB06_SL100_inputs.zip`.

### Power BI model and measures

The model has an active one-to-many relationship from `Pairs[pair_code]` to
`Backtests[pair_code]`. Pair filters flow to the backtest results. The standalone
`Currency summary` table holds coverage summaries by currency.
[Power BI model diagram](power-bi/model.png)

The [DAX query](power-bi/measures.dax) contains the report's ten saved measures
and evaluates them across the full model. It requires the report's semantic model
to run in Power BI Desktop's DAX query view. `Profitable Settings %` returns a
fraction formatted as a percentage in the report. The mean and median pair
measures aggregate each pair's share with equal weight.

The Power BI totals and the JPY and non-JPY group results match the SQL and
Python checks. [Validation controls](docs/VALIDATION.md)

## Interpretation and limitations

Configurations overlap and currency pairs share currencies. Configuration profits
cannot be summed into a portfolio result. Regions were selected after inspecting
the history, and finer sampling does not add independent market observations.

The study uses one broker's data and 1-minute OHLC modelling. Real-tick,
another-broker and genuinely unseen-date validation remain future work. Exact
end-date inclusion and historical broker-to-UTC offsets have not been independently
verified. Changing account currency can affect monetary and ratio-based results.

A comparison of 437 matching coarse/fine 23:00 settings found matching trade
counts, profit signs and missing-value patterns, but small metric differences:
74 profits differed by up to €0.02. Their cause remains unresolved. Matching trade
counts do not establish identical trade histories.

## Future work

- Freeze a shortlist and selection rules for independent validation.
- Compare real-tick results, other broker conditions and genuinely unseen dates.
- Investigate additional exits, stop-loss/take-profit choices and account currency.
- Examine day-of-week statistics using dated trade records and an explicit
  broker-time definition of weekday.

The completed report is an exploratory research result. These follow-up experiments
are separate from preparing the technical source release.
