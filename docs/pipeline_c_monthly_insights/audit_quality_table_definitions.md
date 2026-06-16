# Audit And Quality Table Definitions

This document defines the purpose and key fields for the `audit` and `quality` schemas in Pipeline C.

Pipeline C uses these schemas to make monthly processing explainable: what ran, which files loaded, whether row counts reconciled, which validation rules failed, which records were excluded, and what caveats should be shown to reporting users.

## Severity Levels

| Severity | Meaning | Reporting impact |
|---|---|---|
| `INFO` | Informational note or expected business event. | Report can proceed without caveat. |
| `WARNING` | Issue should be visible to users, but does not prevent reporting. | Report can proceed with caveat. |
| `ERROR` | Invalid records should be rejected or corrected. | Report can usually proceed if the issue is small and controlled. |
| `BLOCKER` | Issue is serious enough that the reporting output should not be trusted. | Month should be marked `NOT_READY` until fixed. |

## Audit Schema

The `audit` schema records operational evidence for pipeline execution, file loading, and reconciliation.

### `audit.pipeline_run`

Purpose: records one ADF pipeline execution.

Expected grain: one row per pipeline run.

| Field | Meaning |
|---|---|
| `pipeline_run_id` | Internal SQL identity key for the run record. |
| `pipeline_name` | Name of the ADF pipeline, such as `pl_pipeline_c_monthly_insights`. |
| `adf_run_id` | ADF run identifier, when available from orchestration. |
| `source_batch_id` | Batch identifier, such as `2024_01`. |
| `reporting_month` | Reporting period processed by the run, such as `2024-01`. |
| `load_mode` | Processing mode, usually `INITIAL_SNAPSHOT` or `MONTHLY_CHANGE`. |
| `trigger_file` | Trigger file that started the run, usually `_READY.json`. |
| `run_status` | Run status, such as `STARTED`, `SUCCEEDED`, or `FAILED`. |
| `started_at` | UTC timestamp when the run started. |
| `ended_at` | UTC timestamp when the run ended. |
| `error_message` | Error details when the run fails. |

### `audit.batch_load`

Purpose: records the source batch folder being processed.

Expected grain: one row per source batch. In Pipeline C, one pipeline run normally processes one batch, so this table overlaps with `audit.pipeline_run`.

| Field | Meaning |
|---|---|
| `batch_load_id` | Internal SQL identity key for the batch record. |
| `pipeline_run_id` | Optional link to the associated pipeline run. |
| `source_batch_id` | Batch identifier, such as `2024_02`. |
| `reporting_month` | Reporting period represented by the batch. |
| `load_mode` | Processing mode, usually `INITIAL_SNAPSHOT` or `MONTHLY_CHANGE`. |
| `source_folder` | ADLS source folder, such as `raw/month=2024-02`. |
| `batch_status` | Batch status, such as `RECEIVED`, `LOADED`, or `FAILED`. |
| `created_at` | UTC timestamp when the batch record was created. |

Design note: because Pipeline C uses one `_READY.json` trigger per month, `audit.batch_load` may be simplified later by storing batch fields directly in `audit.pipeline_run`.

### `audit.file_load`

Purpose: records each source file loaded into a Bronze table.

Expected grain: one row per source file loaded per batch.

| Field | Meaning |
|---|---|
| `file_load_id` | Internal SQL identity key for the file-load record. |
| `pipeline_run_id` | Optional link to the associated pipeline run. |
| `source_batch_id` | Batch identifier for the monthly folder. |
| `reporting_month` | Reporting period represented by the file. |
| `source_file_name` | File loaded, such as `students.csv` or `attendance.csv`. |
| `target_table_name` | Bronze target table, such as `bronze.students`. |
| `source_row_count` | Number of rows expected from the source file. |
| `loaded_row_count` | Number of rows loaded into the target table. |
| `rejected_row_count` | Number of rows rejected during load, if any. |
| `load_status` | File load status, such as `LOADED`, `PARTIAL`, or `FAILED`. |
| `loaded_at` | UTC timestamp when the file load was recorded. |

### `audit.row_count_reconciliation`

Purpose: records row-count checks between layers.

Expected grain: one row per reconciliation check per object per batch.

