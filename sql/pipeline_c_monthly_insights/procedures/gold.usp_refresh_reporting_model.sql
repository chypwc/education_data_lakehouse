USE [sqldb-edu-insights-dev];
GO

-- Dimension tables

CREATE OR ALTER PROCEDURE gold.usp_refresh_reporting_dimensions
    @source_batch_id NVARCHAR(50),
    @reporting_month CHAR(7)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @month_start_date DATE = TRY_CONVERT(DATE, @reporting_month + '-01');
    DECLARE @month_key INT = TRY_CONVERT(INT, REPLACE(@reporting_month, '-', ''));

    MERGE gold.dim_month AS tgt
    USING (
        SELECT
            @month_key AS month_key,
            @reporting_month AS reporting_month,
            @month_start_date AS month_start_date,
            YEAR(@month_start_date) AS calendar_year,
            MONTH(@month_start_date) AS calendar_month_number,
            DATENAME(MONTH, @month_start_date) AS calendar_month_name,
            YEAR(@month_start_date) AS school_year,
            CASE
                WHEN MONTH(@month_start_date) IN (1) THEN 'Summer break'
                WHEN MONTH(@month_start_date) IN (2, 3, 4) THEN 'Term 1'
                WHEN MONTH(@month_start_date) IN (5, 6, 7) THEN 'Term 2'
                WHEN MONTH(@month_start_date) IN (8, 9) THEN 'Term 3'
                WHEN MONTH(@month_start_date) IN (10, 11, 12) THEN 'Term 4'
            END AS school_term,
            CASE
                WHEN MONTH(@month_start_date) IN (12, 1, 2) THEN 'Summer'
                WHEN MONTH(@month_start_date) IN (3, 4, 5) THEN 'Autumn'
                WHEN MONTH(@month_start_date) IN (6, 7, 8) THEN 'Winter'
                ELSE 'Spring'
            END AS season,
            TRY_CONVERT(INT, FORMAT(DATEADD(MONTH, -1, @month_start_date), 'yyyyMM')) AS prior_month_key,
            CASE WHEN MONTH(@month_start_date) IN (6, 7, 8) THEN 1 ELSE 0 END AS is_winter_month
    ) AS src
        ON tgt.month_key = src.month_key
    WHEN MATCHED THEN UPDATE SET
        tgt.reporting_month = src.reporting_month,
        tgt.month_start_date = src.month_start_date,
        tgt.calendar_year = src.calendar_year,
        tgt.calendar_month_number = src.calendar_month_number,
        tgt.calendar_month_name = src.calendar_month_name,
        tgt.school_year = src.school_year,
        tgt.school_term = src.school_term,
        tgt.season = src.season,
        tgt.prior_month_key = src.prior_month_key,
        tgt.is_winter_month = src.is_winter_month
    WHEN NOT MATCHED THEN INSERT (
        month_key,
        reporting_month,
        month_start_date,
        calendar_year,
        calendar_month_number,
        calendar_month_name,
        school_year,
        school_term,
        season,
        prior_month_key,
        is_winter_month
    )
    VALUES (
        src.month_key,
        src.reporting_month,
        src.month_start_date,
        src.calendar_year,
        src.calendar_month_number,
        src.calendar_month_name,
        src.school_year,
        src.school_term,
        src.season,
        src.prior_month_key,
        src.is_winter_month
    );

    MERGE gold.dim_school AS tgt
    USING (
        SELECT
            school_key,
            school_id,
            school_name,
            region,
            school_type,
            status,
            open_date
        FROM silver.school
    ) AS src
        ON tgt.school_key = src.school_key
    WHEN MATCHED THEN UPDATE SET
        tgt.school_id = src.school_id,
        tgt.school_name = src.school_name,
        tgt.region = src.region,
        tgt.school_type = src.school_type,
        tgt.status = src.status,
        tgt.open_date = src.open_date
    WHEN NOT MATCHED THEN INSERT (
        school_key,
        school_id,
        school_name,
        region,
        school_type,
        status,
        open_date
    )
    VALUES (
        src.school_key,
        src.school_id,
        src.school_name,
        src.region,
        src.school_type,
        src.status,
        src.open_date
    );

    MERGE gold.dim_year_level AS tgt
    USING (
        SELECT
            year_level AS year_level_key,
            year_level,
            CASE
                WHEN year_level = 0 THEN 'Kindergarten'
                ELSE CONCAT('Year ', year_level)
            END AS year_level_label,
            CASE
                WHEN year_level <= 6 THEN 'Primary'
                WHEN year_level = 7 THEN 'Year 7 transition'
                WHEN year_level BETWEEN 8 AND 10 THEN 'Years 8-10'
                ELSE 'Senior secondary'
            END AS cohort_group,
            year_level AS sort_order
        FROM (
            SELECT DISTINCT current_year_level AS year_level
            FROM silver.student
            WHERE current_year_level IS NOT NULL
        ) y
    ) AS src
        ON tgt.year_level_key = src.year_level_key
    WHEN MATCHED THEN UPDATE SET
        tgt.year_level = src.year_level,
        tgt.year_level_label = src.year_level_label,
        tgt.cohort_group = src.cohort_group,
        tgt.sort_order = src.sort_order
    WHEN NOT MATCHED THEN INSERT (
        year_level_key,
        year_level,
        year_level_label,
        cohort_group,
        sort_order
    )
    VALUES (
        src.year_level_key,
        src.year_level,
        src.year_level_label,
        src.cohort_group,
        src.sort_order
    );

    MERGE gold.dim_attendance_band AS tgt
    USING (
        SELECT 'Low' AS attendance_band, CAST(0.0000 AS DECIMAL(6,4)) AS lower_bound, CAST(0.8200 AS DECIMAL(6,4)) AS upper_bound, 1 AS band_sort_order
        UNION ALL SELECT 'Medium', 0.8200, 0.9000, 2
        UNION ALL SELECT 'High', 0.9000, 1.0000, 3
    ) AS src
        ON tgt.attendance_band = src.attendance_band
    WHEN MATCHED THEN UPDATE SET
        tgt.lower_bound = src.lower_bound,
        tgt.upper_bound = src.upper_bound,
        tgt.band_sort_order = src.band_sort_order
    WHEN NOT MATCHED THEN INSERT (
        attendance_band,
        lower_bound,
        upper_bound,
        band_sort_order
    )
    VALUES (
        src.attendance_band,
        src.lower_bound,
        src.upper_bound,
        src.band_sort_order
    );

    MERGE gold.dim_assessment_domain AS tgt
    USING (
        SELECT 'Reading' AS domain, 1 AS domain_sort_order
        UNION ALL SELECT 'Numeracy', 2
        UNION ALL SELECT 'Writing', 3
    ) AS src
        ON tgt.domain = src.domain
    WHEN MATCHED THEN UPDATE SET
        tgt.domain_sort_order = src.domain_sort_order
    WHEN NOT MATCHED THEN INSERT (
        domain,
        domain_sort_order
    )
    VALUES (
        src.domain,
        src.domain_sort_order
    );
