USE [sqldb-edu-insights-dev];
GO

CREATE OR ALTER PROCEDURE reporting.usp_validate_reporting_views
AS
BEGIN
    SET NOCOUNT ON;  -- Stops SQL Server from returning extra messages like: (5 rows affected)

    -- Creates a temporary in-memory table variable inside the procedure.
    DECLARE @validation_results TABLE (
        view_name SYSNAME NOT NULL,     -- SYSNAME is SQL Server’s built-in type for object names
        validation_status NVARCHAR(20) NOT NULL,
        row_count BIGINT NULL,
        validation_message NVARCHAR(1000) NULL
    );

    BEGIN TRY
        INSERT INTO @validation_results
        SELECT
            'reporting.vw_monthly_attendance_summary',
            'PASS',
            COUNT_BIG(*),
            'View queried successfully.'
        FROM reporting.vw_monthly_attendance_summary;
    END TRY
    BEGIN CATCH
        INSERT INTO @validation_results
        VALUES (
            'reporting.vw_monthly_attendance_summary',
            'FAIL',
            NULL,
            ERROR_MESSAGE()
        );
    END CATCH;

    BEGIN TRY
        INSERT INTO @validation_results
        SELECT
            'reporting.vw_year_level_attendance_patterns',
            'PASS',
            COUNT_BIG(*),
            'View queried successfully.'
        FROM reporting.vw_year_level_attendance_patterns;
    END TRY
    BEGIN CATCH
        INSERT INTO @validation_results
        VALUES (
            'reporting.vw_year_level_attendance_patterns',
            'FAIL',
            NULL,
            ERROR_MESSAGE()
        );
    END CATCH;

    BEGIN TRY
        INSERT INTO @validation_results
        SELECT
            'reporting.vw_attendance_assessment_relationship',
            'PASS',
            COUNT_BIG(*),
            'View queried successfully.'
        FROM reporting.vw_attendance_assessment_relationship;
    END TRY
    BEGIN CATCH
        INSERT INTO @validation_results
        VALUES (
            'reporting.vw_attendance_assessment_relationship',
            'FAIL',
            NULL,
            ERROR_MESSAGE()
        );
    END CATCH;

    BEGIN TRY
        INSERT INTO @validation_results
        SELECT
            'reporting.vw_monthly_reporting_readiness',
            'PASS',
            COUNT_BIG(*),
            'View queried successfully.'
        FROM reporting.vw_monthly_reporting_readiness;
    END TRY
    BEGIN CATCH
        INSERT INTO @validation_results
        VALUES (
            'reporting.vw_monthly_reporting_readiness',
            'FAIL',
            NULL,
            ERROR_MESSAGE()
        );
    END CATCH;

    BEGIN TRY
        INSERT INTO @validation_results
        SELECT
            'reporting.vw_data_quality_caveats',
            'PASS',
            COUNT_BIG(*),
            'View queried successfully.'
        FROM reporting.vw_data_quality_caveats;
    END TRY
    BEGIN CATCH
        INSERT INTO @validation_results
        VALUES (
            'reporting.vw_data_quality_caveats',
            'FAIL',
            NULL,
            ERROR_MESSAGE()
        );
    END CATCH;

    SELECT
        view_name,
        validation_status,
        row_count,
        validation_message
    FROM @validation_results
    ORDER BY view_name;
END;
GO

-- EXEC reporting.usp_validate_reporting_views;