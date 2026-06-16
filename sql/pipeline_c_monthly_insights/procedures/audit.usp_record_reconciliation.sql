USE [sqldb-edu-insights-dev];
GO

CREATE OR ALTER PROCEDURE audit.usp_record_reconciliation
    @pipeline_run_id BIGINT = NULL,
    @source_batch_id NVARCHAR(50),
    @reporting_month CHAR(7),
    @layer_name NVARCHAR(30),
    @object_name NVARCHAR(150),
    @source_row_count INT = NULL,
    @target_row_count INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @difference_count INT;
    DECLARE @reconciliation_status NVARCHAR(30);

    SET @difference_count = 
        CASE
            WHEN @source_row_count IS NULL OR @target_row_count IS NULL THEN NULL
            ELSE @target_row_count - @source_row_count
        END;

    SET @reconciliation_status =
        CASE
            WHEN @source_row_count IS NULL OR @target_row_count IS NULL THEN 'WARNING'
            WHEN @source_row_count = @target_row_count THEN 'PASS'
            ELSE 'FAIL'
        END;


    INSERT INTO audit.row_count_reconciliation (
        pipeline_run_id,
        source_batch_id,
        reporting_month,
        layer_name,
        object_name,
        source_row_count,
        target_row_count,
        difference_count,
        reconciliation_status,
        checked_at
    )
    VALUES (
        @pipeline_run_id,
        @source_batch_id,
        @reporting_month,
        @layer_name,
        @object_name,
        @source_row_count,
        @target_row_count,
        @difference_count,
        @reconciliation_status,
        SYSUTCDATETIME()
    );

    SELECT
        reconciliation_id,
        pipeline_run_id,
        source_batch_id,
        reporting_month,
        layer_name,
        object_name,
        source_row_count,
        target_row_count,
        difference_count,
        reconciliation_status,
        checked_at
    FROM audit.row_count_reconciliation
    WHERE reconciliation_id = SCOPE_IDENTITY();
END;
GO


-- EXEC audit.usp_record_reconciliation
--     @pipeline_run_id = NULL,
--     @source_batch_id = 'TEST_2024_01',
--     @reporting_month = '2024-01',
--     @layer_name = 'bronze_to_silver',
--     @object_name = 'students',
--     @source_row_count = 10000,
--     @target_row_count = 10000;



-- EXEC audit.usp_record_reconciliation
--     @pipeline_run_id = NULL,
--     @source_batch_id = 'TEST_2024_01',
--     @reporting_month = '2024-01',
--     @layer_name = 'bronze_to_silver',
--     @object_name = 'attendance',
--     @source_row_count = 10000,
--     @target_row_count = 9998;


-- DELETE FROM audit.row_count_reconciliation
-- WHERE source_batch_id LIKE 'TEST_%';