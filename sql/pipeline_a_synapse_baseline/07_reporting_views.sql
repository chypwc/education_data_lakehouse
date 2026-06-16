-- Reporting views over curated dimensional tables.
-- These views are designed for SQL demos and optional Power BI reporting.

USE act_education_lakehouse;
GO

-- view for reporting: vw_attendance_by_school
DROP VIEW IF EXISTS dbo.vw_attendance_by_school;
GO

CREATE VIEW dbo.vw_attendance_by_school AS
SELECT
    ds.school_key,
    ds.school_name,
    ds.region,
    ds.school_type,
    dd.calendar_year,
    dd.calendar_month,
    dd.month_name,
    SUM(fa.possible_days) AS total_possible_days,
    SUM(fa.attended_days) AS total_attended_days,
    SUM(fa.absence_days) AS total_absence_days,
    CAST(
        SUM(fa.attended_days) * 1.0 / NULLIF(SUM(fa.possible_days), 0)
        AS DECIMAL(6,4)
    ) AS attendance_rate,
    CAST(
        1.0 - (SUM(fa.attended_days) * 1.0 / NULLIF(SUM(fa.possible_days), 0))
        AS DECIMAL(6,4)
    ) AS absence_rate,
    SUM(CASE WHEN fa.chronic_absence_flag = 1 THEN 1 ELSE 0 END) AS chronic_absence_records,
    SUM(CASE WHEN fa.is_valid_attendance = 0 THEN 1 ELSE 0 END) AS invalid_attendance_records
FROM dbo.fact_attendance AS fa
INNER JOIN dbo.dim_school AS ds
    ON fa.school_key = ds.school_key
INNER JOIN dbo.dim_date AS dd
    ON fa.date_key = dd.date_key
GROUP BY
    ds.school_key,
    ds.school_name,
    ds.region,
    ds.school_type,
    dd.calendar_year,
    dd.calendar_month,
    dd.month_name;
GO

SELECT TOP 100 *
FROM dbo.vw_attendance_by_school
ORDER BY calendar_year, calendar_month, school_name;

-- view for reporting vw_attendance_by_year_level
DROP VIEW IF EXISTS dbo.vw_attendance_by_year_level;
GO

CREATE VIEW dbo.vw_attendance_by_year_level AS
SELECT
    ds.school_key,
    ds.school_name,
    ds.region,
    ds.school_type,
    sg.year_level,
    sg.gender,
    sg.student_status,
    dd.calendar_year,
    dd.calendar_month,
    dd.month_name,
    SUM(fa.possible_days) AS total_possible_days,
    SUM(fa.attended_days) AS total_attended_days,
    SUM(fa.absence_days) AS total_absence_days,
    CAST(
        SUM(fa.attended_days) * 1.0 / NULLIF(SUM(fa.possible_days), 0)
        AS DECIMAL(6,4)
    ) AS attendance_rate,
    CAST(
        1.0 - (SUM(fa.attended_days) * 1.0 / NULLIF(SUM(fa.possible_days), 0))
        AS DECIMAL(6,4)
    ) AS absence_rate,
    SUM(CASE WHEN fa.chronic_absence_flag = 1 THEN 1 ELSE 0 END) AS chronic_absence_records,
    SUM(CASE WHEN fa.is_valid_attendance = 0 THEN 1 ELSE 0 END) AS invalid_attendance_records
FROM dbo.fact_attendance AS fa
INNER JOIN dbo.dim_school AS ds
    ON fa.school_key = ds.school_key
INNER JOIN dbo.dim_student_group AS sg
    ON fa.student_group_key = sg.student_group_key
INNER JOIN dbo.dim_date AS dd
    ON fa.date_key = dd.date_key
GROUP BY
    ds.school_key,
    ds.school_name,
    ds.region,
    ds.school_type,
    sg.year_level,
    sg.gender,
    sg.student_status,
    dd.calendar_year,
    dd.calendar_month,
    dd.month_name;
GO


SELECT TOP 20 *
FROM dbo.vw_attendance_by_year_level
ORDER BY calendar_year, calendar_month, school_name, year_level;

-- view for reporting: vw_assessment_by_school
DROP VIEW IF EXISTS dbo.vw_assessment_by_school;
GO

