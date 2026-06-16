USE [sqldb-edu-insights-dev];
GO

CREATE OR ALTER PROCEDURE silver.usp_merge_school
    @pipeline_run_id BIGINT = NULL,
    @source_batch_id NVARCHAR(50),
    @reporting_month CHAR(7)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM quality.reporting_readiness
        WHERE source_batch_id = @source_batch_id
          AND reporting_month = @reporting_month
          AND readiness_status = 'NOT_READY'
    )
    BEGIN
        ;THROW 51000, 'Quality checks are NOT_READY for this batch. Silver merge stopped.', 1;
    END;


    WITH source_rows AS (
        SELECT
            NULLIF(LTRIM(RTRIM(school_id)), '') AS school_id,
            COALESCE(NULLIF(LTRIM(RTRIM(school_name)), ''), 'Unknown school') AS school_name,
            NULLIF(LTRIM(RTRIM(region)), '') AS region,
            NULLIF(LTRIM(RTRIM(school_type)), '') AS school_type,
            TRY_CONVERT(DATE, open_date) AS open_date,
            NULLIF(LTRIM(RTRIM(status)), '') AS status,
            source_batch_id,
            reporting_month,
            HASHBYTES(
                'SHA2_256',
                CONCAT_WS('|',
                    NULLIF(LTRIM(RTRIM(school_id)), ''),
                    COALESCE(NULLIF(LTRIM(RTRIM(school_name)), ''), 'Unknown school'),
                    NULLIF(LTRIM(RTRIM(region)), ''),
                    NULLIF(LTRIM(RTRIM(school_type)), ''),
                    TRY_CONVERT(DATE, open_date),
                    NULLIF(LTRIM(RTRIM(status)), '')
                )
            ) AS record_hash,
            ROW_NUMBER() OVER (
                PARTITION BY NULLIF(LTRIM(RTRIM(school_id)), '')
                ORDER BY bronze_school_id DESC      -- Within each duplicate group, keep the latest loaded Bronze row.
            ) AS rn
        FROM bronze.schools
        WHERE source_batch_id = @source_batch_id
            AND reporting_month = @reporting_month
            AND NULLIF(LTRIM(RTRIM(school_id)), '') IS NOT NULL
    ),
    deduped AS (
        SELECT *
        FROM source_rows
        WHERE rn = 1
    )
    MERGE silver.school AS tgt 
    USING deduped AS src 
        ON tgt.school_id = src.school_id 
    WHEN MATCHED AND (
        ISNULL(tgt.record_hash, 0x) <> ISNULL(src.record_hash, 0x)
        OR tgt.last_seen_reporting_month <> src.reporting_month
    )
        THEN UPDATE SET 
            tgt.school_name = src.school_name,
            tgt.region = src.region,
            tgt.school_type = src.school_type,
            tgt.open_date = src.open_date,
            tgt.status = src.status,
            tgt.source_batch_id = src.source_batch_id,
            tgt.last_seen_reporting_month = src.reporting_month,
            tgt.record_hash = src.record_hash,
            tgt.updated_at = SYSUTCDATETIME()
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (
            school_id,
            school_name,
            region,
            school_type,
            open_date,
            status,
            source_batch_id,
            effective_from_month,
            last_seen_reporting_month,
            record_hash,
            validation_status
        )
        VALUES (
            src.school_id,
            src.school_name,
            src.region,
            src.school_type,
            src.open_date,
            src.status,
            src.source_batch_id,
            src.reporting_month,
            src.reporting_month,
            src.record_hash,
            'Valid'
        );
END;
GO



