USE [sqldb-edu-insights-dev];
GO
-- create a wrapper reconciliation procedure
CREATE OR ALTER PROCEDURE audit.usp_reconcile_bronze_to_silver
    @pipeline_run_id BIGINT = NULL,
    @source_batch_id NVARCHAR(50),
    @reporting_month CHAR(7)
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM audit.row_count_reconciliation
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
      AND layer_name = 'bronze_to_silver';

    DECLARE @source_row_count INT;
    DECLARE @target_row_count INT;

    SELECT @source_row_count = COUNT(*)
    FROM bronze.schools
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    SELECT @target_row_count = COUNT(*)
    FROM silver.school
    WHERE source_batch_id = @source_batch_id
      AND last_seen_reporting_month = @reporting_month;

    EXEC audit.usp_record_reconciliation
        @pipeline_run_id = @pipeline_run_id,
        @source_batch_id = @source_batch_id,
        @reporting_month = @reporting_month,
        @layer_name = 'bronze_to_silver',
        @object_name = 'school',
        @source_row_count = @source_row_count,
        @target_row_count = @target_row_count;

    SELECT @source_row_count = COUNT(*)
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

    SELECT @target_row_count = COUNT(*)
    FROM silver.student_monthly_status
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    EXEC audit.usp_record_reconciliation
        @pipeline_run_id = @pipeline_run_id,
        @source_batch_id = @source_batch_id,
        @reporting_month = @reporting_month,
        @layer_name = 'bronze_to_silver',
        @object_name = 'student_monthly_status',
        @source_row_count = @source_row_count,
        @target_row_count = @target_row_count;

    SELECT @source_row_count = COUNT(*)
    FROM bronze.attendance
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    SELECT @target_row_count = COUNT(*)
    FROM silver.attendance_monthly
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    EXEC audit.usp_record_reconciliation
        @pipeline_run_id = @pipeline_run_id,
        @source_batch_id = @source_batch_id,
        @reporting_month = @reporting_month,
        @layer_name = 'bronze_to_silver',
        @object_name = 'attendance_monthly',
        @source_row_count = @source_row_count,
        @target_row_count = @target_row_count;

    SELECT @source_row_count = COUNT(*)
    FROM bronze.assessment_results
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    SELECT @target_row_count = COUNT(*)
    FROM silver.assessment_result
    WHERE source_batch_id = @source_batch_id;

    EXEC audit.usp_record_reconciliation
        @pipeline_run_id = @pipeline_run_id,
        @source_batch_id = @source_batch_id,
        @reporting_month = @reporting_month,
        @layer_name = 'bronze_to_silver',
        @object_name = 'assessment_result',
        @source_row_count = @source_row_count,
        @target_row_count = @target_row_count;

    SELECT @source_row_count = COUNT(*)
    FROM bronze.school_events
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    SELECT @target_row_count = COUNT(*)
    FROM silver.school_event
    WHERE source_batch_id = @source_batch_id;

    EXEC audit.usp_record_reconciliation
        @pipeline_run_id = @pipeline_run_id,
        @source_batch_id = @source_batch_id,
        @reporting_month = @reporting_month,
        @layer_name = 'bronze_to_silver',
        @object_name = 'school_event',
        @source_row_count = @source_row_count,
        @target_row_count = @target_row_count;
END;
GO



--EXEC audit.usp_reconcile_bronze_to_silver
--    @pipeline_run_id = NULL,
--    @source_batch_id = '2024_01',
--    @reporting_month = '2024-01';


--SELECT
--    layer_name,
--    object_name,
--    source_row_count,
--    target_row_count,
--    difference_count,
--    reconciliation_status,
--    checked_at
--FROM audit.row_count_reconciliation
--WHERE source_batch_id = '2024_01'
--  AND reporting_month = '2024-01'
--  AND layer_name = 'bronze_to_silver'
--ORDER BY object_name;
