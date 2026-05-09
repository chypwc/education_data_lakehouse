-- Data quality checks for the ACT Education Azure Lakehouse project.
-- The script creates a reusable validation summary view over the staging views.
-- Each SELECT statement represents one data quality rule and returns the same
-- six columns so UNION ALL can stack the rule results into one monitoring view.

USE act_education_lakehouse;
GO

-- Drop the view first so this script can be rerun during development.
DROP VIEW IF EXISTS dbo.dq_validation_results;
GO

CREATE VIEW dbo.dq_validation_results AS

-- DQ001: student_id is the student business key and must be present.
SELECT
    CAST('DQ001' AS VARCHAR(20)) AS validation_id,
    CAST('Missing student_id in students' AS VARCHAR(200)) AS check_name,
    CAST('stg_students' AS VARCHAR(100)) AS table_name,
    COUNT_BIG(*) AS failed_record_count,
    CAST('High' AS VARCHAR(20)) AS severity,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS run_timestamp
FROM dbo.stg_students
-- TRIM removes surrounding spaces. NULLIF converts blank strings to NULL.
WHERE NULLIF(TRIM(student_id), '') IS NULL

UNION ALL

-- DQ002: school_id must be present so each student can be linked to a school.
SELECT
    CAST('DQ002' AS VARCHAR(20)) AS validation_id,
    CAST('Missing school_id in students' AS VARCHAR(200)) AS check_name,
    CAST('stg_students' AS VARCHAR(100)) AS table_name,
    COUNT_BIG(*) AS failed_record_count,
    CAST('High' AS VARCHAR(20)) AS severity,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS run_timestamp
FROM dbo.stg_students
WHERE NULLIF(TRIM(school_id), '') IS NULL

UNION ALL 

-- DQ003: attendance days must be numeric, non-negative, and attended days
-- cannot exceed possible school days.
SELECT
    CAST('DQ003' AS VARCHAR(20)) AS validation_id,
    CAST('Invalid attendance days' AS VARCHAR(200)) AS check_name,
    CAST('stg_attendance' AS VARCHAR(100)) AS table_name,
    COUNT_BIG(*) AS failed_record_count,
    CAST('High' AS VARCHAR(20)) AS severity,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS run_timestamp
FROM dbo.stg_attendance
WHERE possible_days IS NULL
   OR attended_days IS NULL
   OR possible_days < 0
   OR attended_days < 0
   OR attended_days > possible_days

UNION ALL

-- DQ004: detect duplicate attendance records at the business grain.
-- The business grain is one record per student, school, and attendance month.
-- This counts all rows involved in duplicate groups, not just the number of groups.
SELECT
    CAST('DQ004' AS VARCHAR(20)) AS validation_id,
    CAST('Duplicate attendance business records' AS VARCHAR(200)) AS check_name,
    CAST('stg_attendance' AS VARCHAR(100)) AS table_name,
    COUNT_BIG(*) AS failed_record_count,
    CAST('Medium' AS VARCHAR(20)) AS severity,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS run_timestamp
FROM dbo.stg_attendance AS a
INNER JOIN (
    SELECT 
        student_id,
        school_id,
        attendance_month
    FROM dbo.stg_attendance
    GROUP BY
        student_id,
        school_id,
        attendance_month
    HAVING COUNT_BIG(*) > 1
) AS duplicates
ON a.student_id = duplicates.student_id
    AND a.school_id = duplicates.school_id
    AND a.attendance_month = duplicates.attendance_month

UNION ALL

-- DQ005: every attendance record with a student_id should reference a student
-- that exists in stg_students. This is a referential integrity check.
SELECT 
    CAST('DQ005' AS VARCHAR(20)) AS validation_id,
    CAST('Attendance references missing student' AS VARCHAR(200)) AS check_name,
    CAST('stg_attendance' AS VARCHAR(100)) AS table_name,
    COUNT_BIG(*) AS failed_record_count,
    CAST('High' AS VARCHAR(20)) AS severity,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS run_timestamp
FROM dbo.stg_attendance AS a 
LEFT JOIN dbo.stg_students AS s
    ON a.student_id = s.student_id
WHERE NULLIF(TRIM(a.student_id), '') IS NOT NULL
    AND s.student_id IS NULL

UNION ALL 

-- DQ006: every assessment record with a student_id should reference a student
-- that exists in stg_students.
SELECT
    CAST('DQ006' AS VARCHAR(20)) AS validation_id,
    CAST('Assessment references missing student' AS VARCHAR(200)) AS check_name,
    CAST('stg_assessment_results' AS VARCHAR(100)) AS table_name,
    COUNT_BIG(*) AS failed_record_count,
    CAST('High' AS VARCHAR(20)) AS severity,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS run_timestamp
