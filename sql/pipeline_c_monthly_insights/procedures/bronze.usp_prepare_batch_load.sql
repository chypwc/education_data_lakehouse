USE [sqldb-edu-insights-dev];
GO

CREATE OR ALTER PROCEDURE bronze.usp_prepare_batch_load
    @source_batch_id NVARCHAR(50),
    @reporting_month CHAR(7)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRAN;

    DELETE FROM quality.rejected_record
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    DELETE FROM quality.reporting_caveat
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    DELETE FROM quality.reporting_readiness
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    DELETE FROM quality.validation_result
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    DELETE FROM audit.file_load
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    DELETE FROM audit.row_count_reconciliation
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    DELETE FROM bronze.school_events
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    DELETE FROM bronze.assessment_results
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    DELETE FROM bronze.attendance
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    DELETE FROM bronze.students
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    DELETE FROM bronze.schools
    WHERE source_batch_id = @source_batch_id
      AND reporting_month = @reporting_month;

    COMMIT TRAN;
END;
GO