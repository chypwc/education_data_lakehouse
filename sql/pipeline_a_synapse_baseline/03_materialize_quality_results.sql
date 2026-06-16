USE act_education_lakehouse;
GO

CREATE EXTERNAL TABLE dbo.dq_validation_results_ext
WITH (
    LOCATION = 'quality/validation_results/dq_validation_results/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS 
SELECT
    validation_id,
    check_name,
    table_name,
    failed_record_count,
    severity,
    run_timestamp
FROM dbo.dq_validation_results;
GO

-- Check the saved parquet
-- SELECT TOP 20
--     *
-- FROM OPENROWSET(
--     BULK 'https://stactedulakehousechien.dfs.core.windows.net/education-data-lake/quality/validation_results/dq_validation_results/',
--     FORMAT = 'PARQUET'
-- ) AS q
-- ORDER BY validation_id;
