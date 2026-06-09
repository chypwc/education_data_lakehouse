# QA Test Strategy

## Purpose

This document defines the quality assurance approach for the Azure Databricks Education QA project. The project validates a synthetic education lakehouse pipeline from ADLS raw files through Bronze, Silver, QA, Gold star-schema tables, reporting views, and Power BI dashboards.

The strategy is designed to demonstrate practical QA Analyst capability: data validation, reconciliation, defect handling, reporting checks, UAT support, traceability, and governance awareness.

## Scope

In scope:

- ADLS raw batch structure and file availability.
- Bronze ingestion audit metadata and idempotent batch loading.
- Silver type standardisation and row-count reconciliation.
- Data quality rule execution for required keys, valid measures, duplicates, referential integrity, and review flags.
- Defect logging and failed-record traceability.
- Gold star-schema dimensions and facts.
- Databricks reporting views used by Power BI.
- Power BI dashboard calculations, slicers, labels, and visual checks.
- Databricks Job orchestration and Azure Data Factory wrapper evidence.

Out of scope:

- Real student, family, staff, or school operational data.
- Production identity lifecycle management.
- Enterprise monitoring and alerting beyond project evidence.
- Full automated CI/CD deployment.

## Test Data

| Batch | Batch ID | Data Period | Load Type | Purpose |
|---|---|---:|---|---|
| Batch 1 | `2025-01-15` | 2024 | Initial load | Establish baseline pipeline and QA outcomes |
| Batch 2 | `2026-01-15` | 2025 | Incremental load | Validate repeatable batch processing, changed schools, new students, and regression behaviour |

All data is synthetic. Batch 2 deliberately includes realistic changes such as new students, graduated students, changed enrolments, a new school, and intentional data quality issues.

## Test Levels

| Level | Objective | Evidence |
|---|---|---|
| Raw file validation | Confirm expected source files exist by batch | ADLS folder screenshots and upload validation |
| Bronze validation | Confirm raw data is ingested with audit fields | Bronze row counts and metadata checks |
| Silver validation | Confirm data types, cleaned fields, and reconciled counts | Silver schemas, row-count reconciliation |
| Data quality validation | Confirm known issues are detected and clean rules pass | `qa.dq_validation_results`, `qa.dq_failed_records`, `qa.defect_log` |
| Gold model validation | Confirm trusted star-schema outputs have expected grain and valid foreign keys | Gold fact/dimension validation queries |
| Reporting view validation | Confirm views return dashboard-ready outputs | Reporting view row-count checks |
| Power BI validation | Confirm dashboard metrics match reporting views | Dashboard test results and screenshots |
| Orchestration validation | Confirm Databricks Job and ADF wrapper execute successfully | Job run and ADF activity run screenshots |

## Entry Criteria

- Azure resources are created and accessible.
- ADLS container and batch folders exist.
- Databricks workspace, catalog, schemas, external location, and storage credentials are configured.
- Batch 1 and Batch 2 source files are available in ADLS.
- Databricks notebooks are parameterised by `environment`, `batch_id`, `run_mode`, and `job_run_id`.

## Exit Criteria

- Batch 1 initial run succeeds end to end.
- Batch 2 incremental run succeeds end to end.
- Bronze and Silver counts are stable after repeated incremental reruns for the same batch.
- QA rules produce expected PASS, FAIL, and WARN results.
- Gold facts and dimensions validate with no missing required dimension keys for trusted reporting records.
- Reporting views return expected batch row counts.
- Power BI dashboards refresh and match Databricks reporting results.
- ADF wrapper successfully triggers the Databricks Job.
- Evidence screenshots and close-out documentation are saved.

## Defect Management

Defects are created from QA rules with non-zero failed record counts. Each defect includes:

- Rule ID and rule name.
- Batch ID.
- Severity.
- Target table.
- Failed record count.
- Status.
- Recommended action.

High-severity failures represent required-key, invalid-measure, or orphan-record issues. Medium-severity failures represent duplicates or invalid categories. Low-severity warnings represent review flags, such as events linked to closed or missing schools.

## Production Readiness Notes

This project is portfolio-focused but designed with production patterns:

- Managed identity and external locations are used instead of local file paths.
- Batch IDs and run IDs support auditability.
- Incremental loads delete and replace the target batch to make reruns idempotent.
- Silver applies latest-record deduplication for repeated Bronze loads.
- Gold uses a star schema with conformed dimensions and fact tables.
- Reporting views provide stable Power BI contracts.

Recommended production hardening:

- Move secrets to Azure Key Vault.
- Add automated alerts for failed Databricks Jobs and ADF runs.
- Add deployment pipelines for notebooks, SQL, and Power BI.
- Replace synthetic identifiers with approved privacy-preserving keys.
- Add formal data owner sign-off and service support processes.
