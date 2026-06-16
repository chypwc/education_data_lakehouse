
-- school level attendance summary
CREATE OR ALTER VIEW reporting.vw_monthly_attendance_summary AS
SELECT
    m.reporting_month,
    m.calendar_year,
    m.calendar_month_number,
    m.calendar_month_name,
    m.school_term,
    m.season,
    m.is_winter_month,
    s.region,
    s.school_type,
    s.status AS school_status,
    COUNT_BIG(*) AS attendance_record_count,
    COUNT(DISTINCT a.school_key) AS school_count,
    COUNT(DISTINCT a.student_key) AS student_count,
    SUM(a.possible_days) AS possible_days,
    SUM(a.attended_days) AS attended_days,
    SUM(a.absent_days) AS absent_days,
    CAST(
        CASE 
            WHEN SUM(a.possible_days) = 0 THEN NULL
            ELSE 1.0 * SUM(a.attended_days) / SUM(a.possible_days)
        END AS DECIMAL(6, 4)
    ) AS attendance_rate
FROM gold.fact_attendance_monthly a
JOIN gold.dim_month m
	ON a.month_key = m.month_key
JOIN gold.dim_school as s
	ON a.school_key = s.school_key
GROUP BY
	m.reporting_month,
    m.calendar_year,
    m.calendar_month_number,
    m.calendar_month_name,
    m.school_term,
    m.season,
    m.is_winter_month,
    s.region,
    s.school_type,
    s.status;
GO


-- year level attendance analysis
CREATE OR ALTER VIEW reporting.vw_year_level_attendance_patterns AS
SELECT
    m.reporting_month,
    m.calendar_year,
    m.calendar_month_number,
    m.calendar_month_name,
    m.school_term,
    m.season,
    s.region,
    s.school_type,
    y.year_level,
    y.year_level_label,
    y.cohort_group,
    y.sort_order AS year_level_sort_order,
    COUNT_BIG(*) AS attendance_record_count,
    COUNT(DISTINCT a.student_key) AS student_count,
    SUM(a.possible_days) AS possible_days,
    SUM(a.attended_days) AS attended_days,
    CAST(
        CASE
            WHEN SUM(a.possible_days) = 0 THEN NULL
            ELSE 1.0 * SUM(a.attended_days) / SUM(a.possible_days)
        END AS DECIMAL(6,4)
    ) AS attendance_rate
FROM gold.fact_attendance_monthly a
JOIN gold.dim_month m
    ON a.month_key = m.month_key
JOIN gold.dim_school s
    ON a.school_key = s.school_key
LEFT JOIN gold.dim_year_level y
    ON a.year_level_key = y.year_level_key
GROUP BY
    m.reporting_month,
    m.calendar_year,
    m.calendar_month_number,
    m.calendar_month_name,
    m.school_term,
    m.season,
    s.region,
    s.school_type,
    y.year_level,
    y.year_level_label,
    y.cohort_group,
    y.sort_order;
GO


-- attendance - assessment relationship
-- leave DAX to calculate average, median, p25, p75 under any slicer context.
CREATE OR ALTER VIEW reporting.vw_attendance_assessment_relationship AS
SELECT
    ar.assessment_result_key,
    ar.assessment_year,
    s.region,
    s.school_type,
    y.year_level,
    y.year_level_label,
    y.cohort_group,
    d.domain,
    d.domain_sort_order,
    b.attendance_band,
    b.band_sort_order AS attendance_band_sort_order,
    ar.score
FROM gold.fact_assessment_result ar
JOIN gold.dim_school s
    ON ar.school_key = s.school_key
LEFT JOIN gold.dim_year_level y
    ON ar.year_level_key = y.year_level_key
JOIN gold.dim_assessment_domain d
    ON ar.assessment_domain_key = d.assessment_domain_key
LEFT JOIN gold.dim_attendance_band b
    ON ar.attendance_band_key = b.attendance_band_key;
GO


CREATE OR ALTER VIEW reporting.vw_monthly_reporting_readiness AS
SELECT
    rr.reporting_month,
    rr.source_batch_id,
    rr.readiness_status,
    rr.blocker_count,
    rr.warning_count,
    rr.rejected_record_count,
    rr.readiness_summary,
    rr.checked_at
FROM quality.reporting_readiness rr;
GO

CREATE OR ALTER VIEW reporting.vw_data_quality_caveats AS
SELECT
    rc.reporting_month,
    rc.source_batch_id,
    rc.caveat_code,
    rc.caveat_title,
    rc.caveat_description,
    rc.severity,
    rc.affected_area,
    rc.recommended_action,
    rc.created_at
FROM quality.reporting_caveat rc;
GO

SELECT
    s.name AS schema_name,
    v.name AS view_name
FROM sys.views v
JOIN sys.schemas s ON v.schema_id = s.schema_id
WHERE s.name = 'reporting'
ORDER BY v.name;