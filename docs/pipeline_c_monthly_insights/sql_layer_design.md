# Pipeline C SQL Layer Design

## Purpose

Pipeline C turns the synthetic monthly education files into stakeholder-ready reporting outputs.

The SQL layer should show production-style analytics capability without becoming a large platform build. It should make the monthly load pattern, data quality caveats, reporting model, and Power BI contract clear enough to implement in small steps.

## Scope

Pipeline C uses:

- Azure Data Lake Storage or local files as the raw source evidence.
- Azure SQL Database serverless as the SQL processing and reporting layer.
- Power BI as the semantic model and dashboard layer.

Pipeline C does not replace Pipelines A or B. Pipelines A and B remain engineering and QA evidence. Pipeline C adds the analytics reporting story.

## Layer Convention

Pipeline C uses modern medallion naming for consistency with the existing project.

| Layer | Location | Purpose |
|---|---|---|
| Raw | ADLS or local files | Source CSV/JSON files, unchanged |
| Bronze | Azure SQL schema | Source-shaped loaded tables with ingestion metadata |
| Silver | Azure SQL schema | Cleaned, typed, deduplicated, validated, upserted business tables |
| Quality | Azure SQL schema | Validation results, caveats, rejected rows, reporting readiness |
| Gold | Azure SQL schema | Analytics-ready dimensions, facts, and summary tables |
| Reporting | Azure SQL schema | Stable Power BI-facing views |
| Audit | Azure SQL schema | Pipeline run, file-load, batch, and row-count evidence |

Flow:

```text
raw files
-> bronze
-> silver
-> quality
-> gold
-> reporting
-> Power BI semantic model
```

## Raw Files

Raw files stay close to what a source system would provide. They should not include pipeline metadata such as `source_batch_id`, `loaded_at`, `effective_from`, `effective_to`, `is_current`, or `record_hash`.

Pipeline C raw folders use production-like monthly partitions:

```text
data/pipeline_c_monthly_insights/month=2024-01/
data/pipeline_c_monthly_insights/month=2024-02/
...
data/pipeline_c_monthly_insights/month=2025-12/
```

January 2024 is the initial snapshot. February 2024 to December 2025 are monthly change batches.

## Bronze Layer

Bronze tables load the raw files with minimal transformation. The table shape should remain close to the source file shape, with ingestion metadata added by the SQL load process.

Common bronze metadata columns:

| Column | Purpose |
|---|---|
| `source_batch_id` | Identifies the monthly load batch |
| `reporting_month` | Month represented by the source folder |
| `source_file_name` | Source file loaded |
| `source_folder` | Raw folder path, such as `month=2024-02` |
| `loaded_at` | Load timestamp |
| `raw_row_number` | Optional row number within source file |

Initial bronze tables:

| Table | Source file | Grain |
|---|---|---|
| `bronze.pipeline_c_schools_snapshot` | `schools.csv` in `month=2024-01` | One row per school in the initial snapshot |
| `bronze.pipeline_c_students_snapshot` | `students.csv` in `month=2024-01` | One row per student in the initial snapshot |
| `bronze.pipeline_c_schools_delta` | `schools_delta.csv` | One changed school record per monthly batch |
| `bronze.pipeline_c_students_delta` | `students_delta.csv` | One changed student record per monthly batch |
| `bronze.pipeline_c_attendance_monthly` | `attendance.csv` | One student attendance record per month |
| `bronze.pipeline_c_assessment_results_delta` | `assessment_results_delta.csv` | One assessment result per student, year, and domain |
| `bronze.pipeline_c_school_events` | `school_events.json` | One school event |

Bronze should not decide whether a record is trusted. It only loads, tags, and preserves the source-shaped data.

## Key Strategy

Raw and bronze keep source identifiers exactly as received:

- `school_id`
- `student_id`

Silver and gold introduce warehouse surrogate keys:

- `school_key`
- `student_key`

The source IDs remain available as attributes for lineage and validation, but joins in silver, gold, and reporting should use surrogate keys where practical.

Recommended key pattern:

| Layer | Key approach |
|---|---|
| Raw | Source IDs only |
| Bronze | Source IDs plus load metadata |
| Silver | Surrogate keys plus source IDs for lineage |
| Gold | Surrogate keys for joins, source IDs hidden or excluded from reporting |
| Reporting | Aggregate views; no student-level identifiers exposed |

Initial key maps can be implemented as part of the silver entity tables:

| Table | Purpose |
|---|---|
| `silver.school` | Assigns and stores `school_key` for each `school_id` |
| `silver.student` | Assigns and stores `student_key` for each `student_id` |

Separate key map tables are optional. For this portfolio project, keeping `school_key` in `silver.school` and `student_key` in `silver.student` is enough unless implementation becomes more complex.

## Silver Layer

Silver tables are the cleaned and conformed business tables. This is where type conversion, key validation, duplicate handling, merge/upsert logic, effective dating, and current-state interpretation happen.

Initial silver tables:

