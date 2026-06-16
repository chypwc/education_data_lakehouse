USE [sqldb-edu-insights-dev];
GO

-- school
IF OBJECT_ID('silver.school', 'U') IS NULL
CREATE TABLE silver.school (
    school_key INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    school_id NVARCHAR(20) NOT NULL,
    school_name NVARCHAR(200) NOT NULL,
    region NVARCHAR(100) NULL,
    school_type NVARCHAR(50) NULL,
    open_date DATE NULL,
    status NVARCHAR(30) NULL,
    source_batch_id NVARCHAR(50) NOT NULL,
    effective_from_month CHAR(7) NOT NULL,
    last_seen_reporting_month CHAR(7) NOT NULL,
    record_hash VARBINARY(32) NULL,
    validation_status NVARCHAR(30) NOT NULL DEFAULT 'Valid',
    loaded_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(3) NULL
);
GO

-- Create a unique index on silver.school(school_id)
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'UX_silver_school_school_id'
        AND object_id = OBJECT_ID('silver.school')
) 
CREATE UNIQUE INDEX UX_silver_school_school_id
ON silver.school(school_id);
GO


-- student
IF OBJECT_ID('silver.student', 'U') IS NULL
CREATE TABLE silver.student (
    student_key INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    student_id NVARCHAR(50) NOT NULL,
    current_school_key INT NULL,
    current_school_id NVARCHAR(20) NULL,
    current_year_level INT NULL,
    gender NVARCHAR(30) NULL,
    enrolment_date DATE NULL,
    status NVARCHAR(30) NULL,
    source_batch_id NVARCHAR(50) NOT NULL,
    effective_from_month CHAR(7) NOT NULL,
    last_seen_reporting_month CHAR(7) NOT NULL,
    record_hash VARBINARY(32) NULL,
    validation_status NVARCHAR(30) NOT NULL DEFAULT 'Valid',
    loaded_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(3) NULL,
    CONSTRAINT FK_silver_student_current_school
        FOREIGN KEY (current_school_key)
        REFERENCES silver.school(school_key)
);
GO


IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'UX_silver_student_student_id'
      AND object_id = OBJECT_ID('silver.student')
)
CREATE UNIQUE INDEX UX_silver_student_student_id
ON silver.student (student_id);
GO


-- student_monthly_status
IF OBJECT_ID('silver.student_monthly_status', 'U') IS NULL
CREATE TABLE silver.student_monthly_status (
    student_monthly_status_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    reporting_month CHAR(7) NOT NULL,
    student_key INT NOT NULL,
    school_key INT NULL,
    year_level INT NULL,
    gender NVARCHAR(30) NULL,
    student_status NVARCHAR(30) NULL,
    source_batch_id NVARCHAR(50) NOT NULL,
    validation_status NVARCHAR(30) NOT NULL DEFAULT 'Valid',
    loaded_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_silver_student_monthly_status_student
        FOREIGN KEY (student_key)
        REFERENCES silver.student (student_key),
    CONSTRAINT FK_silver_student_monthly_status_school
        FOREIGN KEY (school_key)
        REFERENCES silver.school (school_key)
);
GO


IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'UX_silver_student_monthly_status_month_student'
      AND object_id = OBJECT_ID('silver.student_monthly_status')
)
CREATE UNIQUE INDEX UX_silver_student_monthly_status_month_student
ON silver.student_monthly_status (reporting_month, student_key);
GO



-- attendance_monthly
IF OBJECT_ID('silver.attendance_monthly', 'U') IS NULL
CREATE TABLE silver.attendance_monthly (
    attendance_monthly_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    attendance_id NVARCHAR(50) NOT NULL,
    reporting_month CHAR(7) NOT NULL,
    attendance_month DATE NOT NULL,
    student_key INT NOT NULL,
    school_key INT NOT NULL,
    possible_days INT NOT NULL,
    attended_days INT NOT NULL,
    attendance_rate DECIMAL(6,4) NULL,
    absence_reason NVARCHAR(100) NULL,
    attendance_band NVARCHAR(20) NULL,
    source_batch_id NVARCHAR(50) NOT NULL,
    validation_status NVARCHAR(30) NOT NULL DEFAULT 'Valid',
    loaded_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_silver_attendance_monthly_student
        FOREIGN KEY (student_key)
        REFERENCES silver.student (student_key),
    CONSTRAINT FK_silver_attendance_monthly_school
        FOREIGN KEY (school_key)
        REFERENCES silver.school (school_key),
    CONSTRAINT CK_silver_attendance_possible_days
        CHECK (possible_days >= 0),
    CONSTRAINT CK_silver_attendance_attended_days
        CHECK (attended_days >= 0 AND attended_days <= possible_days)
);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'UX_silver_attendance_monthly_attendance_id'
      AND object_id = OBJECT_ID('silver.attendance_monthly')
)
CREATE UNIQUE INDEX UX_silver_attendance_monthly_attendance_id
ON silver.attendance_monthly (attendance_id);
GO


-- assessment_result
IF OBJECT_ID('silver.assessment_result', 'U') IS NULL
CREATE TABLE silver.assessment_result (
    assessment_result_key BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    assessment_id NVARCHAR(40) NOT NULL,
    student_key INT NOT NULL,
    school_key INT NOT NULL,
    assessment_year INT NOT NULL,
    domain NVARCHAR(50) NOT NULL,
    score DECIMAL(6,2) NOT NULL,
    proficiency_band NVARCHAR(30) NULL,
    source_batch_id NVARCHAR(50) NOT NULL,
    validation_status NVARCHAR(30) NOT NULL DEFAULT 'Valid',
    loaded_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_silver_assessment_result_student
        FOREIGN KEY (student_key)
        REFERENCES silver.student (student_key),
    CONSTRAINT FK_silver_assessment_result_school
        FOREIGN KEY (school_key)
        REFERENCES silver.school (school_key),
    CONSTRAINT CK_silver_assessment_score
        CHECK (score >= 0 AND score <= 1000)
);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'UX_silver_assessment_result_assessment_id'
      AND object_id = OBJECT_ID('silver.assessment_result')
)
CREATE UNIQUE INDEX UX_silver_assessment_result_assessment_id
ON silver.assessment_result (assessment_id);
GO


-- school_event
IF OBJECT_ID('silver.school_event', 'U') IS NULL
CREATE TABLE silver.school_event (
    school_event_key BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    event_id NVARCHAR(30) NOT NULL,
    school_key INT NOT NULL,
    event_type NVARCHAR(100) NOT NULL,
    event_date DATE NOT NULL,
    description NVARCHAR(500) NULL,
    source_batch_id NVARCHAR(50) NOT NULL,
    validation_status NVARCHAR(30) NOT NULL DEFAULT 'Valid',
    loaded_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_silver_school_event_school
        FOREIGN KEY (school_key)
        REFERENCES silver.school (school_key)
);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'UX_silver_school_event_event_id'
      AND object_id = OBJECT_ID('silver.school_event')
)
CREATE UNIQUE INDEX UX_silver_school_event_event_id
ON silver.school_event (event_id);
GO


SELECT
    s.name AS schema_name,
    t.name AS table_name
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'silver'
ORDER BY t.name;