FROM dbo.stg_assessment_results AS ar
LEFT JOIN dbo.stg_students AS s
    ON ar.student_id = s.student_id
WHERE NULLIF(TRIM(ar.student_id), '') IS NOT NULL
  AND s.student_id IS NULL

UNION ALL

-- DQ007: assessment scores must be within the expected synthetic score range.
SELECT
    CAST('DQ007' AS VARCHAR(20)) AS validation_id,
    CAST('Invalid assessment score' AS VARCHAR(200)) AS check_name,
    CAST('stg_assessment_results' AS VARCHAR(100)) AS table_name,
    COUNT_BIG(*) AS failed_record_count,
    CAST('High' AS VARCHAR(20)) AS severity,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS run_timestamp
FROM dbo.stg_assessment_results
WHERE score IS NULL 
    OR score < 250
    OR score > 700

UNION ALL

-- DQ008: proficiency_band should use the controlled category values.
SELECT
    CAST('DQ008' AS VARCHAR(20)) AS validation_id,
    CAST('Invalid proficiency band' AS VARCHAR(200)) AS check_name,
    CAST('stg_assessment_results' AS VARCHAR(100)) AS table_name,
    COUNT_BIG(*) AS failed_record_count,
    CAST('Medium' AS VARCHAR(20)) AS severity,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS run_timestamp
FROM dbo.stg_assessment_results
WHERE NULLIF(TRIM(proficiency_band), '') IS NULL
   OR proficiency_band NOT IN ('Low', 'Medium', 'High')

UNION ALL

-- DQ009: school status should use the controlled category values.
SELECT
    CAST('DQ009' AS VARCHAR(20)) AS validation_id,
    CAST('Invalid school status' AS VARCHAR(200)) AS check_name,
    CAST('stg_schools' AS VARCHAR(100)) AS table_name,
    COUNT_BIG(*) AS failed_record_count,
    CAST('Medium' AS VARCHAR(20)) AS severity,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS run_timestamp
FROM dbo.stg_schools
WHERE NULLIF(TRIM(status), '') IS NULL
   OR status NOT IN ('Active', 'Closed')

UNION ALL

-- DQ010: attendance_month should not be after the current UTC date.
SELECT
    CAST('DQ010' AS VARCHAR(20)) AS validation_id,
    CAST('Future attendance month' AS VARCHAR(200)) AS check_name,
    CAST('stg_attendance' AS VARCHAR(100)) AS table_name,
    COUNT_BIG(*) AS failed_record_count,
    CAST('Medium' AS VARCHAR(20)) AS severity,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS run_timestamp
FROM dbo.stg_attendance
WHERE attendance_month > CAST(SYSUTCDATETIME() AS DATE)

UNION ALL 

-- DQ011: operational records should be reviewed if linked to closed schools.
SELECT
    CAST('DQ011' AS VARCHAR(20)) AS validation_id,
    CAST('Activity linked to inactive school' AS VARCHAR(200)) AS check_name,
    CAST('multiple staging views' AS VARCHAR(100)) AS table_name,
    COUNT_BIG(*) AS failed_record_count,
    CAST('Low' AS VARCHAR(20)) AS severity,
    CAST(SYSUTCDATETIME() AS DATETIME2) AS run_timestamp
FROM (
    SELECT a.school_id
    FROM dbo.stg_attendance AS a
    INNER JOIN dbo.stg_schools AS s
        ON a.school_id = s.school_id
    WHERE s.status = 'Closed'

    UNION ALL

    SELECT ar.school_id
    FROM dbo.stg_assessment_results AS ar
    INNER JOIN dbo.stg_schools AS s
        ON ar.school_id = s.school_id
    WHERE s.status = 'Closed'

    UNION ALL

    SELECT e.school_id
    FROM dbo.stg_school_events AS e
    INNER JOIN dbo.stg_schools AS s
        ON e.school_id = s.school_id
    WHERE s.status = 'Closed'
) AS inactive_school_activity;
GO


-- Summary query for screenshot/export evidence.
SELECT *
FROM dbo.dq_validation_results
ORDER BY validation_id;


-- Optional detail query: inspect duplicate attendance groups.
-- SELECT
--     student_id,
--     school_id,
--     attendance_month,
--     COUNT_BIG(*) AS duplicate_count
-- FROM dbo.stg_attendance
-- GROUP BY
--     student_id,
--     school_id,
--     attendance_month
-- HAVING COUNT_BIG(*) > 1;