| Table | Grain | Notes |
|---|---|---|
| `silver.school` | One current school record per `school_key` | Stores `school_id` as the source key and is upserted from snapshot and school deltas |
| `silver.student` | One current student record per `student_key` | Stores `student_id` as the source key and is upserted from snapshot and student deltas |
| `silver.student_monthly_status` | One `student_key` per reporting month | Captures monthly `school_key`, year level, and active/left status for analysis |
| `silver.attendance_monthly` | One valid `student_key` attendance record per reporting month | Uses `student_key` and `school_key`; excludes or flags invalid attendance rows |
| `silver.assessment_result` | One valid assessment result per `student_key`, year, and domain | Uses `student_key` and `school_key`; excludes or flags invalid score rows |
| `silver.school_event` | One valid school event | Uses `school_key` where the source school is valid |

Recommended silver metadata columns:

| Column | Purpose |
|---|---|
| `source_batch_id` | Batch lineage |
| `effective_from_month` | First reporting month where the current value applies |
| `effective_to_month` | Last reporting month where the value applies, if history is retained |
| `is_current` | Current active version flag, if history is retained |
| `record_hash` | Change detection for upserts |
| `validation_status` | `Valid`, `Warning`, or `Rejected` |

For this portfolio project, full type-2 history is optional. The minimum production-like approach is:

- maintain current `silver.school` and `silver.student` tables with surrogate keys;
- build `silver.student_monthly_status` so historical monthly reporting is still possible;
- record row-level caveats in `quality` tables.

## Quality Layer

The quality layer makes caveats visible instead of hiding defects inside the ETL.

Initial quality tables:

| Table | Grain | Purpose |
|---|---|---|
| `quality.validation_result` | One validation outcome per rule, batch, and table | Stores pass/fail/warning outcomes |
| `quality.rejected_record` | One rejected source record | Stores records excluded from silver/gold reporting |
| `quality.reporting_caveat` | One caveat per month, rule, or reporting area | Feeds dashboard caveat pages and monthly brief |
| `quality.reporting_readiness` | One readiness status per reporting month | Indicates whether the month is ready for stakeholder review |

Initial quality checks:

| Rule | Layer | Expected handling |
|---|---|---|
| Required key missing | Bronze to Silver | Reject or caveat |
| Unknown school reference | Bronze to Silver | Reject or caveat |
| Duplicate attendance record | Bronze to Silver | Deduplicate and caveat |
| `attended_days > possible_days` | Bronze to Silver | Reject from valid attendance metrics |
| Assessment score outside valid range | Bronze to Silver | Reject from valid assessment metrics |
| Monthly row counts outside expected range | Bronze/Silver/Gold | Warning or blocker depending on severity |

## Audit Layer

Audit tables support reruns, reconciliation, and portfolio evidence.

Initial audit tables:

| Table | Grain | Purpose |
|---|---|---|
| `audit.pipeline_run` | One row per pipeline run | Start/end time, status, trigger, notes |
| `audit.batch_load` | One row per reporting month loaded | Batch status and reporting month |
| `audit.file_load` | One row per source file loaded | File name, folder, row count, loaded timestamp |
| `audit.row_count_reconciliation` | One row per check | Raw, bronze, silver, gold, and reporting count checks |

Audit tables are operational evidence. They are not part of the Power BI business model unless a technical evidence page is needed.

## Gold Layer

Gold tables are analytics-ready. They should be stable, business-readable, and easy to connect to Power BI.

Initial gold dimensions:

| Table | Grain | Purpose |
|---|---|---|
| `gold.dim_month` | One row per reporting month | Month, year, term/season, prior month |
| `gold.dim_school` | One row per `school_key` | School source ID, school name, region, school type, status |
| `gold.dim_year_level` | One row per year level | Year level label and cohort group |
| `gold.dim_assessment_domain` | One row per assessment domain | Reading, Numeracy, Writing |
| `gold.dim_attendance_band` | One row per attendance band | Low, Medium, High with sort order |

Initial gold facts:

| Table | Grain | Purpose |
|---|---|---|
| `gold.fact_student_snapshot` | One `student_key` per reporting month | Cohort size, active status, school, year level |
| `gold.fact_attendance_monthly` | One `student_key` per reporting month | Attendance rate and attendance band |
| `gold.fact_assessment_result` | One `student_key` per assessment year and domain | Score and proficiency band |
| `gold.fact_data_quality_caveat` | One caveat per month/rule/table | Reporting caveats and excluded records |

Initial gold summary tables are optional but useful for performance and clarity:

| Table | Grain | Purpose |
|---|---|---|
| `gold.summary_monthly_attendance` | Month, school, year level | Monthly attendance KPIs |
| `gold.summary_year_level_pattern` | Month, year level | Year-level attendance pattern outputs |
| `gold.summary_attendance_assessment` | Attendance band, year level, domain | Attendance-to-assessment relationship |
| `gold.summary_reporting_readiness` | Month | Readiness status and caveat counts |

