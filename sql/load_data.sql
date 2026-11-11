-- FX Time Range Breakout | import for the original 28-pair study.
-- Run the numbered sections in one MySQL session after 01_schema.sql.
-- Start with the four empty tables created for reproduction.
-- Replace both /path/to/mysql-upload/ paths with server-side file paths.
-- See docs/IMPORT.md for prerequisites and expected counts.
-- After the checks, commit or roll back in the same session.

-- STEP 1. Check the import directory and confirm the tables are empty.
SELECT @@GLOBAL.secure_file_priv AS allowed_import_directory;
SELECT
    (SELECT COUNT(*) FROM fx_time_range_breakout.currency_pairs) AS pairs,
    (SELECT COUNT(*) FROM fx_time_range_breakout.backtest_scans) AS scans,
    (SELECT COUNT(*) FROM fx_time_range_breakout.optimization_results_staging)
        AS staged_rows,
    (SELECT COUNT(*) FROM fx_time_range_breakout.optimization_results)
        AS result_rows;

-- STEP 2. Start the import transaction and seed the 28 pairs.
START TRANSACTION;

INSERT INTO fx_time_range_breakout.currency_pairs
    (pair_code, base_currency, quote_currency)
VALUES
    ('AUDCAD', 'AUD', 'CAD'),
    ('AUDCHF', 'AUD', 'CHF'),
    ('AUDJPY', 'AUD', 'JPY'),
    ('AUDNZD', 'AUD', 'NZD'),
    ('AUDUSD', 'AUD', 'USD'),
    ('CADCHF', 'CAD', 'CHF'),
    ('CADJPY', 'CAD', 'JPY'),
    ('CHFJPY', 'CHF', 'JPY'),
    ('EURAUD', 'EUR', 'AUD'),
    ('EURCAD', 'EUR', 'CAD'),
    ('EURCHF', 'EUR', 'CHF'),
    ('EURGBP', 'EUR', 'GBP'),
    ('EURJPY', 'EUR', 'JPY'),
    ('EURNZD', 'EUR', 'NZD'),
    ('EURUSD', 'EUR', 'USD'),
    ('GBPAUD', 'GBP', 'AUD'),
    ('GBPCAD', 'GBP', 'CAD'),
    ('GBPCHF', 'GBP', 'CHF'),
    ('GBPJPY', 'GBP', 'JPY'),
    ('GBPNZD', 'GBP', 'NZD'),
    ('GBPUSD', 'GBP', 'USD'),
    ('NZDCAD', 'NZD', 'CAD'),
    ('NZDCHF', 'NZD', 'CHF'),
    ('NZDJPY', 'NZD', 'JPY'),
    ('NZDUSD', 'NZD', 'USD'),
    ('USDCAD', 'USD', 'CAD'),
    ('USDCHF', 'USD', 'CHF'),
    ('USDJPY', 'USD', 'JPY');

-- STEP 3. Load scan metadata, then load result rows into staging.
LOAD DATA INFILE
'/path/to/mysql-upload/TRB06_SL100_scans.csv'
INTO TABLE fx_time_range_breakout.backtest_scans
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    dataset_code, pair_code, source_file, source_sha256,
    ea_name, broker_server, timeframe,
    test_start_input, test_end_input,
    initial_deposit, account_currency, leverage,
    modeling_mode, fixed_stop_loss_pct
);
SHOW WARNINGS;

LOAD DATA INFILE
'/path/to/mysql-upload/TRB06_SL100_results.csv'
INTO TABLE fx_time_range_breakout.optimization_results_staging
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    source_sha256,
    pass_id,
    optimizer_result,
    net_profit,
    expected_payoff,
    profit_factor,
    recovery_factor,
    sharpe_ratio,
    correlation_r,
    equity_drawdown_pct,
    trade_count,
    breakout_mode,
    range_start_min,
    range_duration_min,
    range_close_min
);
SHOW WARNINGS;

-- Expected: 318136 rows, 28 hashes, 31304 missing PF, 0 unmatched rows.
SELECT
    COUNT(*) AS staged_rows,
    COUNT(DISTINCT r.source_sha256) AS source_files,
    SUM(r.profit_factor IS NULL) AS missing_pf,
    SUM(s.scan_id IS NULL) AS unmatched_scans
FROM fx_time_range_breakout.optimization_results_staging AS r
LEFT JOIN fx_time_range_breakout.backtest_scans AS s
    ON s.source_sha256 = r.source_sha256
   AND s.dataset_code = 'TRB06_SL100';

-- STEP 4. Resolve source hashes to scan IDs and insert the final rows.
INSERT INTO fx_time_range_breakout.optimization_results (
    scan_id, pass_id, optimizer_result, net_profit, expected_payoff,
    profit_factor, recovery_factor, sharpe_ratio, correlation_r,
    equity_drawdown_pct, trade_count, breakout_mode,
    range_start_min, range_duration_min, range_close_min
)
SELECT
    s.scan_id, r.pass_id, r.optimizer_result, r.net_profit, r.expected_payoff,
    r.profit_factor, r.recovery_factor, r.sharpe_ratio, r.correlation_r,
    r.equity_drawdown_pct, r.trade_count, r.breakout_mode,
    r.range_start_min, r.range_duration_min, r.range_close_min
FROM fx_time_range_breakout.optimization_results_staging AS r
JOIN fx_time_range_breakout.backtest_scans AS s
    ON s.source_sha256 = r.source_sha256
WHERE s.dataset_code = 'TRB06_SL100';
SHOW WARNINGS;

-- STEP 5. Run Checks 1 and 2 from 03_validation.sql in this session.
-- If the import and both checks match, run COMMIT separately.
-- If a load fails or counts differ, run ROLLBACK before retrying.
-- COMMIT;
-- ROLLBACK;
