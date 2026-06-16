USE [sqldb-edu-insights-dev];
GO

IF OBJECT_ID('bronze.schools', 'U') IS NULL
CREATE TABLE bronze.schools (
    bronze_school_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    source_batch_id NVARCHAR(50) NOT NULL,
    reporting_month CHAR(7) NOT NULL,
    source_file_name NVARCHAR(260) NOT NULL,
    raw_row_number INT NULL,
    loaded_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    school_id NVARCHAR(20) NULL,
    school_name NVARCHAR(200) NULL,
    region NVARCHAR(100) NULL,
    school_type NVARCHAR(50) NULL,
    open_date NVARCHAR(30) NULL,
    status NVARCHAR(30) NULL
);
GO

IF OBJECT_ID('bronze.students', 'U') IS NULL
CREATE TABLE bronze.students (
    bronze_student_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    source_batch_id NVARCHAR(50) NOT NULL,
    reporting_month CHAR(7) NOT NULL,
    source_file_name NVARCHAR(260) NOT NULL,
    raw_row_number INT NULL,
    loaded_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    student_id NVARCHAR(50) NULL,
    school_id NVARCHAR(20) NULL,
    year_level NVARCHAR(10) NULL,
    gender NVARCHAR(30) NULL,
    enrolment_date NVARCHAR(30) NULL,
    status NVARCHAR(30) NULL
);
GO

IF OBJECT_ID('bronze.attendance', 'U') IS NULL
CREATE TABLE bronze.attendance (
    bronze_attendance_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    source_batch_id NVARCHAR(50) NOT NULL,
    reporting_month CHAR(7) NOT NULL,
    source_file_name NVARCHAR(260) NOT NULL,
    raw_row_number INT NULL,
    loaded_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    attendance_id NVARCHAR(50) NULL,
    student_id NVARCHAR(50) NULL,
    school_id NVARCHAR(20) NULL,
    attendance_month NVARCHAR(30) NULL,
    possible_days NVARCHAR(20) NULL,
    attended_days NVARCHAR(20) NULL,
    absence_reason NVARCHAR(100) NULL
);
GO

IF OBJECT_ID('bronze.assessment_results', 'U') IS NULL
CREATE TABLE bronze.assessment_results (
    bronze_assessment_result_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    source_batch_id NVARCHAR(50) NOT NULL,
    reporting_month CHAR(7) NOT NULL,
    source_file_name NVARCHAR(260) NOT NULL,
    raw_row_number INT NULL,
    loaded_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    assessment_id NVARCHAR(40) NULL,
    student_id NVARCHAR(50) NULL,
    school_id NVARCHAR(20) NULL,
    assessment_year NVARCHAR(10) NULL,
    domain NVARCHAR(50) NULL,
    score NVARCHAR(20) NULL,
    proficiency_band NVARCHAR(30) NULL
);
GO


IF OBJECT_ID('bronze.school_events', 'U') IS NULL
CREATE TABLE bronze.school_events (
    bronze_school_event_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    source_batch_id NVARCHAR(50) NOT NULL,
    reporting_month CHAR(7) NOT NULL,
    source_file_name NVARCHAR(260) NOT NULL,
    raw_row_number INT NULL,
    loaded_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    event_id NVARCHAR(30) NULL,
    school_id NVARCHAR(20) NULL,
    event_type NVARCHAR(100) NULL,
    event_date NVARCHAR(30) NULL,
    description NVARCHAR(500) NULL
);
GO

SELECT
    s.name AS schema_name,
    t.name AS table_name
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'bronze'
ORDER BY t.name;