END;
GO


--EXEC gold.usp_refresh_reporting_dimensions
--    @source_batch_id = '2024_01',
--    @reporting_month = '2024-01';


--SELECT 'gold.dim_month' AS table_name, COUNT(*) AS row_count FROM gold.dim_month
--UNION ALL
--SELECT 'gold.dim_school', COUNT(*) FROM gold.dim_school
--UNION ALL
--SELECT 'gold.dim_year_level', COUNT(*) FROM gold.dim_year_level
--UNION ALL
--SELECT 'gold.dim_attendance_band', COUNT(*) FROM gold.dim_attendance_band
--UNION ALL
--SELECT 'gold.dim_assessment_domain', COUNT(*) FROM gold.dim_assessment_domain;



-- Fact tables
--Gold facts are month-scoped analytics outputs:
--    fact_student_snapshot: one month snapshot
--    fact_attendance_monthly: one month attendance fact
--    fact_data_quality_caveat: one month caveat fact
--For those, full refresh for the affected month is usually clearer.
--DELETE existing Gold rows for this month/batch;
--INSERT refreshed Gold rows from Silver;

CREATE OR ALTER PROCEDURE gold.usp_refresh_reporting_facts
    @source_batch_id NVARCHAR(50),
    @reporting_month CHAR(7)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @month_key INT = TRY_CONVERT(INT, REPLACE(@reporting_month, '-', ''));

    IF NOT EXISTS (
        SELECT 1
        FROM gold.dim_month
        WHERE month_key = @month_key
    )
    BEGIN
        RAISERROR('Gold month dimension is missing for this reporting month. Fact refresh stopped.', 16, 1);
        RETURN;
    END;

    DELETE FROM gold.fact_data_quality_caveat
    WHERE month_key = @month_key
      AND source_batch_id = @source_batch_id;

    DELETE FROM gold.fact_assessment_result
    WHERE source_batch_id = @source_batch_id;

    DELETE FROM gold.fact_attendance_monthly
    WHERE month_key = @month_key
      AND source_batch_id = @source_batch_id;

    DELETE FROM gold.fact_student_snapshot
    WHERE month_key = @month_key
      AND source_batch_id = @source_batch_id;

    INSERT INTO gold.fact_student_snapshot (
        month_key,
        student_key,
        school_key,
        year_level_key,
        is_active_student,
        source_batch_id
    )
    SELECT
        @month_key,
        sms.student_key,
        sms.school_key,
        sms.year_level AS year_level_key,
        CASE
            WHEN UPPER(COALESCE(sms.student_status, '')) IN ('ACTIVE', 'ENROLLED') THEN 1
            ELSE 0
        END AS is_active_student,
        sms.source_batch_id
    FROM silver.student_monthly_status sms
    WHERE sms.reporting_month = @reporting_month
      AND sms.source_batch_id = @source_batch_id;

    INSERT INTO gold.fact_attendance_monthly (
        month_key,
        student_key,
        school_key,
        year_level_key,
        attendance_band_key,
        possible_days,
        attended_days,
        attendance_rate,
        source_batch_id
    )
    SELECT
        @month_key,
        att.student_key,
        att.school_key,
        sms.year_level AS year_level_key,
        band.attendance_band_key,
        att.possible_days,
        att.attended_days,
        att.attendance_rate,
        att.source_batch_id
    FROM silver.attendance_monthly att
    LEFT JOIN silver.student_monthly_status sms
        ON sms.reporting_month = att.reporting_month
       AND sms.student_key = att.student_key
       AND sms.source_batch_id = @source_batch_id
    LEFT JOIN gold.dim_attendance_band band
        ON band.attendance_band = att.attendance_band
    WHERE att.reporting_month = @reporting_month
      AND att.source_batch_id = @source_batch_id;

    INSERT INTO gold.fact_assessment_result (
        assessment_result_key,
        assessment_year,
        student_key,
        school_key,
        year_level_key,
        assessment_domain_key,
        attendance_band_key,
        score,
        source_batch_id
    )
    SELECT
        ar.assessment_result_key,
        ar.assessment_year,
        ar.student_key,
        ar.school_key,
        s.current_year_level AS year_level_key,
        d.assessment_domain_key,
        band.attendance_band_key,
        ar.score,
        ar.source_batch_id
    FROM silver.assessment_result ar
    JOIN gold.dim_assessment_domain d
        ON d.domain = ar.domain
    LEFT JOIN silver.student s
        ON s.student_key = ar.student_key
    OUTER APPLY (
        SELECT TOP 1
            att.attendance_band
        FROM silver.attendance_monthly att
        WHERE att.student_key = ar.student_key
          AND LEFT(att.reporting_month, 4) = CONVERT(CHAR(4), ar.assessment_year)
        ORDER BY att.reporting_month DESC
    ) latest_attendance
    LEFT JOIN gold.dim_attendance_band band
        ON band.attendance_band = latest_attendance.attendance_band
    WHERE ar.source_batch_id = @source_batch_id;

    INSERT INTO gold.fact_data_quality_caveat (
        month_key,
        reporting_caveat_id,
        caveat_code,
        severity,
        affected_area,
        failed_record_count,
        source_batch_id
    )
    SELECT
        @month_key,
        rc.reporting_caveat_id,
        rc.caveat_code,
        rc.severity,
        rc.affected_area,
        COALESCE(vr.failed_record_count, 0) AS failed_record_count,
        rc.source_batch_id
    FROM quality.reporting_caveat rc
    LEFT JOIN quality.validation_result vr
        ON vr.source_batch_id = rc.source_batch_id
       AND vr.reporting_month = rc.reporting_month
       AND vr.rule_code = rc.caveat_code
    WHERE rc.source_batch_id = @source_batch_id
      AND rc.reporting_month = @reporting_month;