CREATE OR ALTER PROCEDURE silver.usp_merge_student_tables
    @pipeline_run_id BIGINT = NULL,
    @source_batch_id NVARCHAR(50),
    @reporting_month CHAR(7)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1
        FROM quality.reporting_readiness
        WHERE source_batch_id = @source_batch_id
          AND reporting_month = @reporting_month
          AND readiness_status IN ('READY', 'READY_WITH_CAVEATS')
    )
    BEGIN
        RAISERROR('Quality checks are not ready for this batch. Student merge stopped.', 16, 1);
        RETURN;
    END;

    IF OBJECT_ID('tempdb..#student_source') IS NOT NULL
        DROP TABLE #student_source;

    WITH ranked_students AS (
        SELECT
            NULLIF(LTRIM(RTRIM(st.student_id)), '') AS student_id,
            NULLIF(LTRIM(RTRIM(st.school_id)), '') AS school_id,
            sc.school_key,
            TRY_CONVERT(INT, st.year_level) AS year_level,
            NULLIF(LTRIM(RTRIM(st.gender)), '') AS gender,
            TRY_CONVERT(DATE, st.enrolment_date) AS enrolment_date,
            NULLIF(LTRIM(RTRIM(st.status)), '') AS status,
            st.source_batch_id,
            st.reporting_month,
            CAST(HASHBYTES(
                'SHA2_256',
                CONCAT_WS('|',
                    NULLIF(LTRIM(RTRIM(st.student_id)), ''),
                    NULLIF(LTRIM(RTRIM(st.school_id)), ''),
                    TRY_CONVERT(INT, st.year_level),
                    NULLIF(LTRIM(RTRIM(st.gender)), ''),
                    TRY_CONVERT(DATE, st.enrolment_date),
                    NULLIF(LTRIM(RTRIM(st.status)), '')
                )
            ) AS VARBINARY(32)) AS record_hash,
            ROW_NUMBER() OVER (
                PARTITION BY NULLIF(LTRIM(RTRIM(st.student_id)), '')
                ORDER BY st.bronze_student_id DESC      -- Within each duplicate group, keep the latest loaded Bronze row.
            ) AS rn
        FROM bronze.students st
        LEFT JOIN silver.school sc
            ON sc.school_id = NULLIF(LTRIM(RTRIM(st.school_id)), '')
        WHERE st.source_batch_id = @source_batch_id
          AND st.reporting_month = @reporting_month
          AND NULLIF(LTRIM(RTRIM(st.student_id)), '') IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM quality.rejected_record rr
              WHERE rr.source_batch_id = @source_batch_id
                AND rr.reporting_month = @reporting_month
                AND rr.source_table_name = 'bronze.students'
                AND rr.business_key = NULLIF(LTRIM(RTRIM(st.student_id)), '')
          )
    )
    SELECT
        student_id,
        school_id,
        school_key,
        year_level,
        gender,
        enrolment_date,
        status,
        source_batch_id,
        reporting_month,
        record_hash
    INTO #student_source
    FROM ranked_students
    WHERE rn = 1;

    MERGE silver.student AS tgt
    USING #student_source AS src
        ON tgt.student_id = src.student_id
    WHEN MATCHED AND (
           ISNULL(tgt.record_hash, 0x) <> ISNULL(src.record_hash, 0x)
        OR tgt.last_seen_reporting_month <> src.reporting_month
    )
        THEN UPDATE SET
            tgt.current_school_key = src.school_key,
            tgt.current_school_id = src.school_id,
            tgt.current_year_level = src.year_level,
            tgt.gender = src.gender,
            tgt.enrolment_date = src.enrolment_date,
            tgt.status = src.status,
            tgt.source_batch_id = src.source_batch_id,
            tgt.last_seen_reporting_month = src.reporting_month,
            tgt.record_hash = src.record_hash,
            tgt.updated_at = SYSUTCDATETIME()
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (
            student_id,
            current_school_key,
            current_school_id,
            current_year_level,
            gender,
            enrolment_date,
            status,
            source_batch_id,
            effective_from_month,
            last_seen_reporting_month,
            record_hash,
            validation_status
        )
        VALUES (
            src.student_id,
            src.school_key,
            src.school_id,
            src.year_level,
            src.gender,
            src.enrolment_date,
            src.status,
            src.source_batch_id,
            src.reporting_month,
            src.reporting_month,
            src.record_hash,
            'Valid'
        );

    
    -- create full silver.student_monthly_status snapshot from silver.student
    DELETE FROM silver.student_monthly_status
    WHERE reporting_month = @reporting_month;

    INSERT INTO silver.student_monthly_status (
        reporting_month,
        student_key,
        school_key,
        year_level,
        gender,
        student_status,
        source_batch_id,
        validation_status
    )
    SELECT
        @reporting_month AS reporting_month,
        s.student_key,
        s.current_school_key AS school_key,
        s.current_year_level AS year_level,
        s.gender,
        s.status AS student_status,
        @source_batch_id AS source_batch_id,
        'Valid' AS validation_status
    FROM silver.student s
    WHERE (
          UPPER(COALESCE(s.status, '')) IN ('ACTIVE', 'ENROLLED')
          OR EXISTS (
              SELECT 1
              FROM bronze.attendance att
              WHERE att.source_batch_id = @source_batch_id
                AND att.reporting_month = @reporting_month
                AND NULLIF(LTRIM(RTRIM(att.student_id)), '') = s.student_id
          )
      )
      AND NOT EXISTS (
          SELECT 1
          FROM quality.rejected_record rr
          WHERE rr.source_batch_id = @source_batch_id
            AND rr.reporting_month = @reporting_month
            AND rr.source_table_name = 'bronze.students'
            AND rr.business_key = s.student_id
      );
