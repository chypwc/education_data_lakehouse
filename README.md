# ACT Education Azure Lakehouse QA Portfolio

This portfolio project demonstrates two Azure education data pipelines built with synthetic school, student, attendance, assessment, and school event data.

The project started as an **ADF + Synapse lakehouse pipeline** and was extended into a more production-style **Azure Databricks QA lakehouse** with Delta tables, Databricks Jobs, data quality rules, defect logging, Gold star-schema facts and dimensions, reporting views, an ADF trigger wrapper, and Power BI validation.

## Data Disclaimer

All data is synthetic. The school, student, attendance, assessment, and event records do not represent real ACT Education Directorate schools, students, staff, families, addresses, or outcomes.

## Project Framing

This repository is best presented as one portfolio project with two implementation paths:

| Pipeline | Role in Portfolio | Main Purpose |
|---|---|---|
| Pipeline A: ADF + Synapse | Foundation / baseline implementation | Demonstrates ADLS, ADF ingestion, Synapse serverless SQL, SQL quality checks, Data Vault-style modelling, curated marts, and Power BI |
| Pipeline B: Databricks QA Lakehouse | Primary QA Analyst showcase | Demonstrates Databricks, Delta Lake, Bronze/Silver/QA/Gold layers, rule catalogues, failed-record evidence, defect logging, incremental loading, orchestration, and dashboard testing |

The Databricks pipeline is the main project for the ACT Education QA Analyst role because it shows end-to-end QA practice across ingestion, transformation, validation, reporting, defect handling, UAT support, and governance.

## Architecture

Full architecture details are documented in [docs/architecture.md](docs/architecture.md).

### Pipeline A: ADF + Synapse Baseline

```text
Synthetic CSV / JSON files
        |
        v
Azure CLI upload to ADLS raw zone
        |
        v
Azure Data Factory raw-to-staging pipeline
        |
        v
Synapse serverless SQL staging views
        |
        v
SQL data quality validation results
        |
        v
Data Vault-style Parquet layer
        |
        v
Curated dimensional Parquet layer
        |
        v
Synapse SQL reporting views
        |
        v
Power BI dashboard
```

### Pipeline B: Databricks QA Lakehouse

```text
ADLS raw batch files
        |
        v
Databricks Job: job_education_qa_pipeline
        |
        +--> 01_ingest_raw_to_bronze
        +--> 02_transform_bronze_to_silver
        +--> 03_run_data_quality_checks
        +--> 04_build_gold_reporting_tables
        +--> 05_create_reporting_views
        |
        v
Power BI QA dashboard
```

Implemented enterprise wrapper:

```text
ADLS marker file: raw/_triggers/batch_id=<batch_id>/_READY.json
        |
        v
ADF storage event trigger
        |
        v
ADF pipeline Web activity
        |
        v
Databricks Jobs API run-now
        |
        v
job_education_qa_pipeline
```

Databricks Jobs are the main orchestrator for the Databricks pipeline. Azure Data Factory is used as an optional enterprise wrapper for event-based triggering and cross-service integration evidence.

## Azure Services Used

- Azure Data Lake Storage Gen2
- Azure Data Factory
- Azure Synapse Analytics serverless SQL
- Azure Databricks
- Delta Lake
- Unity Catalog
- Power BI Desktop

## Source Datasets

| Dataset | Description |
|---|---|
| `schools.csv` | Synthetic school reference data |
| `students.csv` | Synthetic student enrolment data |
| `attendance.csv` | Monthly attendance records |
| `assessment_results.csv` | Assessment outcomes by domain |
| `school_events.json` | API-style school event data |

Two synthetic batches are used in the Databricks pipeline:

| Batch | Batch ID | Data Period | Load Type |
|---|---|---:|---|
| Batch 1 | `2025-01-15` | 2024 | Initial load |
| Batch 2 | `2026-01-15` | 2025 | Incremental load |

Batch 2 includes new and changed data so the project can demonstrate incremental processing, regression checks, and dashboard refresh behaviour.

## Databricks QA Pipeline

The Databricks implementation uses these layers:

| Layer | Purpose |
|---|---|
| Raw | Batch-partitioned source files in ADLS |
| Bronze | Raw Delta tables with audit metadata and lineage |
| Silver | Typed, cleaned, standardised Delta tables |
| QA | Rule catalogue, validation results, failed records, and defect log |
| Gold | Production-style star schema with dimensions and facts |
| Reporting | Stable Power BI-facing views |

Implemented QA rules:

- Missing student ID
- Missing school ID
- Invalid attendance days
- Duplicate attendance business records
- Attendance references missing student
- Assessment references missing student
- Invalid assessment score
- Invalid proficiency band
- Invalid school status
- Future attendance month
- School event linked to inactive or missing school

Latest validated QA outcome:

| Batch | QA Rule Results | Issue Rule Results | Failed or Warning Records | Defects |
|---|---:|---:|---:|---:|
| Batch 1 - 2024 data | 11 | 7 | 14 | 7 |
| Batch 2 - 2025 data | 11 | 5 | 8 | 5 |
| Total | 22 | 12 | 22 | 12 |

