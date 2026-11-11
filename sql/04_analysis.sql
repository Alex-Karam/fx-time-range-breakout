-- FX Time Range Breakout | selected analyses from the original 28-pair study.
-- Each read-only query uses the populated TRB06_SL100 reporting view.
-- Coverage is the percentage of eligible configurations with positive net profit.
-- Query outputs use percentage units (54.15 means 54.15%).

-- QUERY 1. Coverage for each pair across both breakout modes.
-- Expected: 28 pairs with 10244 eligible settings each. USDJPY has 9779
-- profitable settings (95.46%) and CADJPY has 8621 (84.16%).
SELECT
    pair_code,
    is_jpy,
    COUNT(*) AS eligible_settings,
    SUM(net_profit > 0) AS profitable_settings,
    ROUND(
        100.0 * SUM(net_profit > 0) / COUNT(*),
        2
    ) AS profitable_share_pct
FROM fx_time_range_breakout.v_trb06_results
WHERE is_eligible = 1
GROUP BY pair_code, is_jpy
ORDER BY profitable_share_pct DESC, pair_code;

-- QUERY 2. Equal-weight mean and median coverage for JPY and non-JPY pairs.
-- First calculate coverage within each pair, then give each pair one vote.
-- Expected JPY: 7 pairs, mean 54.15%, median 57.31%.
-- Expected non-JPY: 21 pairs, mean 5.16%, median 2.06%.
WITH pair_coverage AS (
    SELECT
        pair_code,
        is_jpy,
        -- Keep precision here; round only the final summaries.
        100.00000000 * SUM(net_profit > 0) / COUNT(*) AS profitable_pct
    FROM fx_time_range_breakout.v_trb06_results
    WHERE is_eligible = 1
    GROUP BY pair_code, is_jpy
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY is_jpy
            ORDER BY profitable_pct, pair_code
        ) AS rn,
        COUNT(*) OVER (PARTITION BY is_jpy) AS group_size
    FROM pair_coverage
)
SELECT
    CASE WHEN is_jpy = 1 THEN 'JPY' ELSE 'Non-JPY' END AS pair_group,
    COUNT(*) AS pairs,
    ROUND(AVG(profitable_pct), 2) AS mean_profitable_pct,

    -- Select the middle pair, or two middle pairs for an even group.
    ROUND(AVG(
        CASE WHEN rn IN (
            FLOOR((group_size + 1) / 2),
            FLOOR((group_size + 2) / 2)
        ) THEN profitable_pct END
    ), 2) AS median_profitable_pct
FROM ranked
GROUP BY is_jpy
ORDER BY is_jpy DESC;

-- QUERY 3. Neighbourhood support by pair in two-signal mode.
-- Each neighbour shifts one timing input by 30 minutes within the same scan.
-- Restrict the denominator to settings with all six eligible neighbours.
-- Expected: 28 rows with 3564 interior settings per pair. These per-pair
-- results feed the group comparison in the report.
WITH grid_steps AS (
    SELECT -30 AS start_shift, 0 AS duration_shift, 0 AS close_shift
    UNION ALL SELECT 30, 0, 0
    UNION ALL SELECT 0, -30, 0
    UNION ALL SELECT 0, 30, 0
    UNION ALL SELECT 0, 0, -30
    UNION ALL SELECT 0, 0, 30
),
settings AS (
    SELECT
        scan_id,
        pass_id,
        pair_code,
        is_jpy,
        breakout_mode,
        range_start_min,
        range_duration_min,
        range_close_min,
        net_profit
    FROM fx_time_range_breakout.v_trb06_results
    WHERE breakout_mode = 1
      AND is_eligible = 1
),
support AS (
    SELECT
        c.scan_id,
        c.pass_id,
        COUNT(n.pass_id) AS available_neighbours,
        COUNT(CASE WHEN n.net_profit > 0 THEN 1 END)
            AS profitable_neighbours
    FROM settings AS c
    CROSS JOIN grid_steps AS g
    LEFT JOIN settings AS n
        ON n.scan_id = c.scan_id
       AND n.breakout_mode = c.breakout_mode
       AND n.range_start_min =
           CAST(c.range_start_min AS SIGNED) + g.start_shift
       AND n.range_duration_min =
           CAST(c.range_duration_min AS SIGNED) + g.duration_shift
       AND n.range_close_min =
           CAST(c.range_close_min AS SIGNED) + g.close_shift
    GROUP BY c.scan_id, c.pass_id
)
SELECT
    c.pair_code,
    c.is_jpy,
    COUNT(*) AS interior_settings,
    SUM(c.net_profit > 0) AS profitable_settings,

    -- Supported = profitable reference AND all six neighbours profitable.
    SUM(c.net_profit > 0 AND s.profitable_neighbours = 6)
        AS supported_settings,

    ROUND(100.0 * AVG(c.net_profit > 0), 2)
        AS profitable_share_pct,
    ROUND(
        100.0 * AVG(
            c.net_profit > 0 AND s.profitable_neighbours = 6
        ), 2
    ) AS supported_share_pct
FROM settings AS c
JOIN support AS s
    ON s.scan_id = c.scan_id
   AND s.pass_id = c.pass_id
WHERE s.available_neighbours = 6
GROUP BY c.pair_code, c.is_jpy
ORDER BY supported_share_pct DESC, profitable_share_pct DESC, c.pair_code;