END;
GO



CREATE OR ALTER PROCEDURE silver.usp_merge_attendance_monthly
    @pipeline_run_id BIGINT = NULL,
    @source_batch_id NVARCHAR(50),
    @reporting_month CHAR(7)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1
        FROM quality.reporting_readiness
        WHERE source_batch_id = @source_batch_id
          AND reporting_month = @reporting_month
          AND readiness_status IN ('READY', 'READY_WITH_CAVEATS')
    )
    BEGIN
        RAISERROR('Quality checks are not ready for this batch. Attendance merge stopped.', 16, 1);
        RETURN;
    END;

    WITH source_rows AS (
        SELECT
            NULLIF(LTRIM(RTRIM(att.attendance_id)), '') AS attendance_id,
            att.reporting_month,
            TRY_CONVERT(DATE, att.attendance_month) AS attendance_month,
            st.student_key,
            sc.school_key,
            TRY_CONVERT(INT, att.possible_days) AS possible_days,
            TRY_CONVERT(INT, att.attended_days) AS attended_days,
            CASE
                WHEN TRY_CONVERT(INT, att.possible_days) > 0
                    THEN CAST(TRY_CONVERT(DECIMAL(10,4), att.attended_days)
                        / TRY_CONVERT(DECIMAL(10,4), att.possible_days) AS DECIMAL(6,4))
                ELSE NULL
            END AS attendance_rate,
            CASE
                WHEN TRY_CONVERT(INT, att.possible_days) = TRY_CONVERT(INT, att.attended_days)
                    THEN NULL
                ELSE NULLIF(LTRIM(RTRIM(att.absence_reason)), '')
            END AS absence_reason,
            CASE
                WHEN TRY_CONVERT(INT, att.possible_days) <= 0 THEN NULL
                WHEN TRY_CONVERT(DECIMAL(10,4), att.attended_days)
                     / TRY_CONVERT(DECIMAL(10,4), att.possible_days) < 0.82 THEN 'Low'
                WHEN TRY_CONVERT(DECIMAL(10,4), att.attended_days)
                     / TRY_CONVERT(DECIMAL(10,4), att.possible_days) < 0.90 THEN 'Medium'
                ELSE 'High'
            END AS attendance_band,
            att.source_batch_id,
            ROW_NUMBER() OVER (
                PARTITION BY NULLIF(LTRIM(RTRIM(att.attendance_id)), '')
                ORDER BY att.bronze_attendance_id DESC      -- Within each duplicate group, keep the latest loaded Bronze row.
            ) AS rn
        FROM bronze.attendance att
        JOIN silver.student st
            ON st.student_id = NULLIF(LTRIM(RTRIM(att.student_id)), '')
        JOIN silver.school sc
            ON sc.school_id = NULLIF(LTRIM(RTRIM(att.school_id)), '')
        WHERE att.source_batch_id = @source_batch_id
          AND att.reporting_month = @reporting_month
          AND NULLIF(LTRIM(RTRIM(att.attendance_id)), '') IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM quality.rejected_record rr
              WHERE rr.source_batch_id = @source_batch_id
                AND rr.reporting_month = @reporting_month
                AND rr.source_table_name = 'bronze.attendance'
                AND rr.business_key = NULLIF(LTRIM(RTRIM(att.attendance_id)), '')
          )
          AND TRY_CONVERT(INT, att.possible_days) IS NOT NULL
          AND TRY_CONVERT(INT, att.attended_days) IS NOT NULL
          AND TRY_CONVERT(INT, att.possible_days) >= 0
          AND TRY_CONVERT(INT, att.attended_days) >= 0
          AND TRY_CONVERT(INT, att.attended_days) <= TRY_CONVERT(INT, att.possible_days)
    ),
    deduped AS (
        SELECT *
        FROM source_rows
        WHERE rn = 1
    )
    MERGE silver.attendance_monthly AS tgt
    USING deduped AS src
        ON tgt.attendance_id = src.attendance_id
    WHEN MATCHED
        THEN UPDATE SET
            tgt.reporting_month = src.reporting_month,
            tgt.attendance_month = src.attendance_month,
            tgt.student_key = src.student_key,
            tgt.school_key = src.school_key,
            tgt.possible_days = src.possible_days,
            tgt.attended_days = src.attended_days,
            tgt.attendance_rate = src.attendance_rate,
            tgt.absence_reason = src.absence_reason,
            tgt.attendance_band = src.attendance_band,
            tgt.source_batch_id = src.source_batch_id,
            tgt.validation_status = 'Valid'
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (
            attendance_id,
            reporting_month,
            attendance_month,
            student_key,
            school_key,
            possible_days,
            attended_days,
            attendance_rate,
            absence_reason,
            attendance_band,
            source_batch_id,
            validation_status
        )
        VALUES (
            src.attendance_id,
            src.reporting_month,
            src.attendance_month,
            src.student_key,
            src.school_key,
            src.possible_days,
            src.attended_days,
            src.attendance_rate,
            src.absence_reason,
            src.attendance_band,
            src.source_batch_id,
            'Valid'
        );
