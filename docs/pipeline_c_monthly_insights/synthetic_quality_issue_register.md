# Pipeline C Synthetic Quality Issue Register

## Purpose

This document tracks the intentional data quality issues imposed during the Pipeline C synthetic data generation process.

These issues exist to support realistic reporting caveats, quality checks, rejected-record handling, and monthly reporting readiness. They should remain small enough that the analytics story is still readable.

Source script:

- `scripts/pipeline_c_monthly_insights/generate_pipeline_c_data.py`

Generated data location:

- `data/pipeline_c_monthly_insights/month=YYYY-MM/`

## Design Principles

- Raw files keep the imposed issues exactly as generated.
- Bronze loads the source-shaped records and adds ingestion metadata.
- Silver validates, deduplicates, rejects, or caveats records before trusted reporting.
- Quality records the issue details and reporting impact.
- Gold and reporting views should use valid records for metrics and expose caveats for stakeholder interpretation.

## Summary

| Issue type | Months | Source file | Expected injected records | Expected rule failures |
|---|---:|---|---:|---:|
| Missing school reference | `2024-03` | `students_delta.csv` | 1 | 1 |
| Invalid attended days | `2024-06`, `2025-06` | `attendance.csv` | 2 | 4 |
| Duplicate attendance business key | `2024-08`, `2025-08` | `attendance.csv` | 2 | 2 |
| Orphan attendance student | `2025-09` | `attendance.csv` | 1 | 1 |
| Invalid assessment score | `2024-11`, `2025-11` | `assessment_results_delta.csv` | 2 | 2 |

Expected total:

- 8 intentionally injected records.
- 10 expected rule failures.

The invalid attended-days records also duplicate an existing student/month attendance business key, so each of those two records should fail both:

- duplicate attendance business key;
- attended days greater than possible days.

## Issue Register

### DQ-C-001: Missing School Reference

| Field | Detail |
|---|---|
| Month | `2024-03` |
| Source file | `month=2024-03/students_delta.csv` |
| Injected record | `student_id = STU_CAVEAT_MISSING_SCHOOL` |
| Imposed issue | `school_id` is blank |
| Expected rule | Student records must reference a valid school |
| Suggested severity | High |
| Expected handling | Reject from trusted silver student table or quarantine as a caveated record |
| Reporting impact | Show as a data quality caveat for March 2024; do not let the record affect school-level student counts |

### DQ-C-002: Invalid Attendance Days

| Field | Detail |
|---|---|
| Months | `2024-06`, `2025-06` |
| Source file | `attendance.csv` |
| Injected records | `ATT_CAVEAT_INVALID_DAYS_202406`, `ATT_CAVEAT_INVALID_DAYS_202506` |
| Imposed issue | `attended_days` is greater than `possible_days` |
| Expected rule | `attended_days <= possible_days` |
| Suggested severity | High |
| Expected handling | Exclude from valid attendance metrics; record in `quality.rejected_record` or `quality.reporting_caveat` |
| Reporting impact | Show as a caveat in June 2024 and June 2025 reporting readiness |

Notes:

- These records are copied from existing attendance rows and given new `attendance_id` values.
- They also duplicate the original student/school/month business key.
- They should therefore trigger both invalid-days and duplicate-business-key checks.

### DQ-C-003: Duplicate Attendance Business Key

| Field | Detail |
|---|---|
| Months | `2024-08`, `2025-08` |
| Source file | `attendance.csv` |
| Injected records | `ATT_CAVEAT_DUPLICATE_202408`, `ATT_CAVEAT_DUPLICATE_202508` |
| Imposed issue | Duplicate attendance record for the same student, school, and month |
| Expected rule | One attendance record per student, school, and attendance month |
| Suggested severity | Medium |
| Expected handling | Deduplicate before silver/gold metrics; record duplicate in quality layer |
| Reporting impact | Show as a caveat for August 2024 and August 2025; valid attendance metrics should use one trusted row |

Recommended business key:

```text
student_id + school_id + attendance_month
```

After surrogate keys are assigned in silver, the trusted business key becomes:

```text
student_key + school_key + attendance_month
```

