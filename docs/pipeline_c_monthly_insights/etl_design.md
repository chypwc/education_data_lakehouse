# Pipeline C ETL Design

## Purpose

This document defines how Pipeline C moves one monthly raw data batch through orchestration, Azure SQL processing, validation, reporting views, and Power BI readiness.

It complements [SQL layer design](sql_layer_design.md):

- `sql_layer_design.md` defines schemas, tables, keys, grains, and reporting views.
- `etl_design.md` defines orchestration, load modes, stored procedure order, validation gates, rerun behaviour, and evidence to capture.

## ETL Scope

Pipeline C uses a production-style monthly process:

```text
ADLS raw month folder
-> _READY.json marker file
-> ADF or Fabric Data Factory event trigger
-> Azure SQL bronze load
-> Azure SQL quality checks
-> Azure SQL silver merge/upsert
-> Azure SQL gold refresh
-> Azure SQL reporting validation
-> Power BI semantic model refresh
```

The ETL design covers 24 runs:

| Run group | Reporting months | Load mode | Purpose |
|---|---|---|---|
| Initial snapshot | `2024-01` | `INITIAL_SNAPSHOT` | Establish starting schools, students, attendance, events, quality, gold, and reporting baseline |
| Monthly changes | `2024-02` to `2025-12` | `MONTHLY_CHANGE` | Process monthly deltas/facts, merge changes, append valid facts, refresh reporting outputs |

## Orchestration Tool

Use Azure Data Factory or Fabric Data Factory as the orchestrator.

Azure SQL Database should run the transformation logic through stored procedures, but Azure SQL Database should not be treated as the end-to-end orchestrator.

ADF/Fabric is responsible for:

- detecting the monthly ready marker;
- deriving the reporting month and source folder;
- passing parameters into SQL procedures;
- sequencing SQL activities;
- recording success/failure evidence;
- optionally triggering Power BI refresh after SQL validation passes.

## Raw Folder Contract

Raw files are uploaded month by month.

Folder pattern:

```text
raw/pipeline_c_monthly_insights/month=YYYY-MM/
```

The pipeline should not trigger on every source file. It should trigger only when the final marker file is uploaded:

```text
raw/pipeline_c_monthly_insights/month=YYYY-MM/_READY.json
```

The marker file means:

- all required source files for the reporting month are present;
- the reporting month is ready for one pipeline run;
- the pipeline can safely validate file presence and begin loading.

## Ready Marker Contract

Example for the initial snapshot:

```json
{
  "pipeline": "pipeline_c_monthly_insights",
  "reporting_month": "2024-01",
  "load_mode": "INITIAL_SNAPSHOT",
  "expected_files": [
    "schools.csv",
    "students.csv",
    "attendance.csv",
    "assessment_results.csv",
    "school_events.json"
  ]
}
```

Example for a monthly change batch:

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

The marker file should be retained as audit evidence.

## Pipeline Parameters

The ADF/Fabric pipeline should be parameterised.

| Parameter | Example | Purpose |
|---|---|---|
| `reporting_month` | `2024-02` | Month being processed |
| `source_folder` | `raw/pipeline_c_monthly_insights/month=2024-02/` | Raw folder path |
| `load_mode` | `MONTHLY_CHANGE` | Chooses initial snapshot or monthly change procedure path |
| `source_batch_id` | `PIPELINE_C_2024_02` | Batch lineage key used in bronze, audit, and quality |

`source_batch_id` can be derived from `pipeline + reporting_month`.

## Required Files

Initial snapshot required files:

| File | Required | Notes |
|---|---|---|
| `schools.csv` | Yes | Full school snapshot |
| `students.csv` | Yes | Full student snapshot |
| `attendance.csv` | Yes | January attendance records |
| `assessment_results.csv` | Yes | Expected to be empty or header-only for January |
| `school_events.json` | Yes | January event context |

Monthly change required files:

| File | Required | Notes |
|---|---|---|
| `schools_delta.csv` | Yes | Can be header-only if no school changes |
| `students_delta.csv` | Yes | Monthly changed students |
| `attendance.csv` | Yes | Monthly attendance records |
| `assessment_results_delta.csv` | Yes | Can be header-only outside assessment months |
| `school_events.json` | Yes | Monthly event context |

## ADF/Fabric Pipeline Sequence

Recommended pipeline name:

```text
pl_pipeline_c_monthly_insights
```

Recommended sequence:

