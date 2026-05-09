USE act_education_lakehouse;
GO

-- Create master key
IF NOT EXISTS (
    SELECT *
    FROM sys.symmetric_keys
    WHERE name = '##MS_DatabaseMasterKey##'
)
BEGIN
    CREATE MASTER KEY;
END;
GOCREATE MASTER KEY;
GO

-- DROP EXTERNAL FILE FORMAT parquet_format;
-- GO

-- DROP EXTERNAL DATA SOURCE education_lake;
-- GO

CREATE DATABASE SCOPED CREDENTIAL SynapseWorkspaceMI
WITH IDENTITY = 'Managed Identity';
GO

-- Create External Data Source
CREATE EXTERNAL DATA SOURCE education_lake
WITH (
    LOCATION = 'https://stactedulakehousechien.dfs.core.windows.net/education-data-lake',
    CREDENTIAL = SynapseWorkspaceMI
);
GO

-- Create Parquet File Format
CREATE EXTERNAL FILE FORMAT parquet_format
WITH (
    FORMAT_TYPE = PARQUET
);
GO

-- Verify Objects
SELECT name, location
FROM sys.external_data_sources;

SELECT name, format_type
FROM sys.external_file_formats;