END;
GO



--EXEC gold.usp_refresh_reporting_facts
--    @source_batch_id = '2024_01',
--    @reporting_month = '2024-01';


--SELECT 'gold.fact_student_snapshot' AS table_name, COUNT(*) AS row_count
--FROM gold.fact_student_snapshot
--WHERE month_key = 202401
--  AND source_batch_id = '2024_01'

--UNION ALL
--SELECT 'gold.fact_attendance_monthly', COUNT(*)
--FROM gold.fact_attendance_monthly
--WHERE month_key = 202401
--  AND source_batch_id = '2024_01'

--UNION ALL
--SELECT 'gold.fact_assessment_result', COUNT(*)
--FROM gold.fact_assessment_result
--WHERE source_batch_id = '2024_01'

--UNION ALL
--SELECT 'gold.fact_data_quality_caveat', COUNT(*)
--FROM gold.fact_data_quality_caveat
--WHERE month_key = 202401
--  AND source_batch_id = '2024_01';
--GO


CREATE OR ALTER PROCEDURE gold.usp_refresh_reporting_model
    @source_batch_id NVARCHAR(50),
    @reporting_month CHAR(7)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC gold.usp_refresh_reporting_dimensions
        @source_batch_id = @source_batch_id,
        @reporting_month = @reporting_month;

    EXEC gold.usp_refresh_reporting_facts
        @source_batch_id = @source_batch_id,
        @reporting_month = @reporting_month;