END;
GO


CREATE OR ALTER PROCEDURE silver.usp_merge_assessment_result
    @pipeline_run_id BIGINT = NULL,
    @source_batch_id NVARCHAR(50),
    @reporting_month CHAR(7)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1
        FROM quality.reporting_readiness
        WHERE source_batch_id = @source_batch_id
          AND reporting_month = @reporting_month
          AND readiness_status IN ('READY', 'READY_WITH_CAVEATS')
    )
    BEGIN
        RAISERROR('Quality checks are not ready for this batch. Assessment merge stopped.', 16, 1);
        RETURN;
    END;

    WITH source_rows AS (
        SELECT
            NULLIF(LTRIM(RTRIM(ar.assessment_id)), '') AS assessment_id,
            st.student_key,
            sc.school_key,
            TRY_CONVERT(INT, ar.assessment_year) AS assessment_year,
            NULLIF(LTRIM(RTRIM(ar.domain)), '') AS domain,
            TRY_CONVERT(DECIMAL(6,2), ar.score) AS score,
            NULLIF(LTRIM(RTRIM(ar.proficiency_band)), '') AS proficiency_band,
            ar.source_batch_id,
            ROW_NUMBER() OVER (
                PARTITION BY NULLIF(LTRIM(RTRIM(ar.assessment_id)), '')
                ORDER BY ar.bronze_assessment_result_id DESC
            ) AS rn
        FROM bronze.assessment_results ar
        JOIN silver.student st
            ON st.student_id = NULLIF(LTRIM(RTRIM(ar.student_id)), '')
        JOIN silver.school sc
            ON sc.school_id = NULLIF(LTRIM(RTRIM(ar.school_id)), '')
        WHERE ar.source_batch_id = @source_batch_id
          AND ar.reporting_month = @reporting_month
          AND NULLIF(LTRIM(RTRIM(ar.assessment_id)), '') IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM quality.rejected_record rr
              WHERE rr.source_batch_id = @source_batch_id
                AND rr.reporting_month = @reporting_month
                AND rr.source_table_name = 'bronze.assessment_results'
                AND rr.business_key = NULLIF(LTRIM(RTRIM(ar.assessment_id)), '')
          )
          AND TRY_CONVERT(INT, ar.assessment_year) IS NOT NULL
          AND NULLIF(LTRIM(RTRIM(ar.domain)), '') IS NOT NULL
          AND TRY_CONVERT(DECIMAL(6,2), ar.score) IS NOT NULL
          AND TRY_CONVERT(DECIMAL(6,2), ar.score) BETWEEN 250 AND 700
    ),
    deduped AS (
        SELECT *
        FROM source_rows
        WHERE rn = 1
    )
    MERGE silver.assessment_result AS tgt
    USING deduped AS src
        ON tgt.assessment_id = src.assessment_id
    WHEN MATCHED
        THEN UPDATE SET
            tgt.student_key = src.student_key,
            tgt.school_key = src.school_key,
            tgt.assessment_year = src.assessment_year,
            tgt.domain = src.domain,
            tgt.score = src.score,
            tgt.proficiency_band = src.proficiency_band,
            tgt.source_batch_id = src.source_batch_id,
            tgt.validation_status = 'Valid'
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (
            assessment_id,
            student_key,
            school_key,
            assessment_year,
            domain,
            score,
            proficiency_band,
            source_batch_id,
            validation_status
        )
        VALUES (
            src.assessment_id,
            src.student_key,
            src.school_key,
            src.assessment_year,
            src.domain,
            src.score,
            src.proficiency_band,
            src.source_batch_id,
            'Valid'
        );
END;
GO



