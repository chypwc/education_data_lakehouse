-- Creates Synapse serverless SQL staging views over ADLS Gen2 files.

CREATE DATABASE act_education_lakehouse;
GO

USE act_education_lakehouse;
GO

DROP VIEW IF EXISTS dbo.stg_schools;
GO

CREATE VIEW dbo.stg_schools AS
SELECT
    CAST(school_id AS VARCHAR(20)) AS school_id,
    CAST(school_name AS VARCHAR(200)) AS school_name,
    CAST(region AS VARCHAR(100)) AS region,
    CAST(school_type AS VARCHAR(50)) AS school_type,
    TRY_CAST(open_date AS DATE) AS open_date,
    CAST(status AS VARCHAR(50)) AS status,
    CAST('schools.csv' AS VARCHAR(200)) AS source_file_name,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp
FROM OPENROWSET(
    BULK 'staging/stg_schools/schools.csv',
    DATA_SOURCE = 'education_lake',
    FORMAT = 'CSV',
    PARSER_VERSION = '2.0',
    HEADER_ROW = TRUE
) AS src;
GO

DROP VIEW IF EXISTS dbo.stg_students;
GO

CREATE VIEW dbo.stg_students AS
SELECT
    CAST(student_id AS VARCHAR(30)) AS student_id,
    CAST(school_id AS VARCHAR(20)) AS school_id,
    TRY_CAST(year_level AS INT) AS year_level,
    CAST(gender AS VARCHAR(50)) AS gender,
    TRY_CAST(enrolment_date AS DATE) AS enrolment_date,
    CAST(status AS VARCHAR(50)) AS status,
    CAST('students.csv' AS VARCHAR(200)) AS source_file_name,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp
FROM OPENROWSET(
    BULK 'staging/stg_students/students.csv',
    DATA_SOURCE = 'education_lake',
    FORMAT = 'CSV',
    PARSER_VERSION = '2.0',
    HEADER_ROW = TRUE
) AS src;
GO 


DROP VIEW IF EXISTS dbo.stg_attendance;
GO

CREATE VIEW dbo.stg_attendance AS
SELECT
    CAST(attendance_id AS VARCHAR(30)) AS attendance_id,
    CAST(student_id AS VARCHAR(30)) AS student_id,
    CAST(school_id AS VARCHAR(20)) AS school_id,
    TRY_CAST(attendance_month AS DATE) AS attendance_month,
    TRY_CAST(possible_days AS INT) AS possible_days,
    TRY_CAST(attended_days AS INT) AS attended_days,
    CAST(absence_reason AS VARCHAR(100)) AS absence_reason,
    CAST('attendance.csv' AS VARCHAR(200)) AS source_file_name,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp
FROM OPENROWSET(
    BULK 'staging/stg_attendance/attendance.csv',
    DATA_SOURCE = 'education_lake',
    FORMAT = 'CSV',
    PARSER_VERSION = '2.0',
    HEADER_ROW = TRUE
) AS src;
GO


DROP VIEW IF EXISTS dbo.stg_assessment_results;
GO

CREATE VIEW dbo.stg_assessment_results AS
SELECT
    CAST(assessment_id AS VARCHAR(30)) AS assessment_id,
    CAST(student_id AS VARCHAR(30)) AS student_id,
    CAST(school_id AS VARCHAR(20)) AS school_id,
    TRY_CAST(assessment_year AS INT) AS assessment_year,
    CAST(domain AS VARCHAR(50)) AS domain,
    TRY_CAST(score AS INT) AS score,
    CAST(proficiency_band AS VARCHAR(50)) AS proficiency_band,
    CAST('assessment_results.csv' AS VARCHAR(200)) AS source_file_name,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp
FROM OPENROWSET(
    BULK 'staging/stg_assessment_results/assessment_results.csv',
    DATA_SOURCE = 'education_lake',
    FORMAT = 'CSV',
    PARSER_VERSION = '2.0',
    HEADER_ROW = TRUE
) AS src;
GO


DROP VIEW IF EXISTS dbo.stg_school_events;
GO


-- OPENROWSET reads the JSON file as text.
-- OPENJSON splits the JSON array into rows.
-- JSON_VALUE extracts fields from each JSON object.
-- CAST/TRY_CAST standardises data types.
-- CREATE VIEW saves the logic as stg_school_events.

CREATE VIEW dbo.stg_school_events AS
SELECT
    CAST(JSON_VALUE(event_rows.value, '$.event_id') AS VARCHAR(30)) AS event_id,
    CAST(JSON_VALUE(event_rows.value, '$.school_id') AS VARCHAR(20)) AS school_id,
    CAST(JSON_VALUE(event_rows.value, '$.event_type') AS VARCHAR(100)) AS event_type,
    TRY_CAST(JSON_VALUE(event_rows.value, '$.event_date') AS DATE) AS event_date,
    CAST(JSON_VALUE(event_rows.value, '$.description') AS VARCHAR(500)) AS description,
    CAST('school_events.json' AS VARCHAR(200)) AS source_file_name,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp
FROM OPENROWSET(
    BULK 'staging/stg_school_events/school_events.json',
    DATA_SOURCE = 'education_lake',
    FORMAT = 'CSV',
    -- does not split the JSON by commas, quotes, or normal line breaks
    FIELDTERMINATOR = '0x0b',
    FIELDQUOTE = '0x0b',
    ROWTERMINATOR = '0x0b'
) WITH (
    -- names that whole text value: json_doc
    -- so now Synapse has one row with one big JSON string.
    json_doc VARCHAR(MAX)
) AS src
-- OPENJSON turns each object in the array into a row.
CROSS APPLY OPENJSON(src.json_doc) AS event_rows;
GO




SELECT TOP 10 * FROM stg_schools;
SELECT TOP 10 * FROM stg_students;
SELECT TOP 10 * FROM stg_attendance;
SELECT TOP 10 * FROM stg_assessment_results;
SELECT TOP 10 * FROM stg_school_events;


USE act_education_lakehouse;
GO

SELECT
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.VIEWS
ORDER BY TABLE_NAME;
