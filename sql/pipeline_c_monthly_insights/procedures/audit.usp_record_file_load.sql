USE [sqldb-edu-insights-dev];
GO

CREATE OR ALTER PROCEDURE audit.usp_record_file_load
    @pipeline_run_id BIGINT = NULL,
    @source_batch_id NVARCHAR(50),
    @reporting_month CHAR(7),
    @source_file_name NVARCHAR(260),
    @target_table_name NVARCHAR(150),
    @source_row_count INT = NULL,
    @loaded_row_count INT = NULL,
    @rejected_row_count INT = 0,
    @load_status NVARCHAR(30) = 'LOADED'
AS
BEGIN
    SET NOCOUNT ON;

    IF @load_status NOT IN ('LOADED', 'PARTIAL', 'FAILED', 'SKIPPED')
    BEGIN
        THROW 50003, 'load_status must be LOADED, PARTIAL, FAILED, or SKIPPED.', 1;
    END;

    INSERT INTO audit.file_load (
        pipeline_run_id,
        source_batch_id,
        reporting_month,
        source_file_name,
        target_table_name,
        source_row_count,
        loaded_row_count,
        rejected_row_count,
        load_status,
        loaded_at
    )
    VALUES (
        @pipeline_run_id,
        @source_batch_id,
        @reporting_month,
        @source_file_name,
        @target_table_name,
        @source_row_count,
        @loaded_row_count,
        @rejected_row_count,
        @load_status,
        SYSUTCDATETIME()
    );

    SELECT
        file_load_id,
        pipeline_run_id,
        source_batch_id,
        reporting_month,
        source_file_name,
        target_table_name,
        source_row_count,
        loaded_row_count,
        rejected_row_count,
        load_status,
        loaded_at
    FROM audit.file_load
    WHERE file_load_id = SCOPE_IDENTITY();
END;
GO


-- Test 
-- EXEC audit.usp_record_file_load
--     @pipeline_run_id = NULL,
--     @source_batch_id = 'TEST_2024_01',
--     @reporting_month = '2024-01',
--     @source_file_name = 'students.csv',
--     @target_table_name = 'bronze.students',
--     @source_row_count = 10000,
--     @loaded_row_count = 10000,
--     @rejected_row_count = 0,
--     @load_status = 'LOADED';


-- DELETE FROM audit.file_load
-- WHERE source_batch_id LIKE 'TEST_%';