USE act_education_lakehouse;
GO

-- Drop reporting views first because they depend on curated tables.
DROP VIEW IF EXISTS dbo.vw_attendance_by_school;
DROP VIEW IF EXISTS dbo.vw_attendance_by_year_level;
DROP VIEW IF EXISTS dbo.vw_assessment_by_school;
DROP VIEW IF EXISTS dbo.vw_assessment_by_domain;
DROP VIEW IF EXISTS dbo.vw_data_quality_summary;
GO


-- Drop fact tables
IF OBJECT_ID('dbo.fact_school_events', 'U') IS NOT NULL
    DROP EXTERNAL TABLE dbo.fact_school_events;

IF OBJECT_ID('dbo.fact_assessment', 'U') IS NOT NULL
    DROP EXTERNAL TABLE dbo.fact_assessment;

IF OBJECT_ID('dbo.fact_attendance', 'U') IS NOT NULL
    DROP EXTERNAL TABLE dbo.fact_attendance;
GO

--- Drop dimension tables
IF OBJECT_ID('dbo.dim_event_type', 'U') IS NOT NULL
    DROP EXTERNAL TABLE dbo.dim_event_type;

IF OBJECT_ID('dbo.dim_assessment_domain', 'U') IS NOT NULL
    DROP EXTERNAL TABLE dbo.dim_assessment_domain;

IF OBJECT_ID('dbo.dim_date', 'U') IS NOT NULL
    DROP EXTERNAL TABLE dbo.dim_date;

IF OBJECT_ID('dbo.dim_student_group', 'U') IS NOT NULL
    DROP EXTERNAL TABLE dbo.dim_student_group;

IF OBJECT_ID('dbo.dim_school', 'U') IS NOT NULL
    DROP EXTERNAL TABLE dbo.dim_school;
GO



-- Drop Data Vault satellites.
IF OBJECT_ID('dbo.sat_event_details') IS NOT NULL
    DROP EXTERNAL TABLE dbo.sat_event_details;

IF OBJECT_ID('dbo.sat_assessment_result') IS NOT NULL
    DROP EXTERNAL TABLE dbo.sat_assessment_result;

IF OBJECT_ID('dbo.sat_attendance_record') IS NOT NULL
    DROP EXTERNAL TABLE dbo.sat_attendance_record;

IF OBJECT_ID('dbo.sat_student_details') IS NOT NULL
    DROP EXTERNAL TABLE dbo.sat_student_details;

IF OBJECT_ID('dbo.sat_school_details') IS NOT NULL
    DROP EXTERNAL TABLE dbo.sat_school_details;
GO

-- Drop Data Vault links.
IF OBJECT_ID('dbo.link_school_event') IS NOT NULL
    DROP EXTERNAL TABLE dbo.link_school_event;

IF OBJECT_ID('dbo.link_student_assessment') IS NOT NULL
    DROP EXTERNAL TABLE dbo.link_student_assessment;

IF OBJECT_ID('dbo.link_student_school') IS NOT NULL
    DROP EXTERNAL TABLE dbo.link_student_school;
GO

-- Drop Data Vault hubs.
IF OBJECT_ID('dbo.hub_event') IS NOT NULL
    DROP EXTERNAL TABLE dbo.hub_event;

IF OBJECT_ID('dbo.hub_assessment') IS NOT NULL
    DROP EXTERNAL TABLE dbo.hub_assessment;

IF OBJECT_ID('dbo.hub_student') IS NOT NULL
    DROP EXTERNAL TABLE dbo.hub_student;

IF OBJECT_ID('dbo.hub_school') IS NOT NULL
    DROP EXTERNAL TABLE dbo.hub_school;
GO

-- Drop materialized data quality result table.
IF OBJECT_ID('dbo.dq_validation_results_ext') IS NOT NULL
    DROP EXTERNAL TABLE dbo.dq_validation_results_ext;
GO


