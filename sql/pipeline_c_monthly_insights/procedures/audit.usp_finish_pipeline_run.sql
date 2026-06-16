USE [sqldb-edu-insights-dev];
GO

CREATE OR ALTER PROCEDURE audit.usp_finish_pipeline_run
    @pipeline_run_id BIGINT,
    @run_status NVARCHAR(30),
    @error_message NVARCHAR(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @run_status NOT IN ('SUCCEEDED', 'FAILED')
    BEGIN
        THROW 50001, 'run_status must be SUCCEEDED or FAILED.', 1;
    END;

    UPDATE audit.pipeline_run
    SET
        run_status = @run_status,
        ended_at = SYSUTCDATETIME(),
        error_message = @error_message
    WHERE pipeline_run_id = @pipeline_run_id;

    IF @@ROWCOUNT = 0
    BEGIN
        THROW 50002, 'No audit.pipeline_run row found for the supplied pipeline_run_id.', 1;
    END;

    SELECT
        pipeline_run_id,
        pipeline_name,
        source_batch_id,
        reporting_month,
        load_mode,
        run_status,
        started_at,
        ended_at,
        error_message
    FROM audit.pipeline_run
    WHERE pipeline_run_id = @pipeline_run_id;
END;
GO


-- Test
-- DECLARE @pipeline_run_id BIGINT;

-- EXEC audit.usp_start_pipeline_run
--     @pipeline_name = 'test_pl_monthly_insights',
--     @adf_run_id = NULL,
--     @source_batch_id = 'TEST_2024_01',
--     @reporting_month = '2024-01',
--     @load_mode = 'INITIAL_SNAPSHOT',
--     @trigger_file = '_READY.json',
--     @pipeline_run_id = @pipeline_run_id OUTPUT;

-- EXEC audit.usp_finish_pipeline_run
--     @pipeline_run_id = @pipeline_run_id,
--     @run_status = 'SUCCEEDED',
--     @error_message = NULL;


-- -- Cleanup test
-- DELETE FROM audit.pipeline_run
-- WHERE source_batch_id = 'TEST_2024_01';