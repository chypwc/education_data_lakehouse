USE [sqldb-edu-insights-dev];
GO

/*
Pipeline C monthly validation script.

Change only these values for each monthly run:
    2024-01 -> INITIAL_SNAPSHOT
    2024-02 onward -> MONTHLY_CHANGE

This script returns four result sets:
    1. Overall month validation summary
    2. Essential row-count checks
    3. Failed quality rules, caveats, and rejected records
    4. Reporting-view row counts for the selected month
*/
DECLARE @source_batch_id NVARCHAR(50) = '2024_08';
DECLARE @reporting_month CHAR(7) = '2024-08';
DECLARE @expected_load_mode NVARCHAR(30) = 'MONTHLY_CHANGE';

DECLARE @month_key INT = TRY_CONVERT(INT, REPLACE(@reporting_month, '-', ''));

/* 1. Overall month validation summary */
;WITH latest_pipeline AS (
    SELECT TOP (1)
        pipeline_run_id,
        pipeline_name,
        adf_run_id,
        load_mode,
        run_status,
        started_at,
        ended_at,
        error_message
    FROM audit.pipeline_run
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
    ORDER BY pipeline_run_id DESC
),
file_summary AS (
    SELECT
        COUNT_BIG(*) AS file_load_count,
        SUM(CASE WHEN load_status <> 'LOADED' THEN 1 ELSE 0 END) AS failed_file_load_count,
        SUM(source_row_count) AS source_row_count,
        SUM(loaded_row_count) AS loaded_row_count,
        SUM(rejected_row_count) AS file_rejected_row_count
    FROM audit.file_load
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
      AND pipeline_run_id = (SELECT pipeline_run_id FROM latest_pipeline)
),
quality_summary AS (
    SELECT
        COUNT_BIG(*) AS rule_count,
        SUM(CASE WHEN result_status <> 'PASS' THEN 1 ELSE 0 END) AS failed_rule_count,
        SUM(CASE WHEN severity = 'BLOCKER' AND result_status <> 'PASS' THEN 1 ELSE 0 END) AS failed_blocker_rule_count,
        SUM(CASE WHEN severity = 'ERROR' AND result_status <> 'PASS' THEN 1 ELSE 0 END) AS failed_error_rule_count,
        SUM(CASE WHEN severity = 'WARNING' AND result_status <> 'PASS' THEN 1 ELSE 0 END) AS failed_warning_rule_count
    FROM quality.validation_result
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
),
readiness AS (
    SELECT TOP (1)
        readiness_status,
        blocker_count,
        warning_count,
        rejected_record_count,
        readiness_summary,
        checked_at
    FROM quality.reporting_readiness
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
    ORDER BY checked_at DESC
),
reconciliation_summary AS (
    SELECT
        COUNT_BIG(*) AS reconciliation_check_count,
        SUM(CASE WHEN reconciliation_status <> 'PASS' THEN 1 ELSE 0 END) AS failed_reconciliation_count
    FROM audit.row_count_reconciliation
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
      AND pipeline_run_id = (SELECT pipeline_run_id FROM latest_pipeline)
),
attendance_key_summary AS (
    SELECT
        COUNT_BIG(*) AS attendance_fact_rows,
        SUM(CASE WHEN year_level_key IS NULL THEN 1 ELSE 0 END) AS missing_year_level_rows,
        SUM(CASE WHEN attendance_band_key IS NULL THEN 1 ELSE 0 END) AS missing_attendance_band_rows
    FROM gold.fact_attendance_monthly
    WHERE source_batch_id = @source_batch_id
      AND month_key = @month_key
)
SELECT
    @source_batch_id AS source_batch_id,
    @reporting_month AS reporting_month,
    @expected_load_mode AS expected_load_mode,
    lp.pipeline_run_id,
    lp.pipeline_name,
    lp.adf_run_id,
    lp.load_mode,
    lp.run_status,
    lp.started_at,
    lp.ended_at,
    fs.file_load_count,
    fs.source_row_count,
    fs.loaded_row_count,
    fs.failed_file_load_count,
    qs.rule_count,
    qs.failed_rule_count,
    r.readiness_status,
    r.blocker_count,
    r.warning_count,
    r.rejected_record_count,
    rc.reconciliation_check_count,
    rc.failed_reconciliation_count,
    CASE
        WHEN rc.failed_reconciliation_count > 0
             AND ISNULL(r.rejected_record_count, 0) > 0
             THEN 'EXPLAINED_BY_REJECTED_RECORDS'
        WHEN rc.failed_reconciliation_count > 0
             THEN 'CHECK_RECONCILIATION'
        ELSE 'PASS'
    END AS reconciliation_interpretation,
    ak.attendance_fact_rows,
    ak.missing_year_level_rows,
    ak.missing_attendance_band_rows,
    CASE
        WHEN lp.pipeline_run_id IS NULL THEN 'CHECK_PIPELINE_RUN'
        WHEN lp.run_status <> 'SUCCEEDED' THEN 'CHECK_PIPELINE_RUN'
        WHEN lp.load_mode <> @expected_load_mode THEN 'CHECK_LOAD_MODE'
        WHEN fs.failed_file_load_count > 0 OR fs.file_load_count = 0 THEN 'CHECK_FILE_LOADS'
        WHEN r.readiness_status IS NULL THEN 'CHECK_QUALITY_READINESS'
        WHEN r.readiness_status = 'NOT_READY' THEN 'NOT_READY'
        WHEN rc.reconciliation_check_count = 0 THEN 'CHECK_RECONCILIATION'
        WHEN rc.failed_reconciliation_count > 0
             AND ISNULL(r.rejected_record_count, 0) = 0
             THEN 'CHECK_RECONCILIATION'
        WHEN ak.missing_year_level_rows > 0 OR ak.missing_attendance_band_rows > 0 THEN 'CHECK_ATTENDANCE_KEYS'
        WHEN r.readiness_status = 'READY_WITH_CAVEATS' THEN 'MONTH_VALIDATED_WITH_CAVEATS'
        ELSE 'MONTH_VALIDATED'
    END AS validation_status,
    r.readiness_summary,
    lp.error_message
