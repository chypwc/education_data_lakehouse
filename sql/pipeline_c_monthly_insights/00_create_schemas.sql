USE [sqldb-edu-insights-dev];
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
	EXEC('CREATE SCHEMA bronze');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
	EXEC('CREATE SCHEMA silver');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'quality')
	EXEC('CREATE SCHEMA quality');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
	EXEC('CREATE SCHEMA gold');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'reporting')
	EXEC('CREATE SCHEMA reporting');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'audit')
	EXEC('CREATE SCHEMA audit');
GO

SELECT
    name AS schema_name
FROM sys.schemas
WHERE name IN ('bronze', 'silver', 'quality', 'gold', 'reporting', 'audit')
ORDER BY name;