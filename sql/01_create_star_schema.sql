-- ============================================================
-- 01_create_star_schema.sql
-- Star schema for unified analytics layer
-- ============================================================

-- ── Dimension: Date ───────────────────────────────────────────
CREATE TABLE dim_date (
    date_key        INT             PRIMARY KEY,  -- YYYYMMDD
    full_date       DATE            NOT NULL,
    year            INT,
    quarter         INT,
    month_num       INT,
    month_name      VARCHAR(10),
    week_num        INT,
    day_of_week     VARCHAR(10),
    is_weekday      BIT
);

-- ── Dimension: Region ─────────────────────────────────────────
CREATE TABLE dim_region (
    region_key      INT IDENTITY(1,1) PRIMARY KEY,
    region_name     VARCHAR(60)     NOT NULL,
    region_short    VARCHAR(20),
    zone            VARCHAR(30),
    manager         VARCHAR(60)
);

-- ── Dimension: Shift ──────────────────────────────────────────
CREATE TABLE dim_shift (
    shift_key       INT IDENTITY(1,1) PRIMARY KEY,
    shift_name      VARCHAR(20)     NOT NULL,  -- Day / Night
    start_time      TIME,
    end_time        TIME
);

-- ── Dimension: Cost Center ────────────────────────────────────
CREATE TABLE dim_cost_center (
    cost_center_key INT IDENTITY(1,1) PRIMARY KEY,
    cost_center_name VARCHAR(60)    NOT NULL,
    category        VARCHAR(30),   -- Labor / Freight / Facilities / etc.
    is_controllable BIT
);

-- ── Dimension: Source System ──────────────────────────────────
CREATE TABLE dim_source (
    source_key      INT IDENTITY(1,1) PRIMARY KEY,
    source_name     VARCHAR(40)     NOT NULL,  -- warehouse_csv / finance_json / api
    source_type     VARCHAR(20),
    ingestion_frequency VARCHAR(20)
);

-- ── Fact: Operations ──────────────────────────────────────────
CREATE TABLE fact_operations (
    fact_key                BIGINT IDENTITY(1,1) PRIMARY KEY,
    date_key                INT             REFERENCES dim_date(date_key),
    region_key              INT             REFERENCES dim_region(region_key),
    shift_key               INT             REFERENCES dim_shift(shift_key),
    source_key              INT             REFERENCES dim_source(source_key),
    -- Measures
    throughput_uph          DECIMAL(8,2),
    dock_delay_hrs          DECIMAL(8,2),
    defect_rate_pct         DECIMAL(6,2),
    inventory_accuracy_pct  DECIMAL(6,2),
    sla_hours               DECIMAL(8,2),
    sla_met                 BIT,
    units_processed         INT,
    cost_per_unit           DECIMAL(8,2),
    total_cost              DECIMAL(12,2),
    -- Lineage
    pipeline_run_date       DATE,
    record_source           VARCHAR(40),
    load_timestamp          DATETIME DEFAULT GETDATE()
);

-- ── Fact: Finance ─────────────────────────────────────────────
CREATE TABLE fact_finance (
    fact_key                BIGINT IDENTITY(1,1) PRIMARY KEY,
    date_key                INT             REFERENCES dim_date(date_key),
    region_key              INT             REFERENCES dim_region(region_key),
    cost_center_key         INT             REFERENCES dim_cost_center(cost_center_key),
    source_key              INT             REFERENCES dim_source(source_key),
    -- Measures
    revenue                 DECIMAL(14,2),
    cogs                    DECIMAL(14,2),
    gross_profit            DECIMAL(14,2),
    budget_amount           DECIMAL(14,2),
    actual_amount           DECIMAL(14,2),
    variance_amount         DECIMAL(14,2),
    -- Lineage
    pipeline_run_date       DATE,
    record_source           VARCHAR(40),
    load_timestamp          DATETIME DEFAULT GETDATE()
);

-- ── Pipeline Audit Log ────────────────────────────────────────
CREATE TABLE pipeline_audit_log (
    log_id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    run_date            DATE            NOT NULL,
    run_timestamp       DATETIME        NOT NULL,
    pipeline_step       VARCHAR(60),
    source_system       VARCHAR(40),
    status              VARCHAR(10),    -- SUCCESS / FAILED
    records_in          INT,
    records_out         INT,
    records_rejected    INT,
    rejection_rate_pct  DECIMAL(6,2),
    duration_sec        DECIMAL(8,2),
    error_message       VARCHAR(500),
    inserted_at         DATETIME DEFAULT GETDATE()
);

-- ── Indexes for Power BI query performance ────────────────────
CREATE NONCLUSTERED INDEX ix_fact_ops_date     ON fact_operations(date_key);
CREATE NONCLUSTERED INDEX ix_fact_ops_region   ON fact_operations(region_key);
CREATE NONCLUSTERED INDEX ix_fact_fin_date     ON fact_finance(date_key);
CREATE NONCLUSTERED INDEX ix_fact_fin_cc       ON fact_finance(cost_center_key);
