-- Materialises a lightweight Data Vault layer to ADLS Gen2 as Parquet files.
-- This script uses CETAS: CREATE EXTERNAL TABLE AS SELECT.
-- Output folders must be empty before rerunning each CREATE EXTERNAL TABLE.

USE act_education_lakehouse;
GO

-- Hubs = business keys
-- Links = relationships
-- Satellites = descriptive details / history

-- A Data Vault hub stores business keys.
-- hub_school
CREATE EXTERNAL TABLE dbo.hub_school
WITH (
    LOCATION = 'vault/hubs/hub_school/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS 
SELECT DISTINCT
    CAST(school_id AS VARCHAR(20)) AS school_id,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp,
    CAST(source_file_name AS VARCHAR(200)) AS record_source
FROM dbo.stg_schools
WHERE NULLIF(TRIM(school_id), '') IS NOT NULL;
GO

SELECT TOP 10 *
FROM dbo.hub_school;
GO

-- hub_student: student_id
CREATE EXTERNAL TABLE dbo.hub_student
WITH (
    LOCATION = 'vault/hubs/hub_student/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT DISTINCT
    CAST(student_id AS VARCHAR(30)) AS student_id,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp,
    CAST(source_file_name AS VARCHAR(200)) AS record_source
FROM dbo.stg_students
WHERE NULLIF(TRIM(student_id), '') IS NOT NULL;
GO

SELECT TOP 10 *
FROM dbo.hub_student;
GO 

SELECT COUNT_BIG(*) AS student_hub_count
FROM dbo.hub_student;
GO

-- hub_assessment: assessment_id
CREATE EXTERNAL TABLE dbo.hub_assessment
WITH (
    LOCATION = 'vault/hubs/hub_assessment/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT DISTINCT
    CAST(assessment_id AS VARCHAR(30)) AS assessment_id,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp,
    CAST(source_file_name AS VARCHAR(200)) AS record_source
FROM dbo.stg_assessment_results
WHERE NULLIF(TRIM(assessment_id), '') IS NOT NULL;
GO

SELECT TOP 10 *
FROM dbo.hub_assessment;
GO

SELECT COUNT_BIG(*) AS assessment_hub_count
FROM dbo.hub_assessment;
GO

-- hub_event: event_id
CREATE EXTERNAL TABLE dbo.hub_event
WITH (
    LOCATION = 'vault/hubs/hub_event/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT DISTINCT
    CAST(event_id AS VARCHAR(30)) AS event_id,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp,
    CAST(source_file_name AS VARCHAR(200)) AS record_source
FROM dbo.stg_school_events
WHERE NULLIF(TRIM(event_id), '') IS NOT NULL;
GO

SELECT TOP 10 *
FROM dbo.hub_event;
GO

SELECT COUNT_BIG(*) AS event_hub_count
FROM dbo.hub_event;
GO


-- In Data Vault, links store relationships between hubs.
-- link_student_school: student_id -> school_id
CREATE EXTERNAL TABLE dbo.link_student_school
WITH (
    LOCATION = 'vault/links/link_student_school/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT DISTINCT
    CAST(s.student_id AS VARCHAR(30)) AS student_id,
    CAST(s.school_id AS VARCHAR(20)) AS school_id,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp,
    CAST(s.source_file_name AS VARCHAR(200)) AS record_source
FROM dbo.stg_students AS s
INNER JOIN dbo.hub_student AS hs 
    ON s.student_id = hs.student_id
INNER JOIN dbo.hub_school AS hsc 
    ON s.school_id = hsc.school_id
WHERE NULLIF(TRIM(s.student_id), '') IS NOT NULL
    AND NULLIF(TRIM(s.school_id), '') IS NOT NULL;
GO

SELECT TOP 10 *
FROM dbo.link_student_school;
GO

SELECT COUNT_BIG(*) AS link_student_school_count
FROM dbo.link_student_school;
GO

-- link_student_assessment: student_id -> assessment_id
CREATE EXTERNAL TABLE dbo.link_student_assessment
WITH (
    LOCATION = 'vault/links/link_student_assessment/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT DISTINCT
    CAST(ar.student_id AS VARCHAR(30)) AS student_id,
    CAST(ar.assessment_id AS VARCHAR(30)) AS assessment_id,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp,
    CAST(ar.source_file_name AS VARCHAR(200)) AS record_source
FROM dbo.stg_assessment_results AS ar 
INNER JOIN dbo.hub_student AS hs 
    ON ar.student_id = hs.student_id
INNER JOIN dbo.hub_assessment AS ha 
    ON ar.assessment_id = ha.assessment_id
WHERE NULLIF(TRIM(ar.student_id), '') IS NOT NULL
  AND NULLIF(TRIM(ar.assessment_id), '') IS NOT NULL;
GO

SELECT TOP 10 *
FROM dbo.link_student_assessment;
GO 

SELECT COUNT_BIG(*) AS link_student_assessment_count
FROM dbo.link_student_assessment;
GO

-- link_school_event: school_id -> event_id
CREATE EXTERNAL TABLE dbo.link_school_event
WITH (
    LOCATION = 'vault/links/link_school_event/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT DISTINCT
    CAST(e.school_id AS VARCHAR(20)) AS school_id,
    CAST(e.event_id AS VARCHAR(30)) AS event_id,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp,
    CAST(e.source_file_name AS VARCHAR(200)) AS record_source
FROM dbo.stg_school_events AS e
INNER JOIN dbo.hub_school AS hs
    ON e.school_id = hs.school_id
INNER JOIN dbo.hub_event AS he
    ON e.event_id = he.event_id
WHERE NULLIF(TRIM(e.school_id), '') IS NOT NULL
  AND NULLIF(TRIM(e.event_id), '') IS NOT NULL;
GO

SELECT TOP 10 *
FROM dbo.link_school_event;
GO

SELECT COUNT_BIG(*) AS link_school_event_count
FROM dbo.link_school_event;
GO

-- Satellites
CREATE EXTERNAL TABLE dbo.sat_school_details
WITH (
    LOCATION = 'vault/satellites/sat_school_details/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT DISTINCT
    CAST(s.school_id AS VARCHAR(20)) AS school_id,
    CAST(s.school_name AS VARCHAR(200)) AS school_name,
    CAST(s.region AS VARCHAR(100)) AS region,
    CAST(s.school_type AS VARCHAR(50)) AS school_type,
    CAST(s.open_date AS DATE) AS open_date,
    CAST(s.status AS VARCHAR(50)) AS status,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp,
    CAST(s.source_file_name AS VARCHAR(200)) AS record_source
FROM dbo.stg_schools AS s
INNER JOIN dbo.hub_school AS hs
    ON s.school_id = hs.school_id
WHERE NULLIF(TRIM(s.school_id), '') IS NOT NULL;
GO

SELECT COUNT_BIG(*) AS sat_school_details_count
FROM dbo.sat_school_details;
GO

SELECT TOP 10 *
FROM dbo.sat_school_details;
GO

-- sat_student_details
CREATE EXTERNAL TABLE dbo.sat_student_details
WITH (
    LOCATION = 'vault/satellites/sat_student_details/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT DISTINCT
    CAST(s.student_id AS VARCHAR(30)) AS student_id,
    CAST(s.school_id AS VARCHAR(20)) AS school_id,
    CAST(s.year_level AS INT) AS year_level,
    CAST(s.gender AS VARCHAR(50)) AS gender,
    CAST(s.enrolment_date AS DATE) AS enrolment_date,
    CAST(s.status AS VARCHAR(50)) AS status,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp,
    CAST(s.source_file_name AS VARCHAR(200)) AS record_source
FROM dbo.stg_students AS s
INNER JOIN dbo.hub_student AS hs
    ON s.student_id = hs.student_id
WHERE NULLIF(TRIM(s.student_id), '') IS NOT NULL;
GO

SELECT TOP 10 *
FROM dbo.sat_student_details;
GO

SELECT COUNT_BIG(*) AS sat_student_details_count
FROM dbo.sat_student_details;
GO

-- sat_attendance_record
CREATE EXTERNAL TABLE dbo.sat_attendance_record
WITH (
    LOCATION = 'vault/satellites/sat_attendance_record/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT
    CAST(a.attendance_id AS VARCHAR(30)) AS attendance_id,
    CAST(a.student_id AS VARCHAR(30)) AS student_id,
    CAST(a.school_id AS VARCHAR(20)) AS school_id,
    CAST(a.attendance_month AS DATE) AS attendance_month,
    CAST(a.possible_days AS INT) AS possible_days,
    CAST(a.attended_days AS INT) AS attended_days,
    CAST(a.absence_reason AS VARCHAR(100)) AS absence_reason,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp,
    CAST(a.source_file_name AS VARCHAR(200)) AS record_source
FROM dbo.stg_attendance AS a
WHERE NULLIF(TRIM(a.attendance_id), '') IS NOT NULL;
GO

SELECT TOP 10 *
FROM dbo.sat_attendance_record;
GO

SELECT COUNT_BIG(*) AS sat_attendance_record_count
FROM dbo.sat_attendance_record;
GO

-- sat_assessment_result
CREATE EXTERNAL TABLE dbo.sat_assessment_result
WITH (
    LOCATION = 'vault/satellites/sat_assessment_result/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT
    CAST(ar.assessment_id AS VARCHAR(30)) AS assessment_id,
    CAST(ar.student_id AS VARCHAR(30)) AS student_id,
    CAST(ar.school_id AS VARCHAR(20)) AS school_id,
    CAST(ar.assessment_year AS INT) AS assessment_year,
    CAST(ar.domain AS VARCHAR(50)) AS domain,
    CAST(ar.score AS INT) AS score,
    CAST(ar.proficiency_band AS VARCHAR(50)) AS proficiency_band,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp,
    CAST(ar.source_file_name AS VARCHAR(200)) AS record_source
FROM dbo.stg_assessment_results AS ar
WHERE NULLIF(TRIM(ar.assessment_id), '') IS NOT NULL;
GO

SELECT TOP 10 *
FROM dbo.sat_assessment_result;
GO

SELECT COUNT_BIG(*) AS sat_assessment_result_count
FROM dbo.sat_assessment_result;
GO


-- sat_event_details
CREATE EXTERNAL TABLE dbo.sat_event_details
WITH (
    LOCATION = 'vault/satellites/sat_event_details/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT
    CAST(e.event_id AS VARCHAR(30)) AS event_id,
    CAST(e.school_id AS VARCHAR(20)) AS school_id,
    CAST(e.event_type AS VARCHAR(100)) AS event_type,
    CAST(e.event_date AS DATE) AS event_date,
    CAST(e.description AS VARCHAR(500)) AS description,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp,
    CAST(e.source_file_name AS VARCHAR(200)) AS record_source
FROM dbo.stg_school_events AS e
WHERE NULLIF(TRIM(e.event_id), '') IS NOT NULL;
GO

SELECT TOP 10 *
FROM dbo.sat_event_details;
GO

SELECT COUNT_BIG(*) AS sat_event_details_count
FROM dbo.sat_event_details;
GO