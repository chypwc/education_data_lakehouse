# Databricks QA Layer Design

## Purpose

This document records the design of the Azure Databricks QA layer added on top of the existing education data lakehouse project.

The original project demonstrated an Azure data lake and Synapse serverless SQL pattern:

- ADLS Gen2 for lake storage.
- Azure Data Factory for ingestion.
- Synapse serverless SQL for staging, validation, modelling, and reporting views.
- Power BI for dashboarding.

The Databricks extension keeps the same synthetic education domain, but shifts the quality assurance workflow into a Delta Lake lakehouse pattern:

- Raw batch files in ADLS.
- Bronze Delta tables for auditable ingestion.
- Silver Delta tables for standardised typed data.
- QA Delta tables for rule metadata, validation results, failed records, and defect logs.
- Gold/reporting tables for dashboard-ready outputs.
- Power BI testing against Gold tables or reporting views.

The goal is to show quality assurance across the full data and reporting lifecycle, aligned to the ACT Education Quality Assurance Analyst position.

## Target Orchestration Architecture

The Databricks implementation uses Databricks Jobs as the primary ETL and QA orchestrator:

```text
ADLS raw files
   -> Databricks Job
      -> 01_ingest_raw_to_bronze
      -> 02_transform_bronze_to_silver
      -> 03_run_data_quality_checks
      -> 04_build_gold_reporting_tables
      -> 05_create_reporting_views
   -> Power BI
```

Azure Data Factory is implemented as an enterprise wrapper:

```text
ADLS marker file: raw/_triggers/batch_id=<batch_id>/_READY.json
   -> ADF storage event trigger: trigger_education_qa_databricks_job
      -> ADF pipeline: pl_education_qa_databricks_job
         -> Web activity: act_run_education_qa_databricks_job
            -> Databricks Jobs API run-now
               -> Databricks Job with batch_id/run_mode/environment
```

Databricks Jobs own the core pipeline because the transformations, QA rules, Delta tables, and Gold outputs are Databricks-native. ADF is useful when the organisation needs cross-service orchestration, external triggers, central Azure scheduling, or integration with upstream/downstream systems. In this project, ADF listens for `_READY.json` marker files under `raw/_triggers/` and triggers the Databricks Job; it does not own the transformation logic.

## Current Azure and Databricks Setup

| Item | Value |
|---|---|
| Resource group | `rg-edu-qa-databricks-dev` |
| Storage account | `steduqadblakehouse` |
| ADLS container | `education-data-lake` |
| Databricks workspace | `dbw-edu-qa-dev` |
| Unity Catalog catalog | `dbw_edu_qa_dev` |
| External location | `extloc_education_data_lake` |
| Access connector | `ac-edu-qa-databricks` |
| Data Factory resource | `adf-edu-qa-dev` |
| ADF pipeline | `pl_education_qa_databricks_job` |
| ADF Web activity | `act_run_education_qa_databricks_job` |
| ADF storage event trigger | `trigger_education_qa_databricks_job` |
| ADF marker path pattern | `raw/_triggers/batch_id=<batch_id>/_READY.json` |

Storage access is configured through the Azure Databricks access connector and managed identity, with storage IAM roles assigned to the connector.

## Batch Design

The project uses two synthetic source batches:

| Batch | Batch ID | Data period | Purpose |
|---|---|---|---|
| Batch 1 | `2025-01-15` | 2024 education data | Initial load |
| Batch 2 | `2026-01-15` | 2025 education data | Incremental load |

Raw files are stored in ADLS using date-based batch folders:

```text
raw/<dataset>/batch_id=YYYY-MM-DD/<file>
```

Example:

```text
raw/students/batch_id=2025-01-15/students.csv
raw/students/batch_id=2026-01-15/students.csv
```

The final demo runs Batch 1 end to end first, then Batch 2 as an incremental load:

```text
Batch 1: raw -> bronze -> silver -> QA -> gold -> Power BI
Batch 2: raw -> bronze append -> silver update -> QA -> gold refresh -> Power BI refresh
```

The Databricks Job uses these parameters:

| Parameter | Purpose |
|---|---|
| `environment` | Identifies the deployment environment, currently `dev` |
| `batch_id` | Selects the source batch folder to process |
| `run_mode` | Controls initial versus incremental behaviour |
| `job_run_id` | Captures the Databricks Job run identifier for lineage |

For Databricks Job runs, `job_run_id` is populated from `{{job.run_id}}`. The notebooks use this value to create a consistent `run_id` across Bronze, Silver, QA, Gold, and reporting outputs.

## Layer Responsibilities