FROM (SELECT 1 AS join_key) base
LEFT JOIN latest_pipeline lp
    ON 1 = 1
CROSS JOIN file_summary fs
CROSS JOIN quality_summary qs
LEFT JOIN readiness r
    ON 1 = 1
CROSS JOIN reconciliation_summary rc
CROSS JOIN attendance_key_summary ak;

/* 2. Essential row-count checks */
;WITH counts AS (
    SELECT
        'file_loads' AS check_group,
        'audit.file_load' AS object_name,
        COUNT_BIG(*) AS row_count,
        CAST(NULL AS BIGINT) AS expected_or_comparison_count,
        CAST(NULL AS BIGINT) AS difference_count,
        CASE WHEN COUNT_BIG(*) = 0 THEN 'CHECK' ELSE 'OK' END AS check_status
    FROM audit.file_load
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
      AND pipeline_run_id = (
          SELECT TOP (1) pipeline_run_id
          FROM audit.pipeline_run
          WHERE source_batch_id = @source_batch_id
            AND reporting_month = @reporting_month
          ORDER BY pipeline_run_id DESC
      )

    UNION ALL
    SELECT
        'bronze',
        'bronze.attendance',
        COUNT_BIG(*),
        CAST(NULL AS BIGINT),
        CAST(NULL AS BIGINT),
        CASE WHEN COUNT_BIG(*) = 0 THEN 'CHECK' ELSE 'OK' END
    FROM bronze.attendance
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month

    UNION ALL
    SELECT
        'bronze',
        'bronze.students',
        COUNT_BIG(*),
        CAST(NULL AS BIGINT),
        CAST(NULL AS BIGINT),
        CASE WHEN COUNT_BIG(*) = 0 THEN 'CHECK' ELSE 'OK' END
    FROM bronze.students
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month

    UNION ALL
    SELECT
        'bronze',
        'bronze.assessment_results',
        COUNT_BIG(*),
        CAST(NULL AS BIGINT),
        CAST(NULL AS BIGINT),
        'INFO'
    FROM bronze.assessment_results
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month

    UNION ALL
    SELECT
        'bronze',
        'bronze.school_events',
        COUNT_BIG(*),
        CAST(NULL AS BIGINT),
        CAST(NULL AS BIGINT),
        'INFO'
    FROM bronze.school_events
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month

    UNION ALL
    SELECT
        'silver_to_gold',
        'student snapshot',
        (SELECT COUNT_BIG(*)
         FROM silver.student_monthly_status
         WHERE source_batch_id = @source_batch_id
           AND reporting_month = @reporting_month),
        (SELECT COUNT_BIG(*)
         FROM gold.fact_student_snapshot
         WHERE source_batch_id = @source_batch_id
           AND month_key = @month_key),
        (SELECT COUNT_BIG(*)
         FROM gold.fact_student_snapshot
         WHERE source_batch_id = @source_batch_id
           AND month_key = @month_key)
        -
        (SELECT COUNT_BIG(*)
         FROM silver.student_monthly_status
         WHERE source_batch_id = @source_batch_id
           AND reporting_month = @reporting_month),
        CASE
            WHEN (SELECT COUNT_BIG(*)
                  FROM silver.student_monthly_status
                  WHERE source_batch_id = @source_batch_id
                    AND reporting_month = @reporting_month)
               = (SELECT COUNT_BIG(*)
                  FROM gold.fact_student_snapshot
                  WHERE source_batch_id = @source_batch_id
                    AND month_key = @month_key)
            THEN 'OK'
            ELSE 'CHECK'
        END

    UNION ALL
    SELECT
        'silver_to_gold',
        'attendance facts',
        (SELECT COUNT_BIG(*)
         FROM silver.attendance_monthly
         WHERE source_batch_id = @source_batch_id
           AND reporting_month = @reporting_month),
        (SELECT COUNT_BIG(*)
         FROM gold.fact_attendance_monthly
         WHERE source_batch_id = @source_batch_id
           AND month_key = @month_key),
        (SELECT COUNT_BIG(*)
         FROM gold.fact_attendance_monthly
         WHERE source_batch_id = @source_batch_id
           AND month_key = @month_key)
        -
        (SELECT COUNT_BIG(*)
         FROM silver.attendance_monthly
         WHERE source_batch_id = @source_batch_id
           AND reporting_month = @reporting_month),
        CASE
            WHEN (SELECT COUNT_BIG(*)
                  FROM silver.attendance_monthly
                  WHERE source_batch_id = @source_batch_id
                    AND reporting_month = @reporting_month)
               = (SELECT COUNT_BIG(*)
                  FROM gold.fact_attendance_monthly
                  WHERE source_batch_id = @source_batch_id
                    AND month_key = @month_key)
            THEN 'OK'
            ELSE 'CHECK'
        END

    UNION ALL
    SELECT
        'quality_to_gold',
        'quality caveats',
        (SELECT COUNT_BIG(*)
         FROM quality.reporting_caveat
         WHERE source_batch_id = @source_batch_id
           AND reporting_month = @reporting_month),
        (SELECT COUNT_BIG(*)
         FROM gold.fact_data_quality_caveat
         WHERE source_batch_id = @source_batch_id
           AND month_key = @month_key),
        (SELECT COUNT_BIG(*)
         FROM gold.fact_data_quality_caveat
         WHERE source_batch_id = @source_batch_id
           AND month_key = @month_key)
        -
        (SELECT COUNT_BIG(*)
         FROM quality.reporting_caveat
         WHERE source_batch_id = @source_batch_id
           AND reporting_month = @reporting_month),
        CASE
            WHEN (SELECT COUNT_BIG(*)
                  FROM quality.reporting_caveat
                  WHERE source_batch_id = @source_batch_id
                    AND reporting_month = @reporting_month)
               = (SELECT COUNT_BIG(*)
                  FROM gold.fact_data_quality_caveat
                  WHERE source_batch_id = @source_batch_id
                    AND month_key = @month_key)
            THEN 'OK'
            ELSE 'CHECK'
        END
)
SELECT
    check_group,
    object_name,
    row_count,
    expected_or_comparison_count,
    difference_count,
    check_status
