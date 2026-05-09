# Data Quality Rules

## Overview

This project includes SQL-based data quality checks over the Synapse serverless SQL staging views.

The checks are implemented in:

```text
sql/06_data_quality_checks.sql
```

The script creates a reusable validation summary view:

```text
dbo.dq_validation_results
```

Each row in the view represents one validation rule and reports the number of failed records.

## Validation Result Structure

| Column | Description |
|---|---|
| `validation_id` | Unique identifier for the validation rule |
| `check_name` | Human-readable rule name |
| `table_name` | Staging view being checked |
| `failed_record_count` | Number of records that failed the rule |
| `severity` | High, Medium, or Low |
| `run_timestamp` | UTC timestamp when the validation view was queried |

## Implemented Rules

| Rule | Severity | Staging view | Logic | Expected result |
|---|---|---|---|---|
| `DQ001` Missing student ID | High | `stg_students` | `student_id` is null, blank, or spaces only | Fails intentionally inserted bad student row |
| `DQ002` Missing school ID | High | `stg_students` | `school_id` is null, blank, or spaces only | Fails intentionally inserted bad student row |
| `DQ003` Invalid attendance days | High | `stg_attendance` | `possible_days` or `attended_days` is null, negative, or `attended_days > possible_days` | Fails intentionally inserted bad attendance row |
| `DQ004` Duplicate attendance business records | Medium | `stg_attendance` | More than one record for the same `student_id`, `school_id`, and `attendance_month` | Fails rows involved in duplicate business keys |
| `DQ005` Attendance references missing student | High | `stg_attendance` | Attendance `student_id` does not exist in `stg_students` | Fails intentionally inserted orphan attendance row |
| `DQ006` Assessment references missing student | High | `stg_assessment_results` | Assessment `student_id` does not exist in `stg_students` | Expected to pass unless orphan assessments are added |
| `DQ007` Invalid assessment score | High | `stg_assessment_results` | `score` is null, below 250, or above 700 | Fails intentionally inserted score of 999 |
| `DQ008` Invalid proficiency band | Medium | `stg_assessment_results` | `proficiency_band` is not Low, Medium, or High | Expected to pass |
| `DQ009` Invalid school status | Medium | `stg_schools` | `status` is not Active or Closed | Expected to pass |
| `DQ010` Future attendance month | Medium | `stg_attendance` | `attendance_month` is after the current UTC date | Expected to pass |
| `DQ011` Activity linked to inactive school | Low | Multiple staging views | Attendance, assessment, or event records link to a closed school | Review flag, not automatic rejection |

## Rule Design Notes

Missing key checks use:

```sql
NULLIF(TRIM(column_name), '') IS NULL
```

This catches values that are:

- Null.
- Empty strings.
- Strings containing only spaces.

Duplicate attendance is checked at the business grain:

```text
student_id + school_id + attendance_month
```

The duplicate rule counts all rows involved in duplicate groups. For example, if two business keys each appear twice, the failed record count is four.

Referential integrity checks use `LEFT JOIN` and then look for unmatched reference rows:

```sql
LEFT JOIN dbo.stg_students AS s
    ON a.student_id = s.student_id
WHERE s.student_id IS NULL
```

This identifies records that contain a key value but cannot be linked to the reference dataset.

`DQ011` is intentionally low severity. It identifies records linked to closed schools, but the synthetic school data does not include a closure date. Without a closure date, the check cannot determine whether the activity occurred before or after closure, so it should be treated as a review flag.

## Evidence

| Evidence | Location |
|---|---|
| Data quality SQL | `sql/06_data_quality_checks.sql` |
| Validation result screenshot | `images/dq_validation_results.png` |
| Exported validation results | `data/generated/data_validation_results.csv` |

## Production Considerations

For this mini project, `dbo.dq_validation_results` is a view. It recalculates the checks whenever queried.

In a production data platform, validation results would usually be written to a physical audit table with additional fields such as:

- Pipeline run ID.
- Source file name.
- Load batch ID.
- Validation run timestamp.
- Failed record sample or rejected record path.
- Resolution status.
