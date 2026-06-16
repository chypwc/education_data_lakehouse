-- Dim tables

IF OBJECT_ID('gold.dim_month', 'U') IS NULL
CREATE TABLE gold.dim_month (
    month_key INT NOT NULL PRIMARY KEY,
    reporting_month CHAR(7) NOT NULL,
    month_start_date DATE NOT NULL,
    calendar_year INT NOT NULL,
    calendar_month_number INT NOT NULL,
    calendar_month_name NVARCHAR(20) NOT NULL,
    school_year INT NOT NULL,
    school_term NVARCHAR(20) NULL,
    season NVARCHAR(20) NULL,
    prior_month_key INT NULL,
    is_winter_month BIT NOT NULL DEFAULT 0,
    loaded_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'UX_gold_dim_month_reporting_month'
      AND object_id = OBJECT_ID('gold.dim_month')
)
CREATE UNIQUE INDEX UX_gold_dim_month_reporting_month
ON gold.dim_month (reporting_month);
GO



IF OBJECT_ID('gold.dim_school', 'U') IS NULL
CREATE TABLE gold.dim_school (
    school_key INT NOT NULL PRIMARY KEY,
    school_id NVARCHAR(20) NOT NULL,
    school_name NVARCHAR(200) NOT NULL,
    region NVARCHAR(100) NULL,
    school_type NVARCHAR(50) NULL,
    status NVARCHAR(30) NULL,
    open_date DATE NULL,
    loaded_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO



IF OBJECT_ID('gold.dim_year_level', 'U') IS NULL
CREATE TABLE gold.dim_year_level (
    year_level_key INT NOT NULL PRIMARY KEY,
    year_level INT NOT NULL,
    year_level_label NVARCHAR(20) NOT NULL,
    cohort_group NVARCHAR(50) NOT NULL,
    sort_order INT NOT NULL
);
GO



IF OBJECT_ID('gold.dim_assessment_domain', 'U') IS NULL
CREATE TABLE gold.dim_assessment_domain (
    assessment_domain_key INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    domain NVARCHAR(50) NOT NULL,
    domain_sort_order INT NOT NULL
);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'UX_gold_dim_assessment_domain_domain'
      AND object_id = OBJECT_ID('gold.dim_assessment_domain')
)
CREATE UNIQUE INDEX UX_gold_dim_assessment_domain_domain
ON gold.dim_assessment_domain (domain);
GO



IF OBJECT_ID('gold.dim_attendance_band', 'U') IS NULL
CREATE TABLE gold.dim_attendance_band (
    attendance_band_key INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    attendance_band NVARCHAR(20) NOT NULL,
    lower_bound DECIMAL(6,4) NULL,
    upper_bound DECIMAL(6,4) NULL,
    band_sort_order INT NOT NULL
);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'UX_gold_dim_attendance_band_band'
      AND object_id = OBJECT_ID('gold.dim_attendance_band')
)
CREATE UNIQUE INDEX UX_gold_dim_attendance_band_band
ON gold.dim_attendance_band (attendance_band);
GO


-- Fact tables


IF OBJECT_ID('gold.fact_student_snapshot', 'U') IS NULL
CREATE TABLE gold.fact_student_snapshot (
    student_snapshot_fact_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    month_key INT NOT NULL,
    student_key INT NOT NULL,
    school_key INT NULL,
    year_level_key INT NULL,
    is_active_student BIT NOT NULL,
    source_batch_id NVARCHAR(50) NOT NULL,
    loaded_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_gold_fact_student_snapshot_month
        FOREIGN KEY (month_key)
        REFERENCES gold.dim_month (month_key),
    CONSTRAINT FK_gold_fact_student_snapshot_school
        FOREIGN KEY (school_key)
        REFERENCES gold.dim_school (school_key),
    CONSTRAINT FK_gold_fact_student_snapshot_year_level
        FOREIGN KEY (year_level_key)
        REFERENCES gold.dim_year_level (year_level_key)
);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'UX_gold_fact_student_snapshot_month_student'
      AND object_id = OBJECT_ID('gold.fact_student_snapshot')
)
CREATE UNIQUE INDEX UX_gold_fact_student_snapshot_month_student
ON gold.fact_student_snapshot (month_key, student_key);
GO