1. Trigger on `_READY.json`.
2. Read marker file.
3. Validate marker fields.
4. Validate expected files exist.
5. Start audit run.
6. Execute bronze load procedure.
7. Execute quality checks.
8. If blocker rules fail, stop before silver/gold and mark run failed or blocked.
9. Execute silver merge/upsert procedure.
10. Execute gold refresh procedure.
11. Execute reporting validation procedure.
12. Mark audit run succeeded or failed.
13. Optionally trigger Power BI refresh after reporting validation passes.

## Azure SQL Procedure Sequence

Pipeline C SQL implementation should be organised into three stages:

```text
1. Setup SQL objects
2. Run initial snapshot
3. Run monthly changes
```

Setup should be manual or controlled. It creates schemas, tables, stored procedures, and reporting views.

The data-processing pipeline should be event-driven and parameterised. It should use `load_mode` to choose between:

- `INITIAL_SNAPSHOT`
- `MONTHLY_CHANGE`

## SQL Script Inventory

Recommended SQL folder structure:

```text
sql/pipeline_c_monthly_insights/
  00_create_schemas.sql
  01_create_bronze_tables.sql
  02_create_silver_tables.sql
  03_create_quality_audit_tables.sql
  04_create_gold_tables.sql
  05_create_reporting_views.sql
  procedures/
    bronze.usp_load_initial_snapshot.sql
    bronze.usp_load_monthly_change_batch.sql
    quality.usp_apply_quality_checks.sql
    silver.usp_merge_pipeline_c_tables.sql
    gold.usp_refresh_pipeline_c_outputs.sql
    reporting.usp_validate_pipeline_c_views.sql
```

Setup scripts should be safe to review and rerun where practical. Destructive reset logic should be explicit and separated from normal monthly processing.

## Stored Procedure Sequence

Recommended stored procedures:

| Step | Procedure | Purpose |
|---|---|---|
| 1 | `audit.usp_start_pipeline_c_batch` | Create run and batch audit rows |
| 2 | `bronze.usp_load_initial_snapshot` | Load January snapshot files into bronze |
| 2 | `bronze.usp_load_monthly_change_batch` | Load monthly change files into bronze |
| 3 | `quality.usp_apply_quality_checks` | Write validation, rejected-record, caveat, and readiness outputs |
| 4 | `silver.usp_merge_pipeline_c_tables` | Merge trusted schools/students and insert valid facts |
| 5 | `gold.usp_refresh_pipeline_c_outputs` | Refresh dimensions, facts, and summaries |
| 7 | `reporting.usp_validate_pipeline_c_views` | Reconcile reporting views against gold outputs |
| 8 | `audit.usp_finish_pipeline_c_batch` | Mark batch status and final row counts |

The implementation can split these procedures further if needed, but the orchestration should keep the logical sequence clear.

## Initial Snapshot Logic

`INITIAL_SNAPSHOT` applies only to:

```text
month=2024-01
```

Expected behaviour:

1. Confirm target bronze/silver/quality/gold/reporting/audit objects exist.
2. Load snapshot files into bronze snapshot tables.
3. Apply quality checks.
4. Assign `school_key` and `student_key` in silver.
5. Build initial `silver.school`, `silver.student`, `silver.student_monthly_status`, `silver.attendance_monthly`, and `silver.school_event`.
6. Build initial gold dimensions, facts, and summaries.
7. Validate reporting views.
8. Record row-count reconciliation.

If re-run behaviour is needed, the safest portfolio approach is to make the initial snapshot rerun controlled and explicit:

- either truncate Pipeline C SQL objects and reload from January;
- or reject a second successful `INITIAL_SNAPSHOT` run unless a reset flag is provided.

## Monthly Change Logic

`MONTHLY_CHANGE` applies to:

```text
month=2024-02
...
month=2025-12
```

Expected behaviour:

1. Load monthly source files into bronze.
2. Validate required files and row counts.
3. Run quality checks against the monthly bronze batch.
4. Merge school deltas into `silver.school`.
5. Merge student deltas into `silver.student`.
6. Create or refresh `silver.student_monthly_status` for the reporting month.
7. Insert valid monthly attendance records into `silver.attendance_monthly`.
8. Insert valid assessment records into `silver.assessment_result`.
9. Insert valid event records into `silver.school_event`.
10. Write rejected records and caveats to quality tables.
11. Refresh affected gold dimensions, facts, and summaries.
12. Validate reporting views and monthly readiness.
13. Record audit and reconciliation outputs.

