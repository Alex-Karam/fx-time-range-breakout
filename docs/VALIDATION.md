# Validation controls

These expected values were reconciled during the original study and appear in
the completed report. The [validation SQL](../sql/03_validation.sql) presents
the checks as four read-only queries. They require the complete original
`TRB06_SL100` dataset; they are not expected outputs for a small input sample.

On 11 November 2026, Alex reproduced all four validation checks in MySQL
Workbench after loading the two CSVs into a newly created schema on the same
MySQL server. All counts matched, including the per-scan controls for all 28
pairs and the 17.40% profitable-setting coverage from the reporting view.

The three analysis queries also ran in the reproduction schema. USDJPY had
9,779 profitable settings out of 10,244 eligible settings. Mean and median
coverage were 54.15% and 57.31% for seven JPY pairs, and 5.16% and 2.06% for 21
non-JPY pairs. The neighbourhood query returned 3,564 interior settings per
pair, with 3,319 supported settings for USDJPY and 2,890 for CADJPY.

The Python walkthrough reproduced the timing counts, overall profitable-setting
coverage, and the JPY and non-JPY group results from the packaged CSVs. In the
original Power BI model, the DAX checks reproduced the raw, eligible and
profitable counts, the 17.40% coverage, and both group means and medians.
[Analysis queries](../sql/04_analysis.sql)

## Check 1: source coverage

| Field | Expected |
| --- | ---: |
| scans | 28 |
| pairs | 28 |
| unique_source_hashes | 28 |

Counting scan records, distinct pairs and distinct source hashes checks different
aspects of coverage. Matching all three counts is necessary, but does not by
itself prove that the files contain the intended parameter grids. Python checks
the source fingerprints and settings separately.

## Check 2: imported raw results

| Field | Expected |
| --- | ---: |
| result_rows | 318,136 |
| scans | 28 |
| missing_pf | 31,304 |
| valid_timing | 286,832 |
| invalid_timing | 31,304 |

Timing is recomputed directly from the stored range start, duration and exit.
The permitted gap is at least 120 scheduled minutes after range end. Invalid
rows remain in storage for audit, and missing profit factors remain SQL NULL.
The matching totals for missing PF and invalid timing are dataset controls;
aggregate counts alone do not prove a row-by-row missing-value match.

## Check 3: every pair/scan

The result must contain 28 rows. Each pair/scan has:

| Field | Expected per scan |
| --- | ---: |
| raw_rows | 11,362 |
| valid_rows | 10,244 |
| invalid_rows | 1,118 |
| missing_pf | 1,118 |

The LEFT JOIN retains scans whose result rows are missing, helping reveal an
incomplete import rather than silently dropping that scan from the output.

## Check 4: reporting view and outcomes

| Field | Expected |
| --- | ---: |
| raw_rows | 318,136 |
| timing_valid_rows | 286,832 |
| eligible_rows | 286,832 |
| invalid_rows | 31,304 |
| no_trade_rows | 0 |
| profitable_rows | 49,920 |
| losing_rows | 236,908 |
| break_even_rows | 4 |
| profitable_settings_pct | 17.40 |

Eligibility additionally requires at least one trade. This dataset has no
timing-valid, zero-trade configurations, so timing-valid and eligible counts
coincide. Invalid zero-profit rows are classified before profit is considered;
they are not included among the four break-even configurations.

Profitable-setting coverage is `49,920 / 286,832`, rounded to 17.40%. It is not
the winning-trade percentage. SQL returns percentage units here; Power BI's
percentage-formatted fraction represents the same quantity differently.

These checks concern import completeness and reporting definitions. They do not
establish independent performance validation. The USDJPY fine-grid extension
has separate inputs, eligibility counts and matched-comparison checks.