| Layer | Responsibility |
|---|---|
| Raw | Immutable source files, partitioned by `batch_id` |
| Bronze | Raw structure preserved with audit metadata |
| Silver | Typed, trimmed, standardised data |
| QA | Rule catalog, validation results, failed records, defects |
| Gold | Dashboard-ready reporting tables |
| Reporting | Business-facing views over Gold outputs |
| Power BI | Visual reporting and dashboard QA evidence |

## Bronze Design

Bronze tables preserve source columns and add audit metadata:

- `source_file_name`
- `load_timestamp`
- `run_id`
- `batch_id`
- `bronze_record_id`

The current Bronze pattern is:

- Batch 1 uses `overwrite` during initial rebuild.
- Batch 2 uses `append` for incremental loading.

Expected Bronze tables:

- `bronze.schools`
- `bronze.students`
- `bronze.attendance`
- `bronze.assessment_results`
- `bronze.school_events`

Validated Bronze row counts:

| Table | Batch 1 | Batch 2 |
|---|---:|---:|
| `bronze.schools` | 50 | 51 |
| `bronze.students` | 10,002 | 10,502 |
| `bronze.attendance` | 120,003 | 96,939 |
| `bronze.assessment_results` | 30,001 | 24,235 |
| `bronze.school_events` | 146 | 135 |

## Silver Design

Silver tables enforce basic data contracts:

- IDs are trimmed and stored as strings.
- Dates are converted to `date`.
- Numeric fields are converted to integer or decimal.
- Category fields are trimmed and standardised.
- Bronze audit fields are preserved.
- `silver_load_timestamp` is added.

Expected Silver tables:

- `silver.schools`
- `silver.students`
- `silver.attendance`
- `silver.assessment_results`
- `silver.school_events`

In the development build, Silver can be overwritten from all available Bronze data for faster iteration. In the production-style demo, Silver supports the Batch 1 first, Batch 2 incremental story.

For production, changing dimension-style entities such as students and schools would normally use merge/upsert logic rather than simple append.

## QA Layer Design

The QA layer contains four core tables:

| Table | Purpose |
|---|---|
| `qa.dq_rule_catalog` | Metadata for data quality rules |
| `qa.dq_validation_results` | Rule execution results by `run_id` and `batch_id` |
| `qa.dq_failed_records` | Failed-record evidence with lineage |
| `qa.defect_log` | Stakeholder-facing defect summary |

The QA layer should support:

- pass/fail/warn status by rule
- severity assignment
- failed-record traceability
- defect triage
- reconciliation evidence
- dashboard-ready quality metrics

## Implemented Data Quality Rules

| Rule ID | Rule | Severity | Batch 1 result | Batch 2 result |
|---|---|---|---:|---:|
| `DQ001` | Missing student ID | High | 1 fail | 0 fail |
| `DQ002` | Missing school ID | High | 1 fail | 1 fail |
| `DQ003` | Invalid attendance days | High | 1 fail | 1 fail |
| `DQ004` | Duplicate attendance business records | Medium | 4 fail | 4 fail |
| `DQ005` | Attendance references missing student | High | 1 fail | 1 fail |
| `DQ006` | Assessment references missing student | High | 0 fail | 0 fail |
| `DQ007` | Invalid assessment score | High | 1 fail | 1 fail |
| `DQ008` | Invalid proficiency band | Medium | 0 fail | 0 fail |
| `DQ009` | Invalid school status | Medium | 0 fail | 0 fail |
| `DQ010` | Future attendance month | Medium | 0 fail | 0 fail |
| `DQ011` | School event linked to inactive or missing school | Low | 5 warn | 0 fail |

The QA run produced 22 failed or warning records across both batches. These records are traceable through `qa.dq_failed_records`, `qa.defect_log`, and `bronze_record_id`.

## Privacy and Key Map Design

The current portfolio data is synthetic, so using `student_id` for failed-record traceability does not expose real personal information.

In production, a source student identifier may be sensitive even if it is not a name. A student ID can often be linked back to an identifiable person inside the organisation. For that reason, raw student identifiers should not be broadly exposed in QA dashboards, Gold reporting tables, or stakeholder evidence.

A production design should introduce a controlled key map early in the lakehouse, preferably during or immediately after Bronze ingestion.

Recommended production pattern:

```text
Raw source student_id
        |
        v
Restricted Bronze/security zone
        |
        +-- student_id: restricted source identifier
        |
        +-- student_key: generated non-sensitive surrogate key
```

Example key map table:

```text
security.student_key_map

student_id
student_key
effective_from
effective_to
is_current
created_timestamp
```

Access to the key map should be restricted. Downstream Silver, QA, Gold, and Power BI outputs should use `student_key` or aggregated metrics instead of raw `student_id`.

Recommended handling by layer:

