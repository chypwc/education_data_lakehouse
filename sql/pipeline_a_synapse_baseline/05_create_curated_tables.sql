-- Materialises curated dimensional tables to ADLS Gen2 as Parquet files.
-- Curated tables are designed for reporting and Power BI-style consumption.
-- Output folders must be empty before rerunning each CREATE EXTERNAL TABLE.

USE act_education_lakehouse;
GO

-- DROP EXTERNAL TABLE dbo.dim_school;
-- GO

-- dim_school
CREATE EXTERNAL TABLE dbo.dim_school
WITH (
    LOCATION = 'curated/dimensions/dim_school/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT
    school_id AS school_key,
    school_name,
    region,
    school_type,
    open_date,
    status,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp
FROM dbo.sat_school_details
WHERE NULLIF(TRIM(school_id), '') IS NOT NULL
  AND NULLIF(TRIM(school_name), '') IS NOT NULL
  AND school_type IN ('Primary', 'High School', 'College', 'Specialist')
  AND status IN ('Active', 'Closed');
GO


SELECT TOP 10 *
FROM dbo.dim_school;
GO



-- dim_student_group
-- DROP EXTERNAL TABLE dbo.dim_student_group;
-- GO

CREATE EXTERNAL TABLE dbo.dim_student_group
WITH (
    LOCATION = 'curated/dimensions/dim_student_group/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY
            s.school_id,
            s.year_level,
            s.gender,
            s.status
    ) AS student_group_key,
    s.school_id AS school_key,
    s.year_level,
    s.gender,
    s.status AS student_status,
    COUNT_BIG(*) AS student_count,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp
FROM dbo.sat_student_details AS s
INNER JOIN dbo.dim_school AS ds
    ON s.school_id = ds.school_key
WHERE NULLIF(TRIM(s.student_id), '') IS NOT NULL
  AND NULLIF(TRIM(s.school_id), '') IS NOT NULL
  AND s.year_level BETWEEN 0 AND 12
  AND s.gender IN ('Female', 'Male', 'Non-specified')
  AND s.status IN ('Active', 'Transferred', 'Left')
GROUP BY
    s.school_id,
    s.year_level,
    s.gender,
    s.status;
GO

SELECT TOP 10 *
FROM dbo.dim_student_group;
GO

-- dim_date
CREATE EXTERNAL TABLE dbo.dim_date
WITH (
    LOCATION = 'curated/dimensions/dim_date/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT DISTINCT
    date_key,
    calendar_date,
    calendar_year,
    calendar_month,
    month_name,
    calendar_quarter,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp
FROM (
    SELECT
        CONVERT(INT, FORMAT(attendance_month, 'yyyyMMdd')) AS date_key,
        attendance_month AS calendar_date,
        YEAR(attendance_month) AS calendar_year,
        MONTH(attendance_month) AS calendar_month,
        DATENAME(MONTH, attendance_month) AS month_name,
        DATEPART(QUARTER, attendance_month) AS calendar_quarter
    FROM dbo.sat_attendance_record
    WHERE attendance_month IS NOT NULL
        AND attendance_month <=CAST(SYSUTCDATETIME() AS DATE)

    UNION

    SELECT
        CONVERT(INT, FORMAT(event_date, 'yyyyMMdd')) AS date_key,
        event_date AS calendar_date,
        YEAR(event_date) AS calendar_year,
        MONTH(event_date) AS calendar_month,
        DATENAME(MONTH, event_date) AS month_name,
        DATEPART(QUARTER, event_date) AS calendar_quarter
    FROM dbo.sat_event_details
    WHERE event_date IS NOT NULL
      AND event_date <= CAST(SYSUTCDATETIME() AS DATE)

    UNION

    SELECT
        assessment_year * 10000 + 101 AS date_key,  -- For 2024, 2024 * 10000 + 101 = 20240101
        DATEFROMPARTS(assessment_year, 1, 1) AS calendar_date,
        assessment_year AS calendar_year,
        1 AS calendar_month,
        CAST('January' AS VARCHAR(20)) AS month_name,
        1 AS calendar_quarter
    FROM dbo.sat_assessment_result
    WHERE assessment_year IS NOT NULL
      AND assessment_year BETWEEN 2000 AND YEAR(CAST(SYSUTCDATETIME() AS DATE))
) AS dates;
GO

SELECT TOP 20 *
FROM dbo.dim_date
ORDER BY calendar_date;
GO

-- dim_assessment_domain
CREATE EXTERNAL TABLE dbo.dim_assessment_domain
WITH (
    LOCATION = 'curated/dimensions/dim_assessment_domain/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY domain
    ) AS assessment_domain_key,
    domain AS assessment_domain,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp
FROM (
    SELECT DISTINCT
        domain
    FROM dbo.sat_assessment_result
    WHERE NULLIF(TRIM(domain), '') IS NOT NULL
      AND domain IN ('Reading', 'Numeracy', 'Writing')
) AS domains;
GO

SELECT *
FROM dbo.dim_assessment_domain
ORDER BY assessment_domain_key;
GO

-- dim_event_type
CREATE EXTERNAL TABLE dbo.dim_event_type
WITH (
    LOCATION = 'curated/dimensions/dim_event_type/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY event_type
    ) AS event_type_key,
    event_type,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp
FROM (
    SELECT DISTINCT
        event_type
    FROM dbo.sat_event_details
    WHERE NULLIF(TRIM(event_type), '') IS NOT NULL
      AND event_type IN (
          'Attendance campaign',
          'Wellbeing program',
          'Assessment intervention'
      )
) AS event_types;
GO

SELECT *
FROM dbo.dim_event_type
ORDER BY event_type_key;
GO


-- Fact tables
-- fact_attendance
CREATE EXTERNAL TABLE dbo.fact_attendance
WITH (
    LOCATION = 'curated/facts/fact_attendance/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT
    a.attendance_id,
    a.student_id,
    a.school_id AS school_key,
    d.date_key,
    sg.student_group_key,
    a.possible_days,
    a.attended_days,
    a.possible_days - a.attended_days AS absence_days,
    CAST(a.attended_days * 1.0 / NULLIF(a.possible_days, 0) AS DECIMAL(6, 4)) AS attendance_rate,
    CAST(1.0 - (a.attended_days * 1.0 / NULLIF(a.possible_days, 0)) AS DECIMAL(6, 4)) AS absence_rate,
    CASE 
        WHEN a.possible_days > 0
            AND a.attended_days * 1.0 / a.possible_days < 0.9
        THEN 1
        ELSE 0
    END AS chronic_absence_flag,
    CASE
        WHEN a.possible_days IS NULL
          OR a.attended_days IS NULL
          OR a.possible_days < 0
          OR a.attended_days < 0
          OR a.attended_days > a.possible_days
        THEN 0
        ELSE 1
    END AS is_valid_attendance,
     CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp
FROM dbo.sat_attendance_record AS a
INNER JOIN dbo.dim_school AS ds
    ON a.school_id = ds.school_key
INNER JOIN dbo.dim_date AS d
    ON a.attendance_month = d.calendar_date
-- To bridge student_id to school_key. Use student_group_key in fact table
-- sat_student_details = internal vault detail
-- dim_student_group = reporting-safe aggregate dimension
-- fact_assessment = links to student_group_key
INNER JOIN dbo.sat_student_details AS s  
    ON a.student_id = s.student_id
INNER JOIN dbo.dim_student_group AS sg
    ON s.school_id = sg.school_key
   AND s.year_level = sg.year_level
   AND s.gender = sg.gender
   AND s.status = sg.student_status
WHERE NULLIF(TRIM(a.attendance_id), '') IS NOT NULL
  AND NULLIF(TRIM(a.student_id), '') IS NOT NULL
  AND NULLIF(TRIM(a.school_id), '') IS NOT NULL
  AND a.attendance_month IS NOT NULL;
GO


SELECT TOP 10 *
FROM dbo.fact_attendance;
GO

SELECT
    is_valid_attendance,
    COUNT_BIG(*) AS record_count
FROM dbo.fact_attendance
GROUP BY is_valid_attendance;
GO



-- fact_assessment
CREATE EXTERNAL TABLE dbo.fact_assessment
WITH (
    LOCATION = 'curated/facts/fact_assessment/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT
    ar.assessment_id,
    ar.student_id,
    ar.school_id AS school_key,
    d.date_key,
    ad.assessment_domain_key,
    sg.student_group_key,
    ar.score,
    ar.proficiency_band,
    CASE
        WHEN ar.score IS NULL
          OR ar.score < 250
          OR ar.score > 700
        THEN 0
        ELSE 1
    END AS is_valid_score,
    CASE
        WHEN ar.proficiency_band = 'Low' THEN 1
        ELSE 0
    END AS low_proficiency_flag,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp
FROM dbo.sat_assessment_result AS ar
INNER JOIN dbo.dim_school AS ds
    ON ar.school_id = ds.school_key
INNER JOIN dbo.dim_date AS d
    ON DATEFROMPARTS(ar.assessment_year, 1, 1) = d.calendar_date
INNER JOIN dbo.dim_assessment_domain AS ad
    ON ar.domain = ad.assessment_domain
INNER JOIN dbo.sat_student_details AS s
    ON ar.student_id = s.student_id
INNER JOIN dbo.dim_student_group AS sg
    ON s.school_id = sg.school_key
   AND s.year_level = sg.year_level
   AND s.gender = sg.gender
   AND s.status = sg.student_status
WHERE NULLIF(TRIM(ar.assessment_id), '') IS NOT NULL
  AND NULLIF(TRIM(ar.student_id), '') IS NOT NULL
  AND NULLIF(TRIM(ar.school_id), '') IS NOT NULL
  AND ar.assessment_year IS NOT NULL
  AND ar.assessment_year BETWEEN 2000 AND YEAR(CAST(SYSUTCDATETIME() AS DATE))
  AND NULLIF(TRIM(ar.domain), '') IS NOT NULL;
GO

SELECT TOP 10 *
FROM dbo.fact_assessment;
GO

SELECT
    is_valid_score,
    COUNT_BIG(*) AS record_count
FROM dbo.fact_assessment
GROUP BY is_valid_score;
GO


-- fact_school_events
CREATE EXTERNAL TABLE dbo.fact_school_events
WITH (
    LOCATION = 'curated/facts/fact_school_events/',
    DATA_SOURCE = education_lake,
    FILE_FORMAT = parquet_format
)
AS
SELECT
    e.event_id,
    e.school_id AS school_key,
    d.date_key,
    et.event_type_key,
    1 AS event_count,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS load_timestamp
FROM dbo.sat_event_details AS e
INNER JOIN dbo.dim_school AS ds
    ON e.school_id = ds.school_key
INNER JOIN dbo.dim_date AS d
    ON e.event_date = d.calendar_date
INNER JOIN dbo.dim_event_type AS et
    ON e.event_type = et.event_type
WHERE NULLIF(TRIM(e.event_id), '') IS NOT NULL
  AND NULLIF(TRIM(e.school_id), '') IS NOT NULL
  AND e.event_date IS NOT NULL
  AND e.event_date <= CAST(SYSUTCDATETIME() AS DATE)
  AND NULLIF(TRIM(e.event_type), '') IS NOT NULL;
GO


SELECT TOP 10 *
FROM dbo.fact_school_events;
GO

SELECT COUNT_BIG(*) AS fact_school_events_count
FROM dbo.fact_school_events;
GO