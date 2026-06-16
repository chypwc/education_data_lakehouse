USE [sqldb-edu-insights-dev];
GO

CREATE OR ALTER PROCEDURE quality.usp_apply_quality_checks
    @pipeline_run_id BIGINT = NULL,
    @source_batch_id NVARCHAR(50),
    @reporting_month CHAR(7)
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM quality.validation_result
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    DELETE FROM quality.reporting_caveat
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    DELETE FROM quality.reporting_readiness
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    DECLARE @results TABLE (
        source_table_name NVARCHAR(150),
        rule_code NVARCHAR(100),
        rule_description NVARCHAR(500),
        severity NVARCHAR(20),
        failed_record_count INT
    );

    INSERT INTO @results
    SELECT
        'bronze.attendance',
        'ATT_NO_ROWS_FOR_MONTH',
        'Bronze attendance has zero rows for the reporting month.',
        'BLOCKER',
        CASE
            WHEN COUNT(*) = 0 THEN 1
            ELSE 0
        END
    FROM bronze.attendance
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    INSERT INTO @results
    SELECT
        'bronze.attendance',
        'ATT_ROW_COUNT_TOO_LOW',
        'Bronze attendance row count is unexpectedly low for the reporting month.',
        'BLOCKER',
        CASE
            WHEN COUNT(*) < 1000 THEN 1
            ELSE 0
        END
    FROM bronze.attendance
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    INSERT INTO @results
    SELECT
        'bronze.students',
        'STU_NO_ROWS_FOR_MONTH',
        'Bronze students has zero rows for the initial snapshot month.',
        'BLOCKER',
        CASE
            WHEN @reporting_month = '2024-01' AND COUNT(*) = 0 THEN 1
            ELSE 0
        END
    FROM bronze.students
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    INSERT INTO @results
    SELECT
        'bronze.schools',
        'SCH_NO_ROWS_FOR_MONTH',
        'Bronze schools has zero rows for the initial snapshot month.',
        'BLOCKER',
        CASE
            WHEN @reporting_month = '2024-01' AND COUNT(*) = 0 THEN 1
            ELSE 0
        END
    FROM bronze.schools
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;


    INSERT INTO @results
    SELECT
        'bronze.schools',
        'SCH_MISSING_KEY',
        'School row is missing school_id.',
        'ERROR',
        COUNT(*)
    FROM bronze.schools
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
      AND NULLIF(LTRIM(RTRIM(school_id)), '') IS NULL;

    INSERT INTO @results
    SELECT
        'bronze.students',
        'STU_MISSING_KEY',
        'Student row is missing student_id.',
        'ERROR',
        COUNT(*)
    FROM bronze.students
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
      AND NULLIF(LTRIM(RTRIM(student_id)), '') IS NULL;

    INSERT INTO @results
    SELECT
        'bronze.students',
        'STU_MISSING_SCHOOL_ID',
        'Student row is missing school_id.',
        'ERROR',
        COUNT(*)
    FROM bronze.students
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
      AND NULLIF(LTRIM(RTRIM(student_id)), '') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(school_id)), '') IS NULL;

    INSERT INTO @results
    SELECT
        'bronze.students',
        'STU_UNKNOWN_SCHOOL',
        'Student references a school_id not available in Bronze schools.',
        'ERROR',
        COUNT(*)
    FROM bronze.students st
    WHERE st.source_batch_id = @source_batch_id
      AND st.reporting_month = @reporting_month
      AND NULLIF(LTRIM(RTRIM(st.school_id)), '') IS NOT NULL
      AND NOT EXISTS (
          SELECT 1
          FROM bronze.schools sc
          WHERE sc.school_id = st.school_id
      );

    INSERT INTO @results
    SELECT
        'bronze.attendance',
        'ATT_INVALID_DAYS',
        'Attendance row has invalid possible_days or attended_days.',
        'ERROR',
        COUNT(*)
    FROM bronze.attendance
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
      AND (
          TRY_CONVERT(INT, possible_days) IS NULL
          OR TRY_CONVERT(INT, attended_days) IS NULL
          OR TRY_CONVERT(INT, possible_days) < 0
          OR TRY_CONVERT(INT, attended_days) < 0
          OR TRY_CONVERT(INT, attended_days) > TRY_CONVERT(INT, possible_days)
      );

    WITH duplicate_attendance AS (
        SELECT
            attendance_id,
            ROW_NUMBER() OVER (
                PARTITION BY
                    NULLIF(LTRIM(RTRIM(student_id)), ''),
                    NULLIF(LTRIM(RTRIM(school_id)), ''),
                    TRY_CONVERT(DATE, attendance_month)
                ORDER BY bronze_attendance_id
            ) AS rn
        FROM bronze.attendance
        WHERE source_batch_id = @source_batch_id
          AND reporting_month = @reporting_month
          AND NULLIF(LTRIM(RTRIM(student_id)), '') IS NOT NULL
          AND NULLIF(LTRIM(RTRIM(school_id)), '') IS NOT NULL
          AND TRY_CONVERT(DATE, attendance_month) IS NOT NULL
    )
    INSERT INTO @results
    SELECT
        'bronze.attendance',
        'ATT_DUPLICATE_BUSINESS_KEY',
        'Attendance has more than one row for the same student, school, and attendance month.',
        'WARNING',
        COUNT(*)
    FROM duplicate_attendance
    WHERE rn > 1;

    INSERT INTO @results
    SELECT
        'bronze.attendance',
        'ATT_UNKNOWN_STUDENT',
        'Attendance references a student_id not available in the student records.',
        'ERROR',
        COUNT(*)
    FROM bronze.attendance att
    WHERE att.source_batch_id = @source_batch_id
      AND att.reporting_month = @reporting_month
      AND NULLIF(LTRIM(RTRIM(att.student_id)), '') IS NOT NULL
      AND NOT EXISTS (
          SELECT 1
          FROM silver.student st
          WHERE st.student_id = NULLIF(LTRIM(RTRIM(att.student_id)), '')
      )
      AND NOT EXISTS (
          SELECT 1
          FROM bronze.students st
          WHERE st.source_batch_id = @source_batch_id
            AND st.reporting_month = @reporting_month
            AND NULLIF(LTRIM(RTRIM(st.student_id)), '') = NULLIF(LTRIM(RTRIM(att.student_id)), '')
      );

    INSERT INTO @results
    SELECT
        'bronze.attendance',
        'ATT_ABSENCE_REASON_NO_ABSENCE',
        'Attendance row has absence_reason even though attended_days equals possible_days.',
        'WARNING',
        COUNT(*)
    FROM bronze.attendance
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
      AND TRY_CONVERT(INT, possible_days) = TRY_CONVERT(INT, attended_days)
      AND NULLIF(LTRIM(RTRIM(absence_reason)), '') IS NOT NULL;

    INSERT INTO @results
    SELECT
        'bronze.attendance',
        'ATT_ABSENCE_REASON_MISSING',
        'Attendance row has absences but no absence_reason.',
        'WARNING',
        COUNT(*)
    FROM bronze.attendance
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
      AND TRY_CONVERT(INT, attended_days) < TRY_CONVERT(INT, possible_days)
      AND NULLIF(LTRIM(RTRIM(absence_reason)), '') IS NULL;

    INSERT INTO @results
    SELECT
        'bronze.assessment_results',
        'ASM_INVALID_SCORE',
        'Assessment score is not numeric or outside expected range 250 to 700.',
        'ERROR',
        COUNT(*)
    FROM bronze.assessment_results
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
      AND (
          TRY_CONVERT(DECIMAL(6,2), score) IS NULL
          OR TRY_CONVERT(DECIMAL(6,2), score) < 250
          OR TRY_CONVERT(DECIMAL(6,2), score) > 700
      )
      AND NULLIF(LTRIM(RTRIM(assessment_id)), '') IS NOT NULL;

    INSERT INTO @results
    SELECT
        'bronze.school_events',
        'EVT_UNKNOWN_SCHOOL',
        'School event references a school_id not available in Bronze schools.',
        'WARNING',
        COUNT(*)
    FROM bronze.school_events ev
    WHERE ev.source_batch_id = @source_batch_id
      AND ev.reporting_month = @reporting_month
      AND NULLIF(LTRIM(RTRIM(ev.school_id)), '') IS NOT NULL
      AND NOT EXISTS (
          SELECT 1
          FROM bronze.schools sc
          WHERE sc.school_id = ev.school_id
      );



    INSERT INTO quality.validation_result (
        pipeline_run_id,
        source_batch_id,
        reporting_month,
        source_table_name,
        rule_code,
        rule_description,
        severity,
        result_status,
        failed_record_count,
        checked_at
    )
    SELECT
        @pipeline_run_id,
        @source_batch_id,
        @reporting_month,
        source_table_name,
        rule_code,
        rule_description,
        severity,
        CASE WHEN failed_record_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        failed_record_count,
        SYSUTCDATETIME()
    FROM @results;


    DELETE FROM quality.rejected_record
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;


        INSERT INTO quality.rejected_record (
        pipeline_run_id,
        source_batch_id,
        reporting_month,
        source_table_name,
        source_file_name,
        raw_row_number,
        business_key,
        rule_code,
        rejection_reason,
        raw_record_json,
        rejected_at
    )
    SELECT
        @pipeline_run_id,
        @source_batch_id,
        @reporting_month,
        'bronze.schools',
        source_file_name,
        raw_row_number,
        school_id,
        'SCH_MISSING_KEY',
        'School row is missing school_id.',
        (
            SELECT
                school_id,
                school_name,
                region,
                school_type,
                open_date,
                status
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER    -- save raw record as json
        ),
        SYSUTCDATETIME()
    FROM bronze.schools
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
      AND NULLIF(LTRIM(RTRIM(school_id)), '') IS NULL;

    INSERT INTO quality.rejected_record (
        pipeline_run_id,
        source_batch_id,
        reporting_month,
        source_table_name,
        source_file_name,
        raw_row_number,
        business_key,
        rule_code,
        rejection_reason,
        raw_record_json,
        rejected_at
    )
    SELECT
        @pipeline_run_id,
        @source_batch_id,
        @reporting_month,
        'bronze.students',
        source_file_name,
        raw_row_number,
        student_id,
        'STU_MISSING_KEY',
        'Student row is missing student_id.',
        (
            SELECT
                student_id,
                school_id,
                year_level,
                gender,
                enrolment_date,
                status
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        SYSUTCDATETIME()
    FROM bronze.students
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
      AND NULLIF(LTRIM(RTRIM(student_id)), '') IS NULL;

    INSERT INTO quality.rejected_record (
        pipeline_run_id,
        source_batch_id,
        reporting_month,
        source_table_name,
        source_file_name,
        raw_row_number,
        business_key,
        rule_code,
        rejection_reason,
        raw_record_json,
        rejected_at
    )
    SELECT
        @pipeline_run_id,
        @source_batch_id,
        @reporting_month,
        'bronze.students',
        source_file_name,
        raw_row_number,
        student_id,
        'STU_MISSING_SCHOOL_ID',
        'Student row is missing school_id.',
        (
            SELECT
                student_id,
                school_id,
                year_level,
                gender,
                enrolment_date,
                status
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        SYSUTCDATETIME()
    FROM bronze.students
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
      AND NULLIF(LTRIM(RTRIM(student_id)), '') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(school_id)), '') IS NULL;

    INSERT INTO quality.rejected_record (
        pipeline_run_id,
        source_batch_id,
        reporting_month,
        source_table_name,
        source_file_name,
        raw_row_number,
        business_key,
        rule_code,
        rejection_reason,
        raw_record_json,
        rejected_at
    )
    SELECT
        @pipeline_run_id,
        @source_batch_id,
        @reporting_month,
        'bronze.students',
        st.source_file_name,
        st.raw_row_number,
        st.student_id,
        'STU_UNKNOWN_SCHOOL',
        'Student references a school_id not available in Bronze schools.',
        (
            SELECT
                st.student_id,
                st.school_id,
                st.year_level,
                st.gender,
                st.enrolment_date,
                st.status
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        SYSUTCDATETIME()
    FROM bronze.students st
    WHERE st.source_batch_id = @source_batch_id
      AND st.reporting_month = @reporting_month
      AND NULLIF(LTRIM(RTRIM(st.school_id)), '') IS NOT NULL
      AND NOT EXISTS (
          SELECT 1
          FROM bronze.schools sc
          WHERE sc.school_id = st.school_id
      );

    INSERT INTO quality.rejected_record (
        pipeline_run_id,
        source_batch_id,
        reporting_month,
        source_table_name,
        source_file_name,
        raw_row_number,
        business_key,
        rule_code,
        rejection_reason,
        raw_record_json,
        rejected_at
    )
    SELECT
        @pipeline_run_id,
        @source_batch_id,
        @reporting_month,
        'bronze.attendance',
        source_file_name,
        raw_row_number,
        attendance_id,
        'ATT_INVALID_DAYS',
        'Attendance row has invalid possible_days or attended_days.',
        (
            SELECT
                attendance_id,
                student_id,
                school_id,
                attendance_month,
                possible_days,
                attended_days,
                absence_reason
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        SYSUTCDATETIME()
    FROM bronze.attendance
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
      AND (
          TRY_CONVERT(INT, possible_days) IS NULL
          OR TRY_CONVERT(INT, attended_days) IS NULL
          OR TRY_CONVERT(INT, possible_days) < 0
          OR TRY_CONVERT(INT, attended_days) < 0
          OR TRY_CONVERT(INT, attended_days) > TRY_CONVERT(INT, possible_days)
      );

    WITH duplicate_attendance AS (
        SELECT
            source_file_name,
            raw_row_number,
            attendance_id,
            student_id,
            school_id,
            attendance_month,
            possible_days,
            attended_days,
            absence_reason,
            ROW_NUMBER() OVER (
                PARTITION BY
                    NULLIF(LTRIM(RTRIM(student_id)), ''),
                    NULLIF(LTRIM(RTRIM(school_id)), ''),
                    TRY_CONVERT(DATE, attendance_month)
                ORDER BY bronze_attendance_id
            ) AS rn
        FROM bronze.attendance
        WHERE source_batch_id = @source_batch_id
          AND reporting_month = @reporting_month
          AND NULLIF(LTRIM(RTRIM(student_id)), '') IS NOT NULL
          AND NULLIF(LTRIM(RTRIM(school_id)), '') IS NOT NULL
          AND TRY_CONVERT(DATE, attendance_month) IS NOT NULL
    )
    INSERT INTO quality.rejected_record (
        pipeline_run_id,
        source_batch_id,
        reporting_month,
        source_table_name,
        source_file_name,
        raw_row_number,
        business_key,
        rule_code,
        rejection_reason,
        raw_record_json,
        rejected_at
    )
    SELECT
        @pipeline_run_id,
        @source_batch_id,
        @reporting_month,
        'bronze.attendance',
        source_file_name,
        raw_row_number,
        attendance_id,
        'ATT_DUPLICATE_BUSINESS_KEY',
        'Attendance has more than one row for the same student, school, and attendance month.',
        (
            SELECT
                attendance_id,
                student_id,
                school_id,
                attendance_month,
                possible_days,
                attended_days,
                absence_reason
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        SYSUTCDATETIME()
    FROM duplicate_attendance
    WHERE rn > 1;

    INSERT INTO quality.rejected_record (
        pipeline_run_id,
        source_batch_id,
        reporting_month,
        source_table_name,
        source_file_name,
        raw_row_number,
        business_key,
        rule_code,
        rejection_reason,
        raw_record_json,
        rejected_at
    )
    SELECT
        @pipeline_run_id,
        @source_batch_id,
        @reporting_month,
        'bronze.attendance',
        att.source_file_name,
        att.raw_row_number,
        att.attendance_id,
        'ATT_UNKNOWN_STUDENT',
        'Attendance references a student_id not available in the student records.',
        (
            SELECT
                att.attendance_id,
                att.student_id,
                att.school_id,
                att.attendance_month,
                att.possible_days,
                att.attended_days,
                att.absence_reason
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        SYSUTCDATETIME()
    FROM bronze.attendance att
    WHERE att.source_batch_id = @source_batch_id
      AND att.reporting_month = @reporting_month
      AND NULLIF(LTRIM(RTRIM(att.student_id)), '') IS NOT NULL
      AND NOT EXISTS (
          SELECT 1
          FROM silver.student st
          WHERE st.student_id = NULLIF(LTRIM(RTRIM(att.student_id)), '')
      )
      AND NOT EXISTS (
          SELECT 1
          FROM bronze.students st
          WHERE st.source_batch_id = @source_batch_id
            AND st.reporting_month = @reporting_month
            AND NULLIF(LTRIM(RTRIM(st.student_id)), '') = NULLIF(LTRIM(RTRIM(att.student_id)), '')
      );

    INSERT INTO quality.rejected_record (
        pipeline_run_id,
        source_batch_id,
        reporting_month,
        source_table_name,
        source_file_name,
        raw_row_number,
        business_key,
        rule_code,
        rejection_reason,
        raw_record_json,
        rejected_at
    )
    SELECT
        @pipeline_run_id,
        @source_batch_id,
        @reporting_month,
        'bronze.assessment_results',
        source_file_name,
        raw_row_number,
        assessment_id,
        'ASM_INVALID_SCORE',
        'Assessment score is not numeric or outside expected range 250 to 700.',
        (
            SELECT
                assessment_id,
                student_id,
                school_id,
                assessment_year,
                domain,
                score,
                proficiency_band
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        SYSUTCDATETIME()
    FROM bronze.assessment_results
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
      AND NULLIF(LTRIM(RTRIM(assessment_id)), '') IS NOT NULL
      AND (
          TRY_CONVERT(DECIMAL(6,2), score) IS NULL
          OR TRY_CONVERT(DECIMAL(6,2), score) < 250
          OR TRY_CONVERT(DECIMAL(6,2), score) > 700
      );



    INSERT INTO quality.reporting_caveat (
        source_batch_id,
        reporting_month,
        caveat_code,
        caveat_title,
        caveat_description,
        severity,
        affected_area,
        recommended_action,
        created_at
    )
    SELECT
        @source_batch_id,
        @reporting_month,
        rule_code,
        rule_code,
        rule_description + ' Failed record count: ' + CAST(failed_record_count AS NVARCHAR(20)) + '.',
        severity,
        CASE
            WHEN source_table_name LIKE '%attendance%' THEN 'Attendance'
            WHEN source_table_name LIKE '%assessment%' THEN 'Assessment'
            WHEN source_table_name LIKE '%student%' THEN 'Student reference'
            WHEN source_table_name LIKE '%school_events%' THEN 'School events'
            ELSE 'School reference'
        END,
        CASE
            WHEN severity = 'BLOCKER' THEN 'Stop reporting for this month until required data is loaded or corrected.'
            WHEN severity = 'ERROR' THEN 'Review source records and exclude invalid rows from trusted reporting.'
            ELSE 'Review caveat and decide whether dashboard users need a note.'
        END,
        SYSUTCDATETIME()
    FROM @results
    WHERE failed_record_count > 0;

    DECLARE @blocker_count INT =
    (SELECT COUNT(*) FROM @results WHERE severity = 'BLOCKER' AND failed_record_count > 0);

    DECLARE @error_count INT =
        (SELECT COUNT(*) FROM @results WHERE severity = 'ERROR' AND failed_record_count > 0);

    DECLARE @warning_count INT =
        (SELECT COUNT(*) FROM @results WHERE severity = 'WARNING' AND failed_record_count > 0);


    DECLARE @rejected_record_count INT = ( 
        SELECT COUNT(*) 
        FROM quality.rejected_record
        WHERE source_batch_id = @source_batch_id
          AND reporting_month = @reporting_month
    );

    INSERT INTO quality.reporting_readiness (
        source_batch_id,
        reporting_month,
        readiness_status,
        blocker_count,
        warning_count,
        rejected_record_count,
        readiness_summary,
        checked_at
    )
    VALUES (
        @source_batch_id,
        @reporting_month,
        CASE
            WHEN @blocker_count > 0 THEN 'NOT_READY'
            WHEN @error_count > 0 THEN 'READY_WITH_CAVEATS'
            WHEN @warning_count > 0 THEN 'READY_WITH_CAVEATS'
            ELSE 'READY'
        END,
        @blocker_count,
        @warning_count,
        @rejected_record_count,
        CASE
            WHEN @blocker_count > 0 THEN 'Blocker checks failed. This reporting month should not be released until required data is loaded or corrected.'
            WHEN @error_count > 0 THEN 'Quality checks found error-level issues. Invalid rows should be excluded from trusted reporting.'
            WHEN @warning_count > 0 THEN 'Quality checks found warning-level caveats. Reporting can proceed with notes.'
            ELSE 'Quality checks passed for this reporting month.'
        END,
        SYSUTCDATETIME()
    );

    SELECT
        source_table_name,
        rule_code,
        severity,
        result_status,
        failed_record_count
    FROM quality.validation_result
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
    ORDER BY source_table_name, rule_code;
END;
GO


--EXEC quality.usp_apply_quality_checks
--    @pipeline_run_id = NULL,
--    @source_batch_id = 'TEST_2024_01',
--    @reporting_month = '2024-01';

--SELECT *
--FROM quality.reporting_readiness
--WHERE source_batch_id = 'TEST_2024_01';

--DELETE FROM quality.validation_result WHERE source_batch_id = 'TEST_2024_01';
--DELETE FROM quality.rejected_record WHERE source_batch_id = 'TEST_2024_01';
--DELETE FROM quality.reporting_caveat WHERE source_batch_id = 'TEST_2024_01';
--DELETE FROM quality.reporting_readiness WHERE source_batch_id = 'TEST_2024_01';
