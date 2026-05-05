-- ============================================================
-- 02_stored_proc_incremental_load.sql
-- Incremental upsert procedures for daily pipeline runs
-- ============================================================

-- ── Upsert: fact_operations ───────────────────────────────────
CREATE OR ALTER PROCEDURE usp_load_fact_operations
    @run_date DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @run_date IS NULL SET @run_date = CAST(GETDATE() AS DATE);

    -- Temp staging table
    CREATE TABLE #staging_ops (
        order_id                VARCHAR(20),
        order_date              DATE,
        region                  VARCHAR(60),
        shift                   VARCHAR(20),
        throughput_uph          DECIMAL(8,2),
        dock_delay_hrs          DECIMAL(8,2),
        defect_rate_pct         DECIMAL(6,2),
        inventory_accuracy_pct  DECIMAL(6,2),
        sla_hours               DECIMAL(8,2),
        sla_met                 BIT,
        units_processed         INT,
        cost_per_unit           DECIMAL(8,2),
        total_cost              AS (cost_per_unit * units_processed) PERSISTED,
        record_source           VARCHAR(40)
    );

    -- Load from external staging (adjust path/linked server as needed)
    -- BULK INSERT #staging_ops FROM 'staging/warehouse_clean.csv'
    -- WITH (FORMAT = 'CSV', FIRSTROW = 2);

    DECLARE @inserted INT = 0;
    DECLARE @updated  INT = 0;

    -- Upsert using MERGE
    MERGE fact_operations AS target
    USING (
        SELECT
            d.date_key,
            r.region_key,
            s.shift_key,
            src.source_key,
            st.throughput_uph,
            st.dock_delay_hrs,
            st.defect_rate_pct,
            st.inventory_accuracy_pct,
            st.sla_hours,
            st.sla_met,
            st.units_processed,
            st.cost_per_unit,
            st.cost_per_unit * st.units_processed AS total_cost,
            @run_date                             AS pipeline_run_date,
            st.record_source
        FROM #staging_ops st
        JOIN dim_date        d   ON d.full_date    = st.order_date
        JOIN dim_region      r   ON r.region_name  = st.region
        JOIN dim_shift       s   ON s.shift_name   = st.shift
        JOIN dim_source      src ON src.source_name = st.record_source
    ) AS source
    ON  target.date_key   = source.date_key
    AND target.region_key = source.region_key
    AND target.shift_key  = source.shift_key
    AND target.pipeline_run_date = source.pipeline_run_date

    WHEN MATCHED THEN UPDATE SET
        target.throughput_uph           = source.throughput_uph,
        target.dock_delay_hrs           = source.dock_delay_hrs,
        target.defect_rate_pct          = source.defect_rate_pct,
        target.inventory_accuracy_pct   = source.inventory_accuracy_pct,
        target.sla_hours                = source.sla_hours,
        target.sla_met                  = source.sla_met,
        target.units_processed          = source.units_processed,
        target.cost_per_unit            = source.cost_per_unit,
        target.total_cost               = source.total_cost,
        target.load_timestamp           = GETDATE()

    WHEN NOT MATCHED THEN INSERT (
        date_key, region_key, shift_key, source_key,
        throughput_uph, dock_delay_hrs, defect_rate_pct,
        inventory_accuracy_pct, sla_hours, sla_met,
        units_processed, cost_per_unit, total_cost,
        pipeline_run_date, record_source
    ) VALUES (
        source.date_key, source.region_key, source.shift_key, source.source_key,
        source.throughput_uph, source.dock_delay_hrs, source.defect_rate_pct,
        source.inventory_accuracy_pct, source.sla_hours, source.sla_met,
        source.units_processed, source.cost_per_unit, source.total_cost,
        source.pipeline_run_date, source.record_source
    );

    SET @inserted = @@ROWCOUNT;

    -- Log to audit table
    INSERT INTO pipeline_audit_log (
        run_date, run_timestamp, pipeline_step,
        source_system, status, records_out
    )
    VALUES (
        @run_date, GETDATE(), 'usp_load_fact_operations',
        'warehouse_csv', 'SUCCESS', @inserted
    );

    DROP TABLE #staging_ops;

    SELECT @inserted AS records_loaded;
END;
GO


-- ── Helper: Populate dim_date (run once) ─────────────────────
CREATE OR ALTER PROCEDURE usp_populate_dim_date
    @start_date DATE = '2020-01-01',
    @end_date   DATE = '2030-12-31'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @current DATE = @start_date;

    WHILE @current <= @end_date
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dim_date WHERE date_key = CONVERT(INT, FORMAT(@current, 'yyyyMMdd')))
        BEGIN
            INSERT INTO dim_date (date_key, full_date, year, quarter, month_num, month_name, week_num, day_of_week, is_weekday)
            VALUES (
                CONVERT(INT, FORMAT(@current, 'yyyyMMdd')),
                @current,
                YEAR(@current),
                DATEPART(QUARTER, @current),
                MONTH(@current),
                DATENAME(MONTH, @current),
                DATEPART(WEEK, @current),
                DATENAME(WEEKDAY, @current),
                CASE WHEN DATEPART(WEEKDAY, @current) NOT IN (1, 7) THEN 1 ELSE 0 END
            );
        END
        SET @current = DATEADD(DAY, 1, @current);
    END;

    SELECT COUNT(*) AS dates_populated FROM dim_date;
END;
GO