CREATE OR ALTER PROCEDURE silver.usp_merge_school_event
    @pipeline_run_id BIGINT = NULL,
    @source_batch_id NVARCHAR(50),
    @reporting_month CHAR(7)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1
        FROM quality.reporting_readiness
        WHERE source_batch_id = @source_batch_id
          AND reporting_month = @reporting_month
          AND readiness_status IN ('READY', 'READY_WITH_CAVEATS')
    )
    BEGIN
        RAISERROR('Quality checks are not ready for this batch. School event merge stopped.', 16, 1);
        RETURN;
    END;

    WITH source_rows AS (
        SELECT
            NULLIF(LTRIM(RTRIM(ev.event_id)), '') AS event_id,
            sc.school_key,
            NULLIF(LTRIM(RTRIM(ev.event_type)), '') AS event_type,
            TRY_CONVERT(DATE, ev.event_date) AS event_date,
            NULLIF(LTRIM(RTRIM(ev.description)), '') AS description,
            ev.source_batch_id,
            ROW_NUMBER() OVER (
                PARTITION BY NULLIF(LTRIM(RTRIM(ev.event_id)), '')
                ORDER BY ev.bronze_school_event_id DESC
            ) AS rn
        FROM bronze.school_events ev
        JOIN silver.school sc
            ON sc.school_id = NULLIF(LTRIM(RTRIM(ev.school_id)), '')
        WHERE ev.source_batch_id = @source_batch_id
          AND ev.reporting_month = @reporting_month
          AND NULLIF(LTRIM(RTRIM(ev.event_id)), '') IS NOT NULL
          AND NULLIF(LTRIM(RTRIM(ev.event_type)), '') IS NOT NULL
          AND TRY_CONVERT(DATE, ev.event_date) IS NOT NULL
    ),
    deduped AS (
        SELECT *
        FROM source_rows
        WHERE rn = 1
    )
    MERGE silver.school_event AS tgt
    USING deduped AS src
        ON tgt.event_id = src.event_id
    WHEN MATCHED
        THEN UPDATE SET
            tgt.school_key = src.school_key,
            tgt.event_type = src.event_type,
            tgt.event_date = src.event_date,
            tgt.description = src.description,
            tgt.source_batch_id = src.source_batch_id,
            tgt.validation_status = 'Valid'
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (
            event_id,
            school_key,
            event_type,
            event_date,
            description,
            source_batch_id,
            validation_status
        )
        VALUES (
            src.event_id,
            src.school_key,
            src.event_type,
            src.event_date,
            src.description,
            src.source_batch_id,
            'Valid'
        );
END;
GO



-- Wrapper procedure so ADF can run all Silver merges with a single Stored Procedure activity:
CREATE OR ALTER PROCEDURE silver.usp_merge_conformed_tables
    @pipeline_run_id BIGINT = NULL,
    @source_batch_id NVARCHAR(50),
    @reporting_month CHAR(7)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC silver.usp_merge_school
        @pipeline_run_id = @pipeline_run_id,
        @source_batch_id = @source_batch_id,
        @reporting_month = @reporting_month;

    EXEC silver.usp_merge_student_tables
        @pipeline_run_id = @pipeline_run_id,
        @source_batch_id = @source_batch_id,
        @reporting_month = @reporting_month;

    EXEC silver.usp_merge_attendance_monthly
        @pipeline_run_id = @pipeline_run_id,
        @source_batch_id = @source_batch_id,
        @reporting_month = @reporting_month;

    EXEC silver.usp_merge_assessment_result
        @pipeline_run_id = @pipeline_run_id,
        @source_batch_id = @source_batch_id,
        @reporting_month = @reporting_month;

    EXEC silver.usp_merge_school_event
        @pipeline_run_id = @pipeline_run_id,
        @source_batch_id = @source_batch_id,
        @reporting_month = @reporting_month;
END;
GO





--EXEC silver.usp_merge_conformed_tables
--    @pipeline_run_id = NULL,
--    @source_batch_id = '2024_01',
--    @reporting_month = '2024-01';


--SELECT 'silver.school' AS table_name, COUNT(*) AS row_count
--FROM silver.school

--UNION ALL
--SELECT 'silver.student', COUNT(*)
--FROM silver.student

--UNION ALL
--SELECT 'silver.student_monthly_status', COUNT(*)
--FROM silver.student_monthly_status
--WHERE reporting_month = '2024-01'

--UNION ALL
--SELECT 'silver.attendance_monthly', COUNT(*)
--FROM silver.attendance_monthly
--WHERE reporting_month = '2024-01'

--UNION ALL
--SELECT 'silver.assessment_result', COUNT(*)
--FROM silver.assessment_result

--UNION ALL
--SELECT 'silver.school_event', COUNT(*)
--FROM silver.school_event;