| Layer | Identifier Handling |
|---|---|
| Raw | Source `student_id` present in restricted storage |
| Bronze | Source `student_id` retained with restricted access; `student_key` generated or joined |
| Silver | Prefer `student_key`; limit raw `student_id` exposure |
| QA failed records | Use `student_key`, `bronze_record_id`, and rule metadata for traceability |
| Gold | Use aggregated data; avoid student-level identifiers |
| Power BI | Show aggregate quality and reporting metrics only |

For this portfolio build, the current synthetic IDs can remain in the working QA tables. The final governance checklist should explicitly state that a production implementation would use a restricted key map and avoid exposing raw student identifiers outside authorised technical controls.

## Gold and Reporting Design

Gold tables provide dashboard-ready aggregates after invalid records are excluded or flagged according to QA rules.

The production-hardened Gold model now includes a formal star-schema layer. The existing aggregate Gold tables remain useful as dashboard-ready marts, but the star-schema layer is the authoritative production-style analytical model for dimensional reporting and Power BI relationships.

Implemented Gold dimensions:

| Dimension | Grain | Key Strategy |
|---|---|---|
| `gold.dim_batch` | One row per source batch | `batch_key = sha2(batch_id)` |
| `gold.dim_date` | One row per reporting calendar date | `date_key = yyyyMMdd` |
| `gold.dim_school` | One school version row per school attribute state | stable `school_key`; SCD row `school_scd_key` |
| `gold.dim_student` | One student snapshot row per batch | stable `student_key`; batch snapshot `student_batch_key` |
| `gold.dim_year_level` | One row per year level | `year_level_key = sha2(year_level)` |
| `gold.dim_assessment_domain` | One row per assessment domain | `domain_key = sha2(domain)` |
| `gold.dim_proficiency_band` | One row per proficiency band | `proficiency_band_key = sha2(proficiency_band)` |
| `gold.dim_dq_rule` | One row per data quality rule | `dq_rule_key = sha2(rule_id)` |

Implemented Gold facts:

| Fact | Grain | Batch 1 Validation | Batch 2 Validation |
|---|---|---:|---:|
| `gold.fact_attendance` | One valid attendance record after `DQ003`, `DQ004`, and `DQ005` exclusions | 119,998 rows | 96,934 rows |
| `gold.fact_assessment_result` | One valid assessment result after `DQ006`, `DQ007`, and `DQ008` exclusions | 30,000 rows | 24,234 rows |
| `gold.fact_data_quality_result` | One latest QA rule result per batch and run | 11 rows; 14 failed records; 7 issue rule results | 11 rows; 8 failed records; 5 issue rule results |
| `gold.fact_defect` | One defect per rule, batch, and latest QA run | 7 rows; 14 defect failed records; 7 open defects | 5 rows; 8 defect failed records; 5 open defects |

`gold.dim_school` uses a simple SCD Type 2 pattern. Each school has a stable `school_key`, and each changed school version receives a `school_scd_key`. Batch 2 closes one existing school and adds one new school, so school history is retained instead of overwriting the earlier state.

`gold.dim_student` stores one student snapshot per batch. It includes `student_key`, `student_batch_key`, `school_key`, `school_scd_key`, and `year_level_key`, so attendance and assessment facts can join to the correct student snapshot and school history row for the batch.

`gold.fact_attendance` and `gold.fact_assessment_result` now carry dimensional keys from Gold dimensions instead of loosely recalculating all keys inside the facts. This makes the model more production-like and supports consistent reporting relationships.

For this portfolio build, hashed keys are used to avoid exposing raw identifiers in the dimensional model. In production, raw student identifiers should still be treated as sensitive because hashing predictable IDs is not a full privacy control. A restricted key map, salted tokenisation, or identity service would be preferred for real student data.

Implemented Gold tables:

| Gold table | Purpose |
|---|---|
| `gold.data_quality_summary` | QA status summary by batch, severity, and status |
| `gold.data_quality_rule_detail` | Rule-level QA results for Power BI drill-through |
| `gold.attendance_by_school_month` | School-month attendance metrics |
| `gold.attendance_by_year_level` | Attendance metrics by year level and month |
| `gold.assessment_by_school` | Assessment outcomes by school |
| `gold.assessment_by_domain` | Assessment outcomes by domain and proficiency band |

The reporting schema adds the business-facing semantic layer for Power BI. Reporting views keep dashboard labels, sort orders, status fields, and banding logic out of the raw Gold table design. The current reporting views are built from the Gold star-schema facts and dimensions.

Implemented reporting views:

| Reporting view | Purpose |
|---|---|
| `reporting.vw_data_quality_rule_detail` | Rule result detail with severity, status, failed counts, and dashboard sort fields |
| `reporting.vw_data_quality_summary` | Summary metrics for overview cards and charts |
| `reporting.vw_defect_log` | Open defect evidence with rule name, target table, status, and recommended action |
| `reporting.vw_attendance_by_school_month` | Attendance trend, school, region, school type, and attendance band fields |
| `reporting.vw_attendance_by_year_level` | Year-level attendance trend and dashboard slicer fields |
| `reporting.vw_assessment_by_school` | School-level assessment metrics and score bands |
| `reporting.vw_assessment_by_domain` | Domain and proficiency-band assessment metrics |