IF OBJECT_ID('gold.fact_attendance_monthly', 'U') IS NULL
CREATE TABLE gold.fact_attendance_monthly (
    attendance_fact_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    month_key INT NOT NULL,
    student_key INT NOT NULL,
    school_key INT NOT NULL,
    year_level_key INT NULL,
    attendance_band_key INT NULL,
    possible_days INT NOT NULL,
    attended_days INT NOT NULL,
    absent_days AS (possible_days - attended_days) PERSISTED,   -- automatically compute and update changes
    attendance_rate DECIMAL(6,4) NULL,
    source_batch_id NVARCHAR(50) NOT NULL,
    loaded_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_gold_fact_attendance_monthly_month
        FOREIGN KEY (month_key)
        REFERENCES gold.dim_month (month_key),
    CONSTRAINT FK_gold_fact_attendance_monthly_school
        FOREIGN KEY (school_key)
        REFERENCES gold.dim_school (school_key),
    CONSTRAINT FK_gold_fact_attendance_monthly_year_level
        FOREIGN KEY (year_level_key)
        REFERENCES gold.dim_year_level (year_level_key),
    CONSTRAINT FK_gold_fact_attendance_monthly_band
        FOREIGN KEY (attendance_band_key)
        REFERENCES gold.dim_attendance_band (attendance_band_key)
);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_gold_fact_attendance_monthly_month_school_year'
      AND object_id = OBJECT_ID('gold.fact_attendance_monthly')
)
CREATE INDEX IX_gold_fact_attendance_monthly_month_school_year
ON gold.fact_attendance_monthly (month_key, school_key, year_level_key);
GO

IF OBJECT_ID('gold.fact_assessment_result', 'U') IS NULL
CREATE TABLE gold.fact_assessment_result (
    assessment_fact_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    assessment_result_key BIGINT NOT NULL,
    assessment_year INT NOT NULL,
    student_key INT NOT NULL,
    school_key INT NOT NULL,
    year_level_key INT NULL,
    assessment_domain_key INT NOT NULL,
    attendance_band_key INT NULL,
    score DECIMAL(6,2) NOT NULL,
    source_batch_id NVARCHAR(50) NOT NULL,
    loaded_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_gold_fact_assessment_result_school
        FOREIGN KEY (school_key)
        REFERENCES gold.dim_school (school_key),
    CONSTRAINT FK_gold_fact_assessment_result_year_level
        FOREIGN KEY (year_level_key)
        REFERENCES gold.dim_year_level (year_level_key),
    CONSTRAINT FK_gold_fact_assessment_result_domain
        FOREIGN KEY (assessment_domain_key)
        REFERENCES gold.dim_assessment_domain (assessment_domain_key),
    CONSTRAINT FK_gold_fact_assessment_result_band
        FOREIGN KEY (attendance_band_key)
        REFERENCES gold.dim_attendance_band (attendance_band_key)
);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'UX_gold_fact_assessment_result_key'
      AND object_id = OBJECT_ID('gold.fact_assessment_result')
)
CREATE UNIQUE INDEX UX_gold_fact_assessment_result_key
ON gold.fact_assessment_result (assessment_result_key);
GO

IF OBJECT_ID('gold.fact_data_quality_caveat', 'U') IS NULL
CREATE TABLE gold.fact_data_quality_caveat (
    data_quality_caveat_fact_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    month_key INT NOT NULL,
    reporting_caveat_id BIGINT NULL,
    caveat_code NVARCHAR(100) NOT NULL,
    severity NVARCHAR(20) NOT NULL,
    affected_area NVARCHAR(100) NOT NULL,
    failed_record_count INT NOT NULL DEFAULT 0,
    source_batch_id NVARCHAR(50) NOT NULL,
    loaded_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_gold_fact_data_quality_caveat_month
        FOREIGN KEY (month_key)
        REFERENCES gold.dim_month (month_key)
);
GO

SELECT
    s.name AS schema_name,
    t.name AS table_name
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'gold'
ORDER BY t.name;
