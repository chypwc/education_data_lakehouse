# Technical Specification

## Project

ACT Education Azure Lakehouse Mini Project

## Purpose

This project demonstrates an Azure-based education data engineering workflow using synthetic school, student, attendance, assessment, and school event data.

The implemented solution shows:

- ADLS Gen2 lakehouse folder organisation.
- Azure Data Factory orchestration.
- Synapse serverless SQL staging views.
- SQL-based data quality checks.
- Materialised quality outputs in ADLS Gen2.
- Materialised lightweight Data Vault tables in ADLS Gen2.
- Materialised curated dimensional tables in ADLS Gen2.
- SQL reporting views for analysis and optional Power BI.

## Implemented Architecture

```text
Local synthetic CSV / JSON files
        |
        v
Azure CLI upload
        |
        v
ADLS Gen2 raw zone
        |
        v
Azure Data Factory raw-to-staging pipeline
        |
        v
ADLS Gen2 staging zone
        |
        v
Synapse serverless SQL staging views
        |
        v
Data quality validation view
        |
        v
ADLS Gen2 quality zone as Parquet
        |
        v
ADLS Gen2 vault zone as Parquet
        |
        v
ADLS Gen2 curated zone as Parquet
        |
        v
SQL reporting views / optional Power BI
```

## Azure Resources

| Resource | Name | Purpose |
|---|---|---|
| Resource group | `rg-act-education-lakehouse-dev` | Project resource container |
| Storage account | `stactedulakehousechien` | ADLS Gen2 storage account |
| File system / container | `education-data-lake` | Lakehouse storage container |
| Azure Data Factory | Project ADF resource | Raw-to-staging orchestration |
| ADF linked service | `ls_adls_education_lakehouse` | Connection to ADLS Gen2 |
| Synapse workspace | `syn-act-education-lakehouse-dev` | Serverless SQL workspace |
| Synapse database | `act_education_lakehouse` | SQL database for views and external tables |

## Storage Layout

```text
education-data-lake/
  raw/
    schools/
    students/
    attendance/
    assessment_results/
    school_events/
  staging/
    stg_schools/
    stg_students/
    stg_attendance/
    stg_assessment_results/
    stg_school_events/
  quality/
    validation_results/
      dq_validation_results/
  vault/
    hubs/
    links/
    satellites/
  curated/
    dimensions/
    facts/
```

## Data Sources

| File | Format | Raw path | Description |
|---|---|---|---|
| `schools.csv` | CSV | `raw/schools/` | School reference data |
| `students.csv` | CSV | `raw/students/` | Student enrolment data |
| `attendance.csv` | CSV | `raw/attendance/` | Monthly attendance data |
| `assessment_results.csv` | CSV | `raw/assessment_results/` | Assessment results by year and domain |
| `school_events.json` | JSON | `raw/school_events/` | API-style school event data |

All data is synthetic. No real student, family, address, phone, email, or personally identifiable information is included.

## Ingestion

Synthetic files are generated locally by:

```text
scripts/shared/generate_synthetic_data.py
```

The initial raw landing step is performed using Azure CLI upload into the ADLS Gen2 raw zone. Azure Data Factory then orchestrates copying from raw folders into staging folders.

ADF pipeline:

```text
pl_copy_raw_to_staging
```

Pipeline activities:

| Activity | Source | Sink |
|---|---|---|
| `copy_schools_raw_to_staging` | `raw/schools/schools.csv` | `staging/stg_schools/schools.csv` |
| `copy_students_raw_to_staging` | `raw/students/students.csv` | `staging/stg_students/students.csv` |
| `copy_attendance_raw_to_staging` | `raw/attendance/attendance.csv` | `staging/stg_attendance/attendance.csv` |
| `copy_assessment_results_raw_to_staging` | `raw/assessment_results/assessment_results.csv` | `staging/stg_assessment_results/assessment_results.csv` |
| `copy_school_events_raw_to_staging` | `raw/school_events/school_events.json` | `staging/stg_school_events/school_events.json` |

## Synapse SQL Objects

### External Objects

Defined in:

```text
sql/pipeline_a_synapse_baseline/00_create_external_objects.sql
```

| Object | Purpose |
|---|---|
| `education_lake` | External data source pointing to the ADLS Gen2 container |
| `parquet_format` | External file format for materialised Parquet output |

### Staging Views

Defined in:

```text
sql/pipeline_a_synapse_baseline/01_create_staging_views.sql
```

| View | Source |
|---|---|
| `stg_schools` | `staging/stg_schools/schools.csv` |
| `stg_students` | `staging/stg_students/students.csv` |
| `stg_attendance` | `staging/stg_attendance/attendance.csv` |
| `stg_assessment_results` | `staging/stg_assessment_results/assessment_results.csv` |
| `stg_school_events` | `staging/stg_school_events/school_events.json` |

The staging views standardise dates and numeric fields and add:

- `source_file_name`
- `load_timestamp`

## Data Quality

Defined in:

```text
sql/pipeline_a_synapse_baseline/06_data_quality_checks.sql
```

The view:

```text
dbo.dq_validation_results
```

summarises validation results by rule.

Implemented checks include:

- Missing student ID.
- Missing school ID.
- Invalid attendance days.
- Duplicate attendance business records.
- Attendance orphan student.
- Assessment orphan student.
- Invalid assessment score.
- Invalid proficiency band.
- Invalid school status.
- Future attendance month.
- Activity linked to inactive school.

The validation summary is materialised to ADLS Gen2 as Parquet by:

```text
sql/pipeline_a_synapse_baseline/03_materialize_quality_results.sql
```

Output path:

```text
quality/validation_results/dq_validation_results/
```