## Gold Star Schema

The Databricks Gold layer includes shared dimensions and facts for reporting:

Dimensions:

- `gold.dim_batch`
- `gold.dim_date`
- `gold.dim_school`
- `gold.dim_student`
- `gold.dim_year_level`
- `gold.dim_assessment_domain`
- `gold.dim_proficiency_band`
- `gold.dim_dq_rule`

Facts:

- `gold.fact_attendance`
- `gold.fact_assessment_result`
- `gold.fact_data_quality_result`
- `gold.fact_defect`

Reporting views are created in the `reporting` schema and imported into Power BI.

## Power BI Reports

The Databricks QA dashboard imports Databricks reporting views and includes:

- Data Quality Overview
- Rule Failure Details
- Attendance Validation
- Assessment Validation

Current report file:

- `powerbi/QA_dashboard.pbix`

Dashboard screenshots:

- `powerbi/screenshots/powerbi_data_quality_overview.png`
- `powerbi/screenshots/powerbi_rule_failure_details.png`
- `powerbi/screenshots/powerbi_attendance_validation.png`
- `powerbi/screenshots/powerbi_assessment_validation.png`

The earlier Synapse dashboard remains as baseline evidence:

- `powerbi/lakehouse_dashboard.pbix`
- Earlier screenshots are also stored under `powerbi/screenshots/`.

## Repository Structure

```text
adf/                         ADF exports for the original Synapse pipeline
data/                        Synthetic generated data and batch folders
databricks_notebooks/        Exported Databricks notebooks in .ipynb format
docs/                        Architecture, QA strategy, data model, UAT, governance, and project notes
images/                      Azure, Databricks, ADF, and evidence screenshots
powerbi/                     Power BI reports, notes, and screenshots
scripts/                     Synthetic data generation and script-format notebook exports
sql/                         Synapse SQL scripts and earlier lakehouse SQL artefacts
checklist.md                 Project execution and evidence checklist
```

## Key Evidence

Databricks QA project:

- [docs/databricks_qa_layer_design.md](docs/databricks_qa_layer_design.md)
- [docs/qa_test_strategy.md](docs/qa_test_strategy.md)
- [docs/test_case_matrix.md](docs/test_case_matrix.md)
- [docs/defect_log.md](docs/defect_log.md)
- [docs/uat_plan.md](docs/uat_plan.md)
- [docs/requirements_traceability_matrix.md](docs/requirements_traceability_matrix.md)
- [docs/governance_accessibility_privacy_checklist.md](docs/governance_accessibility_privacy_checklist.md)
- [docs/power_bi_dashboard_test_results.md](docs/power_bi_dashboard_test_results.md)
- [docs/data_model_diagram.md](docs/data_model_diagram.md)
- `databricks_notebooks/01_ingest_raw_to_bronze.ipynb`
- `databricks_notebooks/02_transform_bronze_to_silver.ipynb`
- `databricks_notebooks/03_run_data_quality_checks.ipynb`
- `databricks_notebooks/04_build_gold_reporting_tables.ipynb`
- `databricks_notebooks/05_create_reporting_views.ipynb`
- `scripts/exported_notebook_scripts/` for script-format copies of the Databricks notebooks
- `images/databricks_qa/`
- `powerbi/QA_dashboard.pbix`

ADF + Synapse baseline:

- `adf/pipeline_export/pl_copy_raw_to_staging.json`
- `sql/01_create_staging_views.sql`
- `sql/04_create_vault_tables.sql`
- `sql/05_create_curated_tables.sql`
- `sql/06_data_quality_checks.sql`
- `sql/07_reporting_views.sql`
- [docs/technical_specification.md](docs/technical_specification.md)

## Role Alignment

This project maps to the ACT Education Quality Assurance Analyst role by demonstrating:

- Data pipeline QA across ingestion, transformation, validation, reporting, and service delivery.
- Quality assurance practices for completeness, validity, duplicates, referential integrity, and business review flags.
- Defect logging with severity, status, failed record counts, and recommended actions.
- Batch-based regression testing using initial and incremental runs.
- Power BI dashboard testing against Databricks reporting views.
- UAT planning, traceability, governance, privacy, and accessibility documentation.
- Clear evidence capture for technical and non-technical stakeholders.

## Limitations

- The data is synthetic and intentionally small.
- Production CI/CD, automated monitoring, and alerting are documented as recommendations but not fully implemented.
- Power BI uses import mode for portfolio convenience.
- The ADF wrapper uses a short-lived Databricks token for demonstration; production should use managed identity or service principal patterns where supported.
- The earlier Synapse Data Vault layer demonstrates modelling awareness rather than a full enterprise Data Vault implementation.

## Future Improvements

- Add CI/CD for Databricks notebooks, SQL, ADF, and Power BI artefacts.
- Store secrets and tokens in Azure Key Vault.
- Add automated pipeline alerts for failed Databricks Jobs, ADF runs, and high-severity data quality failures.
- Add formal row-level security and object-level security for Power BI and Databricks.
- Add Microsoft Purview-style data catalogue and lineage documentation.
- Add production runbooks for reruns, incident handling, and defect closure.
