# ACT Education Azure Lakehouse Mini Project

This portfolio project demonstrates an Azure-based education data lakehouse using synthetic school, student, attendance, assessment, and school event data.

It was built to practise and evidence Azure Data Factory, Azure Data Lake Storage Gen2, Synapse serverless SQL, SQL-based data quality checks, lightweight Data Vault modelling, curated dimensional modelling, and Power BI reporting.

## Data Disclaimer

All data is synthetic. The school, student, attendance, assessment, and event records do not represent real ACT Education Directorate schools, students, staff, or outcomes.

## Architecture

See the final architecture diagram in `docs/architecture.md`.

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
Data quality validation results
        |
        v
Materialised Data Vault-style Parquet layer
        |
        v
Materialised curated dimensional Parquet layer
        |
        v
Synapse SQL reporting views
        |
        v
Power BI dashboard
```

Synapse reads and writes ADLS Gen2 through the workspace Managed Identity.

## Azure Services Used

- Azure Data Lake Storage Gen2
- Azure Data Factory
- Azure Synapse Analytics serverless SQL
- Power BI Desktop

## Datasets

| Dataset | Description |
|---|---|
| `schools.csv` | Synthetic school reference data |
| `students.csv` | Synthetic student enrolment data |
| `attendance.csv` | Monthly attendance records |
| `assessment_results.csv` | Assessment outcomes by domain |
| `school_events.json` | API-style school event data |

The data generation script intentionally injects selected quality issues, including missing keys, duplicate attendance records, invalid attendance values, orphan records, and invalid assessment scores.

## Repository Structure

```text
adf/          Azure Data Factory pipeline export and screenshots
data/         Synthetic source data and generated validation export
docs/         Architecture, data dictionary, data model, quality rules, and interview notes
images/       Azure and Synapse evidence screenshots
powerbi/      Power BI report and dashboard screenshots
scripts/      Synthetic data generation script
sql/          Synapse SQL scripts for staging, quality, vault, curated, and reporting layers
```

## SQL Layers

| Layer | Purpose |
|---|---|
| Staging views | Standardise files from the staging lake zone |
| Data quality | Summarise validation failures across staging datasets |
| Data Vault-style layer | Separate hubs, links, and satellites for auditable modelling awareness |
| Curated dimensional layer | Create reporting-ready dimensions and facts |
| Reporting views | Provide Power BI-ready attendance, assessment, and data quality outputs |

## Power BI Report

The Power BI report imports Synapse serverless SQL reporting views and includes:

- Attendance Overview
- Attendance Details
- Assessment Overview
- Assessment Details
- Data Quality Monitor

Report file:

- `powerbi/dashboard.pbix`

Screenshots:

- `powerbi/screenshots/attendance_overview.png`
- `powerbi/screenshots/assessment_overview.png`
- `powerbi/screenshots/data_quality_monitor.png`
- `powerbi/screenshots/attendance_details.png`
- `powerbi/screenshots/assessment_details.png`

## Key Project Evidence

- ADF pipeline export: `adf/pipeline_export/pl_copy_raw_to_staging.json`
- Staging SQL: `sql/01_create_staging_views.sql`
- Data quality SQL: `sql/06_data_quality_checks.sql`
- Vault SQL: `sql/04_create_vault_tables.sql`
- Curated model SQL: `sql/05_create_curated_tables.sql`
- Reporting views SQL: `sql/07_reporting_views.sql`
- Architecture diagram: `docs/architecture.md`
- Technical specification: `docs/technical_specification.md`
- Data model diagram: `docs/data_model_diagram.md`

## Role Alignment

This project maps to common data engineering responsibilities in an education analytics context:

- Ingesting file-based source data with Azure Data Factory
- Organising raw, staging, quality, vault, and curated lake zones in ADLS Gen2
- Using Synapse serverless SQL for ELT, external tables, and reporting views
- Implementing SQL-based validation for completeness, validity, duplicates, and referential integrity
- Creating a lightweight Data Vault-style model and curated dimensional model
- Producing Power BI-ready datasets and dashboard evidence
- Documenting design decisions, limitations, and implementation steps

## Limitations

- The data is synthetic and intentionally small.
- The pipeline is batch-oriented and not production automated.
- Security, CI/CD, monitoring, and governance are simplified for portfolio scope.
- The Data Vault layer demonstrates modelling awareness rather than a full enterprise implementation.

## Future Improvements

- Add metadata-driven ADF ingestion.
- Add incremental loading.
- Add automated triggers and monitoring.
- Add CI/CD with GitHub Actions or Azure DevOps.
- Add Power BI row-level security.
- Add unit tests for SQL transformations.
- Add Microsoft Purview-style data governance documentation.