CREATE VIEW dbo.vw_assessment_by_school AS
SELECT
    ds.school_key,
    ds.school_name,
    ds.region,
    ds.school_type,
    dd.calendar_year AS assessment_year,
    ad.assessment_domain,
    COUNT_BIG(*) AS assessment_record_count,
    AVG(CASE WHEN fa.is_valid_score = 1 THEN CAST(fa.score AS FLOAT) END) AS average_score,
    SUM(CASE WHEN fa.proficiency_band = 'Low' THEN 1 ELSE 0 END) AS low_proficiency_count,
    SUM(CASE WHEN fa.proficiency_band = 'Medium' THEN 1 ELSE 0 END) AS medium_proficiency_count,
    SUM(CASE WHEN fa.proficiency_band = 'High' THEN 1 ELSE 0 END) AS high_proficiency_count,
    CAST(
        SUM(CASE WHEN fa.proficiency_band = 'Low' THEN 1 ELSE 0 END) * 1.0
        / NULLIF(COUNT_BIG(*), 0)
        AS DECIMAL(6,4)
    ) AS low_proficiency_rate,
    SUM(CASE WHEN fa.is_valid_score = 0 THEN 1 ELSE 0 END) AS invalid_score_records
FROM dbo.fact_assessment AS fa
INNER JOIN dbo.dim_school AS ds
    ON fa.school_key = ds.school_key
INNER JOIN dbo.dim_date AS dd
    ON fa.date_key = dd.date_key
INNER JOIN dbo.dim_assessment_domain AS ad
    ON fa.assessment_domain_key = ad.assessment_domain_key
GROUP BY
    ds.school_key,
    ds.school_name,
    ds.region,
    ds.school_type,
    dd.calendar_year,
    ad.assessment_domain;
GO

SELECT TOP 20 *
FROM dbo.vw_assessment_by_school
ORDER BY assessment_year, school_name, assessment_domain;
GO

-- view for reporting: vw_assessment_by_domain
DROP VIEW IF EXISTS dbo.vw_assessment_by_domain;
GO

CREATE VIEW dbo.vw_assessment_by_domain AS
SELECT
    dd.calendar_year AS assessment_year,
    ad.assessment_domain,
    COUNT_BIG(*) AS assessment_record_count,
    AVG(CASE WHEN fa.is_valid_score = 1 THEN CAST(fa.score AS FLOAT) END) AS average_score,
    SUM(CASE WHEN fa.proficiency_band = 'Low' THEN 1 ELSE 0 END) AS low_proficiency_count,
    SUM(CASE WHEN fa.proficiency_band = 'Medium' THEN 1 ELSE 0 END) AS medium_proficiency_count,
    SUM(CASE WHEN fa.proficiency_band = 'High' THEN 1 ELSE 0 END) AS high_proficiency_count,
    CAST(
        SUM(CASE WHEN fa.proficiency_band = 'Low' THEN 1 ELSE 0 END) * 1.0
        / NULLIF(COUNT_BIG(*), 0)
        AS DECIMAL(6,4)
    ) AS low_proficiency_rate,
    SUM(CASE WHEN fa.is_valid_score = 0 THEN 1 ELSE 0 END) AS invalid_score_records
FROM dbo.fact_assessment AS fa
INNER JOIN dbo.dim_date AS dd
    ON fa.date_key = dd.date_key
INNER JOIN dbo.dim_assessment_domain AS ad
    ON fa.assessment_domain_key = ad.assessment_domain_key
GROUP BY
    dd.calendar_year,
    ad.assessment_domain;
GO

SELECT *
FROM dbo.vw_assessment_by_domain
ORDER BY assessment_year, assessment_domain;
GO

-- view for reporting: vw_data_quality_summary
DROP VIEW IF EXISTS dbo.vw_data_quality_summary;
GO

CREATE VIEW dbo.vw_data_quality_summary AS
SELECT
    validation_id,
    check_name,
    table_name,
    failed_record_count,
    severity,
    CASE
        WHEN failed_record_count = 0 THEN 'Passed'
        ELSE 'Failed'
    END AS validation_status,
    run_timestamp
FROM dbo.dq_validation_results
WHERE validation_id IS NOT NULL;
GO


SELECT *
FROM dbo.vw_data_quality_summary
ORDER BY validation_id;
GO
