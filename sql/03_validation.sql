-- FX Time Range Breakout: read-only checks for the original TRB06_SL100 cohort.
-- Prerequisites: the tables, full original dataset and reporting view.
-- These checks are SELECT queries only. They do not create or import anything.
-- Run one labelled check at a time and compare with docs/VALIDATION.md.
-- Expected controls apply to the complete 28-pair study, not a sample dataset.
-- The separate USDJPY five-minute scans are excluded from this cohort.

-- CHECK 1: scan metadata and source coverage.
-- Expected: scans = 28, pairs = 28, unique_source_hashes = 28.
SELECT
    COUNT(*) AS scans,
    COUNT(DISTINCT pair_code) AS pairs,
    COUNT(DISTINCT source_sha256) AS unique_source_hashes
FROM fx_time_range_breakout.backtest_scans
WHERE dataset_code = 'TRB06_SL100';

-- CHECK 2: imported raw rows, timing validity and missing profit factors.
-- This calculates timing directly from the stored inputs, independently of
-- the reporting view's derived flags.
-- Expected: result_rows = 318136, scans = 28, missing_pf = 31304,
--           valid_timing = 286832, invalid_timing = 31304.
SELECT
    COUNT(*) AS result_rows,
    COUNT(DISTINCT r.scan_id) AS scans,
    SUM(r.profit_factor IS NULL) AS missing_pf,
    SUM(r.range_start_min + r.range_duration_min + 120
        <= r.range_close_min) AS valid_timing,
    SUM(r.range_start_min + r.range_duration_min + 120
        > r.range_close_min) AS invalid_timing
FROM fx_time_range_breakout.optimization_results AS r
JOIN fx_time_range_breakout.backtest_scans AS s
    ON s.scan_id = r.scan_id
WHERE s.dataset_code = 'TRB06_SL100';

-- CHECK 3: reconcile every scan, so a global total cannot conceal a missing pair.
-- Expected: 28 rows, one per pair/scan; each has raw_rows = 11362,
--           valid_rows = 10244, invalid_rows = 1118, missing_pf = 1118.
-- LEFT JOIN keeps a metadata row visible even if its results were not imported.
SELECT
    s.pair_code,
    COUNT(r.pass_id) AS raw_rows,
    COALESCE(SUM(
        r.range_start_min + r.range_duration_min + 120
        <= r.range_close_min
    ), 0) AS valid_rows,
    COALESCE(SUM(
        r.range_start_min + r.range_duration_min + 120
        > r.range_close_min
    ), 0) AS invalid_rows,
    -- COUNT(column) excludes NULL values.
    COUNT(r.pass_id) - COUNT(r.profit_factor) AS missing_pf
FROM fx_time_range_breakout.backtest_scans AS s
LEFT JOIN fx_time_range_breakout.optimization_results AS r
    ON r.scan_id = s.scan_id
WHERE s.dataset_code = 'TRB06_SL100'
GROUP BY s.scan_id, s.pair_code
ORDER BY s.pair_code;

-- CHECK 4: reporting-layer flags, outcomes and profitable-setting coverage.
-- Expected: raw_rows = 318136, timing_valid_rows = 286832,
-- eligible_rows = 286832, invalid_rows = 31304, no_trade_rows = 0,
-- profitable_rows = 49920, losing_rows = 236908, break_even_rows = 4,
-- profitable_settings_pct = 17.40 (percentage units, not the fraction 0.174).
-- MySQL treats each TRUE condition as 1 and FALSE as 0 inside SUM.
-- NULLIF avoids dividing by zero if no eligible rows have been imported.
SELECT
    COUNT(*) AS raw_rows,
    SUM(timing_valid) AS timing_valid_rows,
    SUM(is_eligible) AS eligible_rows,
    SUM(outcome = 'Invalid') AS invalid_rows,
    SUM(outcome = 'No trades') AS no_trade_rows,
    SUM(outcome = 'Profitable') AS profitable_rows,
    SUM(outcome = 'Losing') AS losing_rows,
    SUM(outcome = 'Break-even') AS break_even_rows,
    ROUND(
        100.0 * SUM(outcome = 'Profitable')
        / NULLIF(SUM(is_eligible), 0),
        2
    ) AS profitable_settings_pct
FROM fx_time_range_breakout.v_trb06_results;