## Data Vault Layer

Defined in:

```text
sql/pipeline_a_synapse_baseline/04_create_vault_tables.sql
```

The Data Vault layer is materialised to ADLS Gen2 as Parquet.

### Hubs

| Table | Business key | Output path |
|---|---|---|
| `hub_school` | `school_id` | `vault/hubs/hub_school/` |
| `hub_student` | `student_id` | `vault/hubs/hub_student/` |
| `hub_assessment` | `assessment_id` | `vault/hubs/hub_assessment/` |
| `hub_event` | `event_id` | `vault/hubs/hub_event/` |

### Links

| Table | Relationship | Output path |
|---|---|---|
| `link_student_school` | Student to school | `vault/links/link_student_school/` |
| `link_student_assessment` | Student to assessment | `vault/links/link_student_assessment/` |
| `link_school_event` | School to event | `vault/links/link_school_event/` |

### Satellites

| Table | Description | Output path |
|---|---|---|
| `sat_school_details` | School attributes | `vault/satellites/sat_school_details/` |
| `sat_student_details` | Student group/enrolment attributes | `vault/satellites/sat_student_details/` |
| `sat_attendance_record` | Attendance record attributes | `vault/satellites/sat_attendance_record/` |
| `sat_assessment_result` | Assessment attributes and score | `vault/satellites/sat_assessment_result/` |
| `sat_event_details` | School event attributes | `vault/satellites/sat_event_details/` |

The vault layer is source-aligned and auditable. It preserves records where business keys are usable, while the data quality layer flags issues.

## Curated Dimensional Model

Defined in:

```text
sql/pipeline_a_synapse_baseline/05_create_curated_tables.sql
```

The curated layer is materialised to ADLS Gen2 as Parquet.

### Dimensions

| Table | Purpose | Output path |
|---|---|---|
| `dim_school` | School reporting attributes | `curated/dimensions/dim_school/` |
| `dim_student_group` | Aggregated student grouping by school, year level, gender, and status | `curated/dimensions/dim_student_group/` |
| `dim_date` | Calendar dates for attendance, assessment, and events | `curated/dimensions/dim_date/` |
| `dim_assessment_domain` | Assessment domain lookup | `curated/dimensions/dim_assessment_domain/` |
| `dim_event_type` | Event type lookup | `curated/dimensions/dim_event_type/` |

### Facts

| Table | Purpose | Output path |
|---|---|---|
| `fact_attendance` | Attendance measures and validity flags | `curated/facts/fact_attendance/` |
| `fact_assessment` | Assessment scores, proficiency flags, and validity flags | `curated/facts/fact_assessment/` |
| `fact_school_events` | School event counts | `curated/facts/fact_school_events/` |

Curated dimensions exclude invalid keys and unexpected category values. Curated facts exclude orphan key records through dimension joins and retain some measure issues with validity flags such as `is_valid_attendance` and `is_valid_score`.

## Reporting Views

Defined in:

```text
sql/pipeline_a_synapse_baseline/07_reporting_views.sql
```

| View | Purpose |
|---|---|
| `vw_attendance_by_school` | Attendance metrics by school and month |
| `vw_attendance_by_year_level` | Attendance metrics by school, year level, gender, and status |
| `vw_assessment_by_school` | Assessment metrics by school, year, and domain |
| `vw_assessment_by_domain` | Assessment metrics by year and domain |
| `vw_data_quality_summary` | Data quality monitoring summary |

## Rerun Notes

Synapse serverless SQL CETAS requires the target ADLS folder to be empty.

To rerun a materialisation script for a specific table:

1. Drop the external table metadata.
2. Delete the corresponding output folder in ADLS Gen2.
3. Rerun the `CREATE EXTERNAL TABLE AS SELECT` statement.

Example:

```sql
DROP EXTERNAL TABLE dbo.dim_school;
GO
```

Then delete:

```text
curated/dimensions/dim_school/
```

before rerunning the CETAS statement.

## Security And Cost Settings

This is a low-cost portfolio implementation:

- Synthetic data only.
- Resource-group budget guardrail configured.
- Default Azure Data Factory networking.
- Synapse serverless SQL instead of dedicated SQL pool.
- ADLS Gen2 hierarchical namespace enabled.
- Default Microsoft-managed encryption.

Production extensions would include:

- Private endpoints.
- Managed identities for all service-to-service access.
- Key Vault for secrets.
- Stricter RBAC.
- Monitoring and alerting.
- Pipeline run IDs and batch metadata.
- Formal rejected-record handling.

## Known Limitations

- Raw landing is seeded by Azure CLI rather than a full ADF landing-to-raw ingestion pipeline.
- Staging is implemented as Synapse serverless SQL views over staged files rather than materialised staging tables.
- Data Vault implementation is lightweight and does not include hashdiffs, effective dating, or full historisation.
- `DQ011` activity linked to inactive school is a low-severity review flag because the synthetic school data has status but no closure date.
- Power BI dashboard is optional and not yet implemented.

## Evidence

| Evidence | Location |
|---|---|
| Architecture documentation | `docs/shared/architecture.md` |
| Data dictionary | `docs/shared/data_dictionary.md` |
| Data quality rules | `docs/pipeline_a_synapse_baseline/data_quality_rules.md` |
| Data model diagram | `docs/shared/data_model_diagram.md` |
| ADF pipeline JSON | `adf/pipeline_export/pl_copy_raw_to_staging.json` |
| ADF screenshots | `adf/pipeline_screenshots/` |
| Azure/Synapse screenshots | `images/pipeline_a_synapse_baseline/` |
| Validation result export | `data/generated/data_validation_results.csv` |
