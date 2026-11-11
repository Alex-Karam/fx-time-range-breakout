-- FX Time Range Breakout: reporting view for the original TRB06_SL100 study.
-- Prerequisite: the tables defined in 01_schema.sql.
-- The view can be defined before loading data; its queries become useful after
-- the scan metadata and optimization results have been imported.
--
-- Reproduction DDL, not a migration for the existing completed project.
-- CREATE VIEW commits automatically and will fail if this view already exists.
--
-- This definition is preserved from the SQL used in the study.
-- The timed CTE joins each result to its scan and currency pair, then calculates
-- the range end and the scheduled time remaining before the exit.
-- The final SELECT adds:
--   timing_valid: at least 120 minutes remain after the range ends.
--   is_eligible: timing is valid AND the configuration has at least one trade.
--   outcome: invalid timing / no trades / profitable / losing / break-even.
--
-- CASE order matters: invalid timing and no-trade rows are classified before
-- profit is considered. They are not treated as break-even trading results.
-- Raw rows remain available for audit; eligibility is a flag, not a row deletion.
-- The dataset filter excludes other cohorts, including the separate fine grids.

CREATE VIEW fx_time_range_breakout.v_trb06_results AS
WITH timed AS (
    SELECT
        s.dataset_code, s.pair_code, s.account_currency,
        p.base_currency, p.quote_currency,
        (p.base_currency = 'JPY' OR p.quote_currency = 'JPY') AS is_jpy,
        r.*,

        r.range_start_min + r.range_duration_min AS range_end_min,

        -- SIGNED allows negative gaps for invalid timing combinations.
        CAST(r.range_close_min AS SIGNED)
        - CAST(r.range_start_min + r.range_duration_min AS SIGNED)
            AS minutes_after_range

    FROM fx_time_range_breakout.optimization_results AS r
    JOIN fx_time_range_breakout.backtest_scans AS s
        ON s.scan_id = r.scan_id
    JOIN fx_time_range_breakout.currency_pairs AS p
        ON p.pair_code = s.pair_code
    WHERE s.dataset_code = 'TRB06_SL100'
)
SELECT
    timed.*,
    (minutes_after_range >= 120) AS timing_valid,
    (minutes_after_range >= 120 AND trade_count > 0) AS is_eligible,

    CASE
        WHEN minutes_after_range < 120 THEN 'Invalid'
        WHEN trade_count = 0 THEN 'No trades'
        WHEN net_profit > 0 THEN 'Profitable'
        WHEN net_profit < 0 THEN 'Losing'
        ELSE 'Break-even'
    END AS outcome
FROM timed;