FROM counts
ORDER BY
    CASE check_group
        WHEN 'file_loads' THEN 1
        WHEN 'bronze' THEN 2
        WHEN 'silver_to_gold' THEN 3
        WHEN 'quality_to_gold' THEN 4
        ELSE 5
    END,
    object_name;

/* 3. Failed quality rules, caveats, and rejected records */
;WITH quality_details AS (
    SELECT
        'failed_rule' AS detail_type,
        source_table_name AS affected_object,
        rule_code,
        severity,
        CAST(failed_record_count AS BIGINT) AS record_count,
        CAST(NULL AS NVARCHAR(260)) AS business_key,
        CAST(NULL AS NVARCHAR(1000)) AS detail_message,
        checked_at AS detail_time
    FROM quality.validation_result
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
      AND result_status <> 'PASS'

    UNION ALL
    SELECT
        'caveat',
        rc.affected_area,
        rc.caveat_code,
        rc.severity,
        CAST(vr.failed_record_count AS BIGINT),
        CAST(NULL AS NVARCHAR(260)),
        CONCAT(rc.caveat_title, ': ', rc.caveat_description),
        rc.created_at
    FROM quality.reporting_caveat rc
    LEFT JOIN quality.validation_result vr
        ON vr.source_batch_id = rc.source_batch_id
       AND vr.reporting_month = rc.reporting_month
       AND vr.rule_code = rc.caveat_code
    WHERE rc.source_batch_id = @source_batch_id
      AND rc.reporting_month = @reporting_month

    UNION ALL
    SELECT
        'rejected_record',
        source_table_name,
        rule_code,
        CAST('ERROR' AS NVARCHAR(20)),
        CAST(1 AS BIGINT),
        business_key,
        rejection_reason,
        rejected_at
    FROM quality.rejected_record
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
)
SELECT
    detail_type,
    affected_object,
    rule_code,
    severity,
    record_count,
    business_key,
    detail_message,
    detail_time
