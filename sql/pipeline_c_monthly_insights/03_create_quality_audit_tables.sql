IF OBJECT_ID('audit.pipeline_run', 'U') IS NULL
CREATE TABLE audit.pipeline_run (
    pipeline_run_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    pipeline_name NVARCHAR(150) NOT NULL,
    adf_run_id NVARCHAR(100) NULL,
    source_batch_id NVARCHAR(50) NOT NULL,
    reporting_month CHAR(7) NOT NULL,
    load_mode NVARCHAR(30) NOT NULL,
    trigger_file NVARCHAR(260) NULL,
    run_status NVARCHAR(30) NOT NULL DEFAULT 'STARTED',
    started_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    ended_at DATETIME2(3) NULL,
    error_message NVARCHAR(2000) NULL
);
GO


IF OBJECT_ID('audit.batch_load', 'U') IS NULL
CREATE TABLE audit.batch_load (
    batch_load_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    pipeline_run_id BIGINT NULL,
    source_batch_id NVARCHAR(50) NOT NULL,
    reporting_month CHAR(7) NOT NULL,
    load_mode NVARCHAR(30) NOT NULL,
    source_folder NVARCHAR(500) NOT NULL,
    batch_status NVARCHAR(30) NOT NULL DEFAULT 'RECEIVED',
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO


IF OBJECT_ID('audit.file_load', 'U') IS NULL
CREATE TABLE audit.file_load (
    file_load_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    pipeline_run_id BIGINT NULL,
    source_batch_id NVARCHAR(50) NOT NULL,
    reporting_month CHAR(7) NOT NULL,
    source_file_name NVARCHAR(260) NOT NULL,
    target_table_name NVARCHAR(150) NOT NULL,
    source_row_count INT NULL,
    loaded_row_count INT NULL,
    rejected_row_count INT NULL,
    load_status NVARCHAR(30) NOT NULL DEFAULT 'LOADED',
    loaded_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO


IF OBJECT_ID('audit.row_count_reconciliation', 'U') IS NULL
CREATE TABLE audit.row_count_reconciliation (
    reconciliation_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    pipeline_run_id BIGINT NULL,
    source_batch_id NVARCHAR(50) NOT NULL,
    reporting_month CHAR(7) NOT NULL,
    layer_name NVARCHAR(30) NOT NULL,
    object_name NVARCHAR(150) NOT NULL,
    source_row_count INT NULL,
    target_row_count INT NULL,
    difference_count INT NULL,
    reconciliation_status NVARCHAR(30) NOT NULL,
    checked_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO



IF OBJECT_ID('quality.validation_result', 'U') IS NULL
CREATE TABLE quality.validation_result (
    validation_result_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    pipeline_run_id BIGINT NULL,
    source_batch_id NVARCHAR(50) NOT NULL,
    reporting_month CHAR(7) NOT NULL,
    source_table_name NVARCHAR(150) NOT NULL,
    rule_code NVARCHAR(100) NOT NULL,
    rule_description NVARCHAR(500) NOT NULL,
    severity NVARCHAR(20) NOT NULL,
    result_status NVARCHAR(20) NOT NULL,
    failed_record_count INT NOT NULL DEFAULT 0,
    checked_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO


IF OBJECT_ID('quality.rejected_record', 'U') IS NULL
CREATE TABLE quality.rejected_record (
    rejected_record_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    pipeline_run_id BIGINT NULL,
    source_batch_id NVARCHAR(50) NOT NULL,
    reporting_month CHAR(7) NOT NULL,
    source_table_name NVARCHAR(150) NOT NULL,
    source_file_name NVARCHAR(260) NULL,
    raw_row_number INT NULL,
    business_key NVARCHAR(150) NULL,
    rule_code NVARCHAR(100) NOT NULL,
    rejection_reason NVARCHAR(1000) NOT NULL,
    raw_record_json NVARCHAR(MAX) NULL,
    rejected_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('quality.reporting_caveat', 'U') IS NULL
CREATE TABLE quality.reporting_caveat (
    reporting_caveat_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    source_batch_id NVARCHAR(50) NOT NULL,
    reporting_month CHAR(7) NOT NULL,
    caveat_code NVARCHAR(100) NOT NULL,
    caveat_title NVARCHAR(200) NOT NULL,
    caveat_description NVARCHAR(1000) NOT NULL,
    severity NVARCHAR(20) NOT NULL,
    affected_area NVARCHAR(100) NOT NULL,
    recommended_action NVARCHAR(1000) NULL,
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('quality.reporting_readiness', 'U') IS NULL
CREATE TABLE quality.reporting_readiness (
    reporting_readiness_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    source_batch_id NVARCHAR(50) NOT NULL,
    reporting_month CHAR(7) NOT NULL,
    readiness_status NVARCHAR(30) NOT NULL,
    blocker_count INT NOT NULL DEFAULT 0,
    warning_count INT NOT NULL DEFAULT 0,
    rejected_record_count INT NOT NULL DEFAULT 0,
    readiness_summary NVARCHAR(1000) NULL,
    checked_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

SELECT
    s.name AS schema_name,
    t.name AS table_name
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name IN ('audit', 'quality')
ORDER BY s.name, t.name;


