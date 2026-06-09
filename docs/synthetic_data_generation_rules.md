# Synthetic Data Generation Rules

## Purpose

This document records the synthetic data generation design for the Azure Databricks education QA project. The project uses two date-based batches so the lakehouse can demonstrate both initial loading and incremental loading.

All data is synthetic. No real student, family, staff, address, contact, or sensitive personal information is included.

## Batch Design

| Batch | Script | Batch ID | Business Period | Purpose |
|---|---|---|---|---|
| Batch 1 | `scripts/generate_synthetic_data.py` | `2025-01-15` | 2024 | Initial baseline load |
| Batch 2 | `scripts/generate_synthetic_batch_2.py` | `2026-01-15` | 2025 | Incremental annual rollover |

Output folders:

```text
data/batches/batch_id=2025-01-15/
data/batches/batch_id=2026-01-15/
```

Target ADLS folders:

```text
raw/<dataset>/batch_id=2025-01-15/<file>
raw/<dataset>/batch_id=2026-01-15/<file>
```

## Table Definitions

| Dataset | Grain | Source Key | Notes |
|---|---|---|---|
| `schools.csv` | One row per school | `school_id` | School reference snapshot |
| `students.csv` | One row per student | `student_id` | Student enrolment snapshot |
| `attendance.csv` | One row per student per month | `attendance_id` | Duplicate QA grain is `student_id + school_id + attendance_month` |
| `assessment_results.csv` | One row per student/year/domain | `assessment_id` | Business grain is `student_id + school_id + assessment_year + domain` |
| `school_events.json` | One row per school event | `event_id` | Semi-structured event data |

## Batch 1 Rules

Batch 1 creates a baseline 2024 dataset:

- 50 schools.
- 10,000 generated students.
- 2024 monthly attendance records.
- 2024 assessment records across Reading, Numeracy, and Writing.
- 2024 school event records.
- Intentional quality issues are injected after generation.

Latest generated Batch 1 counts:

| Dataset | Count |
|---|---:|
| Schools | 50 |
| Students | 10,002 |
| Attendance | 120,003 |
| Assessment Results | 30,001 |
| School Events | 146 |

## Batch 1 Intentional Data Quality Issues

| Issue | Dataset | Purpose |
|---|---|---|
| Missing `school_id` | `students.csv` | Required foreign key validation |
| Missing `student_id` | `students.csv` | Required primary key validation |
| Invalid attendance days | `attendance.csv` | `attended_days` exceeds `possible_days` |
| Duplicate attendance business record | `attendance.csv` | Duplicate detection by student, school, and month |
| Orphan attendance student | `attendance.csv` | Referential integrity validation |
| Invalid assessment score | `assessment_results.csv` | Numeric range validation |

## Batch 2 Rules

Batch 2 reads Batch 1 schools and students, then creates a 2025 annual rollover:

- Existing schools are copied from Batch 1.
- `SCH050` is changed to `Closed`.
- New school `SCH051` is added as an active primary school.
- Existing active students generally increase by one `year_level`.
- Year 12 active students become `Left`.
- Most students stay at the same school.
- Students move schools only when their current school no longer supports the new year level, their school is closed, or they are selected for a small voluntary transfer.
- 500 new students are added.
- New students are mostly Foundation/Kindergarten (`year_level = 0`), with some transfer-style enrolments into later years.
- 2025 attendance is generated for active Batch 2 students.
- 2025 assessments are generated for active Batch 2 students.
- 2025 school events are generated for active Batch 2 schools.
- Intentional Batch 2 quality issues are injected after generation.

Latest generated Batch 2 counts:

| Dataset | Count |
|---|---:|
| Schools | 51 |
| Students | 10,502 |
| Attendance | 96,939 |
| Assessment Results | 24,235 |
| School Events | 135 |

## Batch 2 Intentional Data Quality Issues

| Issue | Dataset | Purpose |
|---|---|---|
| Missing `school_id` | `students.csv` | Required foreign key validation |
| Invalid attendance days | `attendance.csv` | `attended_days` exceeds `possible_days` |
| Duplicate attendance business record | `attendance.csv` | Duplicate detection by student, school, and month |
| Orphan attendance student | `attendance.csv` | Referential integrity validation |
| Invalid assessment score | `assessment_results.csv` | Numeric range validation |

## Incremental Loading Intent

The two-batch design supports this Databricks pattern:

| Layer | Batch 1 | Batch 2 |
|---|---|---|
| Raw | Upload initial files | Upload new dated batch files |
| Bronze | Create initial Delta tables | Append new batch records |
| Silver | Create typed and standardised tables | Merge/upsert reference snapshots and append/merge facts |
| QA | Run rules for Batch 1 | Run rules by `batch_id` and compare quality |
| Gold | Build initial reporting outputs | Refresh affected year/month outputs |

Bronze audit columns should include:

- `source_file_name`
- `load_timestamp`
- `run_id`
- `batch_id`
- `bronze_record_id`

## Consistency Notes

- Batch 1 currently generates attendance and assessment records for all generated students, regardless of student status.
- Batch 2 generates attendance and assessment records only for active students after rollover.
- Batch 2 contains a duplicate `choose_school_for_year_level` function definition in the script; Python uses the second definition. This should be cleaned up later for readability.
- Batch 2 skips only blank `student_id` rows during rollover. The Batch 1 test record `STU_BAD_MISSING_SCHOOL` starts with `STU`, so it is rolled forward rather than skipped.
- These behaviours are acceptable for current learning, but should be reviewed before describing the generator as production-grade.