Validated reporting view row counts:

| Reporting view | Batch 1 | Batch 2 |
|---|---:|---:|
| `vw_data_quality_rule_detail` | 11 | 11 |
| `vw_data_quality_summary` | 5 | 5 |
| `vw_defect_log` | 7 | 5 |
| `vw_attendance_by_school_month` | 600 | 576 |
| `vw_attendance_by_year_level` | 156 | 156 |
| `vw_assessment_by_school` | 50 | 48 |
| `vw_assessment_by_domain` | 9 | 9 |

## Power BI QA Design

Power BI reads from reporting views, not from Raw, Bronze, Silver, QA, or direct Gold tables.

After the star-schema refactor, the updated reporting views were imported into Power BI and the dashboard visuals still worked as expected. The Power BI report continues to use local dimension tables for slicers, labels, and sort ordering where that keeps the dashboard model simpler. The Databricks Gold dimensions remain the production-style lakehouse model behind the reporting views.

Implemented dashboard pages:

- Data Quality Overview
- Rule Failure Details
- Attendance Reporting Validation
- Assessment Reporting Validation

Dashboard QA verified:

- totals match Gold tables
- filters work by batch, school, year level, domain, and severity
- invalid scores are excluded or flagged consistently
- attendance percentages stay within valid range
- severity counts match `qa.dq_validation_results`
- defect counts match `qa.defect_log`
- visuals are readable and accessible

Student-level identifiers should not be displayed in stakeholder-facing Power BI pages.

Power BI evidence is stored in `powerbi/pipeline_b_databricks_qa/screenshots/`. The SQL Warehouse used for Power BI import was stopped after refresh for cost control.

## ADF Trigger Wrapper Evidence

The ADF wrapper was implemented and tested as a production-style integration pattern:

1. Source batch files are uploaded to ADLS raw batch folders.
2. A marker file is uploaded to `raw/_triggers/batch_id=<batch_id>/_READY.json`.
3. The storage event trigger `trigger_education_qa_databricks_job` detects the marker file.
4. The ADF pipeline `pl_education_qa_databricks_job` runs.
5. The Web activity `act_run_education_qa_databricks_job` calls the Databricks Jobs `run-now` API.
6. The Databricks Job runs the Bronze, Silver, QA, Gold, and reporting notebooks.

ADF wrapper evidence:

| Evidence | Location |
|---|---|
| Databricks Batch 1 job run | `images/pipeline_b_databricks_qa/databricks_job_batch1_initial.png` |
| Databricks Batch 2 job run | `images/pipeline_b_databricks_qa/databricks_job_batch2_incremental.png` |
| ADF pipeline wrapper run | `images/pipeline_b_databricks_qa/adf_pipeline_debug_success.png` |

## Position Alignment

This Databricks QA layer supports the role requirements by demonstrating:

- data validation across ETL/ELT pipelines
- testing across ingestion, transformation, modelling, and reporting
- defect identification, severity assignment, and issue triage
- quality metrics and evidence for decision-making
- Azure and Databricks learning capability
- Power BI dashboard testing
- privacy, access, governance, and traceability awareness

## Current Status

Completed:

- Azure Databricks workspace and ADLS access configured.
- Raw Batch 1 and Batch 2 uploaded.
- Bronze tables loaded with audit metadata.
- Silver tables created with typed fields.
- Bronze-to-Silver row-count reconciliation created.
- QA rule catalog and QA output tables created.
- All 11 DQ rules implemented and validated.
- Failed records and defect log created.
- Gold star-schema dimensions and facts created.
- Reporting views created in the `reporting` schema from Gold facts and dimensions.
- Power BI dashboard built and tested.
- Databricks Job created and tested for Batch 1 initial and Batch 2 incremental processing.
- ADF storage-event wrapper created and successfully triggered with `_READY.json`.
- Gold star-schema dimensions created and validated for Batch 1 and Batch 2.
- Gold star-schema fact tables created and validated for Batch 1 and Batch 2:
  - `gold.fact_attendance`
  - `gold.fact_assessment_result`
  - `gold.fact_data_quality_result`
  - `gold.fact_defect`
- Reporting views refactored to read from Gold facts and dimensions.
- Power BI refreshed against the refactored reporting views; dashboard visuals still look correct.

Remaining packaging work:

- Finalise QA artefacts such as test strategy, UAT plan, defect log narrative, traceability matrix, and governance checklist.
- Update the README with architecture, evidence, cost-control notes, and role alignment.