### DQ-C-004: Orphan Attendance Student

| Field | Detail |
|---|---|
| Month | `2025-09` |
| Source file | `month=2025-09/attendance.csv` |
| Injected record | `ATT_CAVEAT_ORPHAN_STUDENT_202509` |
| Imposed issue | `student_id = STU999999` does not exist in the student records |
| Expected rule | Attendance must reference a known student |
| Suggested severity | High |
| Expected handling | Reject from trusted attendance metrics; record in quality layer |
| Reporting impact | Show as a September 2025 caveat; do not include the orphan record in attendance summaries |

### DQ-C-005: Invalid Assessment Score

| Field | Detail |
|---|---|
| Months | `2024-11`, `2025-11` |
| Source file | `assessment_results_delta.csv` |
| Injected records | `ASM_CAVEAT_INVALID_SCORE_2024`, `ASM_CAVEAT_INVALID_SCORE_2025` |
| Imposed issue | `score = 999` |
| Expected rule | Assessment score must be between 250 and 700 |
| Suggested severity | High |
| Expected handling | Exclude from valid assessment metrics; record in quality layer |
| Reporting impact | Show as a caveat in November assessment reporting; do not include invalid scores in average score or proficiency calculations |

## Expected Quality Layer Outputs

Recommended `quality.validation_result` examples:

| Rule ID | Rule name | Expected affected months |
|---|---|---|
| `DQ-C-001` | Missing school reference | `2024-03` |
| `DQ-C-002` | Attended days greater than possible days | `2024-06`, `2025-06` |
| `DQ-C-003` | Duplicate attendance business key | `2024-06`, `2024-08`, `2025-06`, `2025-08` |
| `DQ-C-004` | Orphan attendance student | `2025-09` |
| `DQ-C-005` | Assessment score outside valid range | `2024-11`, `2025-11` |

Recommended `quality.reporting_caveat` outputs:

| Reporting month | Caveat summary |
|---|---|
| `2024-03` | Student delta contains a missing school reference |
| `2024-06` | Attendance data contains invalid attended days and a duplicate business key |
| `2024-08` | Attendance data contains a duplicate business key |
| `2024-11` | Assessment results contain an invalid score |
| `2025-06` | Attendance data contains invalid attended days and a duplicate business key |
| `2025-08` | Attendance data contains a duplicate business key |
| `2025-09` | Attendance data contains an orphan student reference |
| `2025-11` | Assessment results contain an invalid score |

## SQL Handling Status

| Register item | Implemented SQL rule | Expected handling |
|---|---|---|
| Missing school reference | `STU_MISSING_SCHOOL_ID` | Reject student row, create reporting caveat, exclude from silver student tables |
| Invalid attended days | `ATT_INVALID_DAYS` | Reject attendance row, create reporting caveat, exclude from silver attendance |
| Duplicate attendance business key | `ATT_DUPLICATE_BUSINESS_KEY` | Reject duplicate attendance row, create reporting caveat, keep one trusted attendance row |
| Orphan attendance student | `ATT_UNKNOWN_STUDENT` | Reject attendance row, create reporting caveat, exclude from silver attendance |
| Invalid assessment score | `ASM_INVALID_SCORE` | Reject assessment row, create reporting caveat, exclude from silver assessment |

The SQL implementation uses the register above as the expected caveat evidence for Pipeline C. If the synthetic rules change, update this register and the matching SQL quality rules together.

## Validation Evidence

The local story validation chart:

- `images/pipeline_c_monthly_insights/story_validation/data_quality_caveats_by_month.png`

should show caveats in the same months listed in this register.

When SQL is implemented, expected evidence includes:

- row counts from bronze source loads;
- rejected/caveated record counts in quality tables;
- reconciliation between raw, bronze, silver, gold, and reporting views;
- dashboard caveat page screenshots;
- monthly insights brief caveat section.

## Non-Quality Business Change

The generator also includes a planned school closure:

- `SCH050` is closed in `2025-07`.

This is not a data quality issue. It is a legitimate business change that should be handled through normal school-dimension upsert logic and reflected in silver/gold reporting.