## Upsert And Append Rules

| Source data | Silver behaviour |
|---|---|
| `schools.csv` | Initial load into `silver.school` |
| `schools_delta.csv` | Merge/upsert by `school_id`, maintaining `school_key` |
| `students.csv` | Initial load into `silver.student` |
| `students_delta.csv` | Merge/upsert by `student_id`, maintaining `student_key` |
| `attendance.csv` | Append valid monthly records after deduplication and validation |
| `assessment_results.csv` | Initial assessment load, expected empty/header-only for January |
| `assessment_results_delta.csv` | Append valid assessment records for assessment months |
| `school_events.json` | Append valid events linked to `school_key` where possible |

Surrogate keys are assigned in silver:

- `school_key` maps to `school_id`;
- `student_key` maps to `student_id`.

Gold facts should use surrogate keys. Reporting views should aggregate and avoid exposing student identifiers.

## Quality Gates

Quality checks run before trusted silver/gold outputs are refreshed.

Known synthetic quality issues are documented in [synthetic quality issue register](synthetic_quality_issue_register.md).

Minimum rules:

| Rule | Expected action |
|---|---|
| Missing required key | Reject or caveat |
| Missing school reference | Reject from trusted student/school counts |
| Unknown student in attendance | Reject from trusted attendance metrics |
| Duplicate attendance business key | Deduplicate and caveat |
| `attended_days > possible_days` | Reject from attendance metrics |
| Assessment score outside valid range | Reject from assessment metrics |
| Unexpected row-count movement | Warning or blocker depending on severity |

Pipeline behaviour:

- blocker failures stop silver/gold refresh for the affected batch;
- warning failures allow processing but must appear in reporting caveats;
- rejected records must reconcile to quality outputs.

## Rerun And Idempotency

The pipeline should be safe to rerun for the same month.

Recommended approach:

- use `source_batch_id` and `reporting_month` in bronze;
- prevent duplicate successful batch loads unless a rerun flag is set;
- delete or supersede prior bronze rows for the same `source_batch_id` before reloading;
- make silver merge/upsert logic deterministic;
- refresh gold outputs for the affected month from silver rather than appending duplicate gold rows;
- record every run attempt in `audit.pipeline_run`.

For portfolio scope, the minimum acceptable pattern is:

- one successful run per reporting month;
- audit evidence showing 24 successful monthly runs;
- documented rerun behaviour.

## Reconciliation

Each run should produce reconciliation evidence.

Minimum checks:

| Check | Purpose |
|---|---|
| Raw expected file count equals actual file count | Confirms folder completeness |
| Raw row count equals bronze loaded row count | Confirms load completeness |
| Bronze rejects equal quality rejected records | Confirms validation accounting |
| Silver valid rows equal bronze rows minus rejected rows | Confirms trusted data accounting |
| Gold facts reconcile to silver valid records | Confirms reporting model completeness |
| Reporting views reconcile to gold summaries | Confirms Power BI contract |

## Reporting Outputs

The ETL process should refresh these reporting outputs:

| View | Stakeholder question |
|---|---|
| `reporting.vw_pipeline_c_monthly_attendance_summary` | What changed this month? |
| `reporting.vw_pipeline_c_year_level_attendance_patterns` | Which cohorts need attention? |
| `reporting.vw_pipeline_c_attendance_assessment_relationship` | What learning outcome signal is associated with attendance? |
| `reporting.vw_pipeline_c_monthly_reporting_readiness` | Is this data ready for review? |
| `reporting.vw_pipeline_c_data_quality_caveats` | What should users be careful about? |

## Evidence To Capture

For portfolio evidence, capture:

- ADLS month folder with `_READY.json`;
- ADF/Fabric pipeline screenshot;
- ADF/Fabric event trigger screenshot;
- initial snapshot run screenshot;
- sample monthly change run screenshot;
- audit table query showing 24 runs;
- row-count reconciliation query;
- quality caveat query;
- gold/reporting output validation query;
- Power BI refresh or connection evidence.

## Open Implementation Decisions

Decide during SQL/ADF implementation:

- whether `_READY.json` is read by ADF/Fabric directly or parsed through a small helper step;
- whether blocker quality failures stop the whole batch or only exclude affected records;
- whether Power BI refresh is triggered automatically after SQL validation or refreshed manually for portfolio evidence;
- whether monthly reruns require a `force_rerun` parameter.
