USE [sqldb-edu-insights-dev];
GO

CREATE OR ALTER PROCEDURE audit.usp_start_pipeline_run
    -- input/output values passed into the procedure.
	@pipeline_name NVARCHAR(150),
    @adf_run_id NVARCHAR(100) = NULL,    -- Optional
    @source_batch_id NVARCHAR(50),
    @reporting_month CHAR(7),
    @load_mode NVARCHAR(30),
    @trigger_file NVARCHAR(260) = NULL,  -- Optional
    @pipeline_run_id BIGINT OUTPUT       -- output parameter
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO audit.pipeline_run (
        pipeline_name,
        adf_run_id,
        source_batch_id,
        reporting_month,
        load_mode,
        trigger_file,
        run_status,
        started_at
    )
    VALUES (
        @pipeline_name,
        @adf_run_id,
        @source_batch_id,
        @reporting_month,
        @load_mode,
        @trigger_file,
        'STARTED',
        SYSUTCDATETIME()
    );

    -- SQL automatically creates the next ID. SCOPE_IDENTITY() gets that new ID.
    SET @pipeline_run_id = SCOPE_IDENTITY();

    -- Returns the new run ID as a result table
    SELECT
        @pipeline_run_id AS pipeline_run_id;
END;
GO


-- Test
-- DECLARE @pipeline_run_id BIGINT;    -- local variable to receive the output value

-- EXEC audit.usp_start_pipeline_run
--     @pipeline_name = 'pl_monthly_insights',
--     @adf_run_id = NULL,
--     @source_batch_id = 'TEST_2024_01',
--     @reporting_month = '2024-01',
--     @load_mode = 'INITIAL_SNAPSHOT',
--     @trigger_file = '_READY.json',
--     @pipeline_run_id = @pipeline_run_id OUTPUT;

-- SELECT @pipeline_run_id AS pipeline_run_id;

-- SELECT TOP 5 *
-- FROM audit.pipeline_run
-- ORDER BY pipeline_run_id DESC;


-- DELETE FROM audit.pipeline_run
-- WHERE source_batch_id LIKE 'TEST_%';

-- SELECT *
-- FROM audit.pipeline_run
-- ORDER BY pipeline_run_id DESC;