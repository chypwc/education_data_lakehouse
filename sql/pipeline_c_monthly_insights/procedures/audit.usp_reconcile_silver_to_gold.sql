USE [sqldb-edu-insights-dev];
GO


CREATE OR ALTER PROCEDURE audit.usp_reconcile_silver_to_gold
    @pipeline_run_id BIGINT = NULL,
    @source_batch_id NVARCHAR(50),
    @reporting_month CHAR(7)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @month_key INT = TRY_CONVERT(INT, REPLACE(@reporting_month, '-', ''));
    DECLARE @source_row_count INT;
    DECLARE @target_row_count INT;

    DELETE FROM audit.row_count_reconciliation
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month
      AND layer_name = 'silver_to_gold';

    SELECT @source_row_count = COUNT(*)
    FROM silver.student_monthly_status
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    SELECT @target_row_count = COUNT(*)
    FROM gold.fact_student_snapshot
    WHERE source_batch_id = @source_batch_id
      AND month_key = @month_key;

    EXEC audit.usp_record_reconciliation
        @pipeline_run_id = @pipeline_run_id,
        @source_batch_id = @source_batch_id,
        @reporting_month = @reporting_month,
        @layer_name = 'silver_to_gold',
        @object_name = 'fact_student_snapshot',
        @source_row_count = @source_row_count,
        @target_row_count = @target_row_count;

    SELECT @source_row_count = COUNT(*)
    FROM silver.attendance_monthly
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    SELECT @target_row_count = COUNT(*)
    FROM gold.fact_attendance_monthly
    WHERE source_batch_id = @source_batch_id
      AND month_key = @month_key;

    EXEC audit.usp_record_reconciliation
        @pipeline_run_id = @pipeline_run_id,
        @source_batch_id = @source_batch_id,
        @reporting_month = @reporting_month,
        @layer_name = 'silver_to_gold',
        @object_name = 'fact_attendance_monthly',
        @source_row_count = @source_row_count,
        @target_row_count = @target_row_count;

    SELECT @source_row_count = COUNT(*)
    FROM silver.assessment_result
    WHERE source_batch_id = @source_batch_id;

    SELECT @target_row_count = COUNT(*)
    FROM gold.fact_assessment_result
    WHERE source_batch_id = @source_batch_id;

    EXEC audit.usp_record_reconciliation
        @pipeline_run_id = @pipeline_run_id,
        @source_batch_id = @source_batch_id,
        @reporting_month = @reporting_month,
        @layer_name = 'silver_to_gold',
        @object_name = 'fact_assessment_result',
        @source_row_count = @source_row_count,
        @target_row_count = @target_row_count;

    SELECT @source_row_count = COUNT(*)
    FROM quality.reporting_caveat
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    SELECT @target_row_count = COUNT(*)
    FROM gold.fact_data_quality_caveat
    WHERE source_batch_id = @source_batch_id
      AND month_key = @month_key;

    EXEC audit.usp_record_reconciliation
        @pipeline_run_id = @pipeline_run_id,
        @source_batch_id = @source_batch_id,
        @reporting_month = @reporting_month,
        @layer_name = 'silver_to_gold',
        @object_name = 'fact_data_quality_caveat',
        @source_row_count = @source_row_count,
        @target_row_count = @target_row_count;
END;
GO


--EXEC audit.usp_reconcile_silver_to_gold
--    @pipeline_run_id = NULL,
--    @source_batch_id = '2024_01',
--    @reporting_month = '2024-01';
--GO


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
--  AND layer_name = 'silver_to_gold'
--ORDER BY object_name;