| Field | Meaning |
|---|---|
| `reconciliation_id` | Internal SQL identity key for the reconciliation record. |
| `pipeline_run_id` | Optional link to the associated pipeline run. |
| `source_batch_id` | Batch identifier for the monthly folder. |
| `reporting_month` | Reporting period being checked. |
| `layer_name` | Layer being reconciled, such as `bronze`, `silver`, `gold`, or `reporting`. |
| `object_name` | Table or view being checked. |
| `source_row_count` | Row count from the upstream source or layer. |
| `target_row_count` | Row count from the target object. |
| `difference_count` | Difference between source and target counts. |
| `reconciliation_status` | Check outcome, such as `PASS`, `WARNING`, or `FAIL`. |
| `checked_at` | UTC timestamp when the check was run. |

## Quality Schema

The `quality` schema records validation results, rejected rows, stakeholder caveats, and reporting readiness.

### `quality.validation_result`

Purpose: records rule-level validation outcomes.

Expected grain: one row per validation rule per source table per batch.

| Field | Meaning |
|---|---|
| `validation_result_id` | Internal SQL identity key for the validation result. |
| `pipeline_run_id` | Optional link to the associated pipeline run. |
| `source_batch_id` | Batch identifier for the monthly folder. |
| `reporting_month` | Reporting period being validated. |
| `source_table_name` | Table checked, such as `bronze.attendance`. |
| `rule_code` | Stable rule identifier, such as `ATT_INVALID_DAYS`. |
| `rule_description` | Plain-English description of the rule. |
| `severity` | Rule severity: `INFO`, `WARNING`, `ERROR`, or `BLOCKER`. |
| `result_status` | Result of the rule, usually `PASS` or `FAIL`. |
| `failed_record_count` | Number of records that failed the rule. |
| `checked_at` | UTC timestamp when the rule was checked. |

### `quality.rejected_record`

Purpose: stores records excluded from trusted Silver or Gold processing.

Expected grain: one row per rejected source record per failed rule.

| Field | Meaning |
|---|---|
| `rejected_record_id` | Internal SQL identity key for the rejected record. |
| `pipeline_run_id` | Optional link to the associated pipeline run. |
| `source_batch_id` | Batch identifier for the monthly folder. |
| `reporting_month` | Reporting period of the rejected record. |
| `source_table_name` | Source table where the record was found. |
| `source_file_name` | Source file where the record came from. |
| `raw_row_number` | Row number in the loaded file, if captured. |
| `business_key` | Natural key for the rejected record, such as `attendance_id` or `student_id`. |
| `rule_code` | Validation rule that caused rejection. |
| `rejection_reason` | Plain-English reason the row was rejected. |
| `raw_record_json` | JSON representation of the rejected source row. |
| `rejected_at` | UTC timestamp when the row was rejected. |

### `quality.reporting_caveat`

Purpose: stores stakeholder-facing caveats for dashboards and monthly insight briefs.

Expected grain: one row per caveat per reporting month.

| Field | Meaning |
|---|---|
| `reporting_caveat_id` | Internal SQL identity key for the caveat. |
| `source_batch_id` | Batch identifier for the monthly folder. |
| `reporting_month` | Reporting period affected by the caveat. |
| `caveat_code` | Stable caveat identifier. |
| `caveat_title` | Short dashboard-friendly caveat title. |
| `caveat_description` | Plain-English caveat explanation. |
| `severity` | Caveat severity: `INFO`, `WARNING`, `ERROR`, or `BLOCKER`. |
| `affected_area` | Business area affected, such as `Attendance`, `Assessment`, or `Student reference`. |
| `recommended_action` | Suggested action for stakeholders or data owners. |
| `created_at` | UTC timestamp when the caveat was created. |

### `quality.reporting_readiness`

Purpose: records whether a reporting month is ready for dashboard and stakeholder review.

Expected grain: one row per reporting month per readiness assessment.

| Field | Meaning |
|---|---|
| `reporting_readiness_id` | Internal SQL identity key for the readiness record. |
| `source_batch_id` | Batch identifier for the monthly folder. |
| `reporting_month` | Reporting period being assessed. |
| `readiness_status` | Readiness outcome, such as `READY`, `READY_WITH_CAVEATS`, or `NOT_READY`. |
| `blocker_count` | Number of blocker issues found. |
| `warning_count` | Number of warning-level caveats found. |
| `rejected_record_count` | Number of records rejected for the period. |
| `readiness_summary` | Plain-English summary of reporting confidence. |
| `checked_at` | UTC timestamp when readiness was assessed. |