## Reporting Views

Reporting views are the stable contract for Power BI. They should use plain-English column names where practical and hide technical implementation detail.

Initial reporting views:

| View | Purpose |
|---|---|
| `reporting.vw_pipeline_c_monthly_attendance_summary` | Monthly attendance KPIs and movement |
| `reporting.vw_pipeline_c_year_level_attendance_patterns` | Year 7 and senior secondary pattern analysis |
| `reporting.vw_pipeline_c_attendance_assessment_relationship` | Attendance band versus assessment outcomes |
| `reporting.vw_pipeline_c_monthly_reporting_readiness` | Monthly readiness status and caveat counts |
| `reporting.vw_pipeline_c_data_quality_caveats` | Caveat detail for dashboard and brief |

Reporting views should not expose `student_id` or `student_key` to stakeholder dashboard pages. Student-level keys can remain available in silver/gold for validation if needed, but the Power BI-facing views should be aggregate by default.

## Event-Driven Orchestration

Pipeline C should be orchestrated by Azure Data Factory or Fabric Data Factory, not by Azure SQL Database alone.

The intended production-like pattern is:

1. Upload one reporting month of raw files into ADLS.
2. Upload a final ready/manifest file for that month.
3. A storage event trigger starts the pipeline once for that reporting month.
4. The pipeline passes `reporting_month`, `source_folder`, and `load_mode` parameters to the SQL load procedures.
5. Azure SQL executes the bronze, silver, quality, gold, audit, and reporting steps.

This design produces 24 pipeline runs:

| Run | Reporting month | Load mode | Purpose |
|---|---|---|---|
| 1 | `2024-01` | `INITIAL_SNAPSHOT` | Create/load initial school, student, attendance, and event baseline |
| 2-24 | `2024-02` to `2025-12` | `MONTHLY_CHANGE` | Merge/upsert changed school and student records, append monthly facts, refresh reporting |

The trigger should not fire on every CSV or JSON source file. Each month contains multiple source files, so triggering on every file could start the same month several times before all files have arrived.

Use a final marker file such as:

```text
raw/pipeline_c_monthly_insights/month=2024-01/_READY.json
raw/pipeline_c_monthly_insights/month=2024-02/_READY.json
...
raw/pipeline_c_monthly_insights/month=2025-12/_READY.json
```

The marker file should be uploaded only after all required source files for that month are present.

Example marker file content:

```json
{
  "pipeline": "pipeline_c_monthly_insights",
  "reporting_month": "2024-02",
  "load_mode": "MONTHLY_CHANGE",
  "expected_files": [
    "schools_delta.csv",
    "students_delta.csv",
    "attendance.csv",
    "assessment_results_delta.csv",
    "school_events.json"
  ]
}
```

The ADF/Fabric pipeline should use the trigger metadata to derive the folder path and read the marker file to determine `reporting_month` and `load_mode`.

## Monthly Processing Sequence

Initial snapshot:

1. Create `audit.pipeline_run` and `audit.batch_load` rows for `2024-01`.
2. Load January 2024 raw files into bronze snapshot tables.
3. Run quality checks against bronze snapshot tables.
4. Merge trusted school and student records into silver.
5. Load valid attendance and event records into silver.
6. Build gold dimensions, facts, and summaries.
7. Refresh reporting views.
8. Record reconciliation results.

Monthly change batch:

1. Create `audit.pipeline_run` and `audit.batch_load` rows for the reporting month.
2. Load monthly raw files into bronze delta/fact tables.
3. Run quality checks against bronze monthly files.
4. Merge school and student deltas into silver.
5. Insert valid monthly attendance, assessment, and event records into silver.
6. Refresh gold dimensions, facts, and summaries for the affected reporting month.
7. Refresh reporting views.
8. Record reconciliation results and reporting readiness.

## Reconciliation Checks

Minimum checks before Power BI refresh:

- Raw file count matches bronze load count for each file.
- Bronze rejected rows match `quality.rejected_record`.
- Silver row counts are explainable after rejected records and deduplication.
- Gold monthly attendance totals reconcile to valid silver attendance rows.
- Gold assessment totals reconcile to valid silver assessment rows.
- Reporting views reconcile to gold summaries.
- Every reporting month has a readiness status.

## Power BI Contract

Power BI should connect to `reporting` views, not directly to bronze or silver tables.

The semantic model should define:

- relationships between reporting outputs and shared dimensions;
- DAX measures for attendance rate, prior month movement, assessment score, caveat count, and reporting readiness;
- hidden technical fields;
- business-friendly names and descriptions.

## Open Implementation Decisions

These can be decided when SQL is implemented:

- Whether silver school and student tables use full type-2 history or current-state plus monthly status snapshots.
- Whether gold summary tables are physically materialised or implemented as reporting views over gold facts.
- Whether JSON school events are loaded through a client script first or parsed inside Azure SQL.
- Whether audit stored procedures live in the same schema as data tables or in a separate control pattern.