FROM quality_details
ORDER BY
    CASE detail_type
        WHEN 'failed_rule' THEN 1
        WHEN 'caveat' THEN 2
        WHEN 'rejected_record' THEN 3
        ELSE 4
    END,
    rule_code,
    business_key;

/* 4. Reporting-view row counts for the selected month */
SELECT
    view_name,
    row_count,
    CASE
        WHEN view_name IN (
            'reporting.vw_monthly_attendance_summary',
            'reporting.vw_year_level_attendance_patterns',
            'reporting.vw_monthly_reporting_readiness'
        )
        AND row_count = 0 THEN 'CHECK'
        ELSE 'OK'
    END AS check_status
FROM (
    SELECT
        'reporting.vw_monthly_attendance_summary' AS view_name,
        COUNT_BIG(*) AS row_count
    FROM reporting.vw_monthly_attendance_summary
    WHERE reporting_month = @reporting_month

    UNION ALL
    SELECT
        'reporting.vw_year_level_attendance_patterns',
        COUNT_BIG(*)
    FROM reporting.vw_year_level_attendance_patterns
    WHERE reporting_month = @reporting_month

    UNION ALL
    SELECT
        'reporting.vw_attendance_assessment_relationship',
        COUNT_BIG(*)
    FROM reporting.vw_attendance_assessment_relationship

    UNION ALL
    SELECT
        'reporting.vw_monthly_reporting_readiness',
        COUNT_BIG(*)
    FROM reporting.vw_monthly_reporting_readiness
    WHERE reporting_month = @reporting_month

    UNION ALL
    SELECT
        'reporting.vw_data_quality_caveats',
        COUNT_BIG(*)
    FROM reporting.vw_data_quality_caveats
    WHERE reporting_month = @reporting_month
) view_counts
ORDER BY view_name;
