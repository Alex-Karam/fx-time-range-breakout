-- FX Time Range Breakout: original 28-pair TRB06_SL100 storage model.
-- MySQL 8.0.16+ is required for enforced CHECK constraints.
-- Reference: https://dev.mysql.com/doc/refman/8.0/en/create-table-check-constraints.html
--
-- Intended for an empty schema when reproducing the project.
-- This file creates tables; DDL commits automatically. It is not a migration
-- for an existing populated database. It does not drop tables or import data.
--
-- Definitions preserve the columns, keys and constraints from the study SQL.
-- InnoDB is explicit here so foreign-key support does not depend on the
-- server's default storage engine.
--
-- The core relationships are:
-- currency_pairs (1) -> backtest_scans (many) -> optimization_results (many).
-- Staging is an intermediate loading table, not an additional research cohort.
--
-- Invalid timing combinations remain stored for auditability. Eligibility and
-- outcomes are derived in the reporting view, rather than enforced by deleting
-- those rows or rejecting them at import. Missing metrics remain SQL NULL.
-- This model covers the original 30-minute study; fine-grid results are separate.

CREATE DATABASE IF NOT EXISTS fx_time_range_breakout
    CHARACTER SET utf8mb4;

USE fx_time_range_breakout;

-- 1. Currency-pair reference data: one row per FX pair.
CREATE TABLE fx_time_range_breakout.currency_pairs (
    pair_code CHAR(6) NOT NULL,
    base_currency CHAR(3) NOT NULL,
    quote_currency CHAR(3) NOT NULL,

    -- Each pair code uniquely identifies one row.
    PRIMARY KEY (pair_code),

    -- A currency cannot be paired with itself.
    CONSTRAINT chk_different_currencies
        CHECK (base_currency <> quote_currency),

    -- Example: USD + JPY must match USDJPY.
    CONSTRAINT chk_pair_code
        CHECK (pair_code = CONCAT(base_currency, quote_currency))
) ENGINE = InnoDB;

-- 2. Scan provenance and settings: one row per imported XML export.
CREATE TABLE fx_time_range_breakout.backtest_scans (
    -- MySQL assigns a unique number to each imported scan.
    scan_id INT UNSIGNED NOT NULL AUTO_INCREMENT,

    -- Keep different research datasets distinguishable.
    dataset_code VARCHAR(50) NOT NULL,
    pair_code CHAR(6) NOT NULL,

    -- Preserve the original filename and its content fingerprint.
    source_file VARCHAR(255) NOT NULL,
    source_sha256 CHAR(64)
        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,

    -- Settings recorded in the XML metadata.
    ea_name VARCHAR(128) NOT NULL,
    broker_server VARCHAR(128) NOT NULL,
    timeframe VARCHAR(10) NOT NULL,

    -- Store the reported date inputs without assuming end-date inclusion.
    test_start_input DATE NOT NULL,
    test_end_input DATE NOT NULL,

    initial_deposit DECIMAL(15,2) NOT NULL,
    account_currency CHAR(3) NOT NULL,
    leverage SMALLINT UNSIGNED NOT NULL,

    -- Confirmed separately: these are not extracted from the XML headers.
    modeling_mode VARCHAR(32) NOT NULL,
    fixed_stop_loss_pct DECIMAL(7,2) NOT NULL,

    -- Time this database record was added, not when MT5 ran.
    imported_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (scan_id),

    -- Prevent importing the same XML content twice.
    CONSTRAINT uq_scan_source_hash UNIQUE (source_sha256),

    -- Every scan must reference a pair in our existing table.
    CONSTRAINT fk_scan_pair
        FOREIGN KEY (pair_code)
        REFERENCES fx_time_range_breakout.currency_pairs (pair_code),

    CONSTRAINT chk_scan_dates
        CHECK (test_start_input < test_end_input),

    CONSTRAINT chk_scan_deposit
        CHECK (initial_deposit > 0),

    CONSTRAINT chk_scan_leverage
        CHECK (leverage > 0),

    CONSTRAINT chk_scan_stop
        CHECK (fixed_stop_loss_pct >= 0)
) ENGINE = InnoDB;

-- 3. Reported metrics and varied inputs: one row per scan/pass.
CREATE TABLE fx_time_range_breakout.optimization_results (
    scan_id INT UNSIGNED NOT NULL,
    pass_id INT UNSIGNED NOT NULL,

    -- Preserve the original reported metrics.
    optimizer_result DOUBLE NULL,
    net_profit DECIMAL(18,2) NOT NULL,
    expected_payoff DOUBLE NULL,
    profit_factor DOUBLE NULL,
    recovery_factor DOUBLE NULL,
    sharpe_ratio DOUBLE NULL,

    -- The XML's Custom field contains our full-precision correlation R.
    correlation_r DOUBLE NULL,

    -- Percentage units: 0.7586 means 0.7586%, not 75.86%.
    equity_drawdown_pct DOUBLE NULL,
    trade_count INT UNSIGNED NOT NULL,

    -- The four inputs varied within each TRB06 scan.
    -- Times are minutes after broker midnight.
    breakout_mode TINYINT UNSIGNED NOT NULL,
    range_start_min SMALLINT UNSIGNED NOT NULL,
    range_duration_min SMALLINT UNSIGNED NOT NULL,
    range_close_min SMALLINT UNSIGNED NOT NULL,

    PRIMARY KEY (scan_id, pass_id),

    -- Prevent repeated parameter combinations within the same scan.
    CONSTRAINT uq_result_settings UNIQUE (
        scan_id,
        breakout_mode,
        range_start_min,
        range_duration_min,
        range_close_min
    ),

    -- Every result must belong to an existing scan.
    CONSTRAINT fk_result_scan
        FOREIGN KEY (scan_id)
        REFERENCES fx_time_range_breakout.backtest_scans (scan_id),

    CONSTRAINT chk_breakout_mode
        CHECK (breakout_mode IN (0, 1))
) ENGINE = InnoDB;

-- 4. Import staging: source hashes are resolved to scan IDs before final insertion.
CREATE TABLE fx_time_range_breakout.optimization_results_staging (
    source_sha256 CHAR(64)
        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    pass_id INT UNSIGNED NOT NULL,

    optimizer_result DOUBLE NULL,
    net_profit DECIMAL(18,2) NOT NULL,
    expected_payoff DOUBLE NULL,
    profit_factor DOUBLE NULL,
    recovery_factor DOUBLE NULL,
    sharpe_ratio DOUBLE NULL,
    correlation_r DOUBLE NULL,
    equity_drawdown_pct DOUBLE NULL,
    trade_count INT UNSIGNED NOT NULL,

    breakout_mode TINYINT UNSIGNED NOT NULL,
    range_start_min SMALLINT UNSIGNED NOT NULL,
    range_duration_min SMALLINT UNSIGNED NOT NULL,
    range_close_min SMALLINT UNSIGNED NOT NULL,

    -- Prevent repeated passes from the same source file.
    PRIMARY KEY (source_sha256, pass_id)
) ENGINE = InnoDB;