END;
GO


--EXEC gold.usp_refresh_reporting_model
--    @source_batch_id = '2024_01',
--    @reporting_month = '2024-01';


--SELECT 'gold.dim_month' AS table_name, COUNT(*) AS row_count FROM gold.dim_month
--UNION ALL
--SELECT 'gold.dim_school', COUNT(*) FROM gold.dim_school
--UNION ALL
--SELECT 'gold.dim_year_level', COUNT(*) FROM gold.dim_year_level
--UNION ALL
--SELECT 'gold.dim_attendance_band', COUNT(*) FROM gold.dim_attendance_band
--UNION ALL
--SELECT 'gold.dim_assessment_domain', COUNT(*) FROM gold.dim_assessment_domain
--UNION ALL
--SELECT 'gold.fact_student_snapshot', COUNT(*) FROM gold.fact_student_snapshot WHERE month_key = 202401 AND source_batch_id = '2024_01'
--UNION ALL
--SELECT 'gold.fact_attendance_monthly', COUNT(*) FROM gold.fact_attendance_monthly WHERE month_key = 202401 AND source_batch_id = '2024_01'
--UNION ALL
--SELECT 'gold.fact_assessment_result', COUNT(*) FROM gold.fact_assessment_result WHERE source_batch_id = '2024_01'
--UNION ALL
--SELECT 'gold.fact_data_quality_caveat', COUNT(*) FROM gold.fact_data_quality_caveat WHERE month_key = 202401 AND source_batch_id = '2024_01';

