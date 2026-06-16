# Data Dictionary

## Overview

This project uses synthetic education data only. No real student names, addresses, emails, phone numbers, or personally identifiable information are included.

## Dataset Summary

| Dataset | File | Grain | Description |
|---|---|---|---|
| Schools | `schools.csv` | One row per school | Simulated ACT school reference data |
| Students | `students.csv` | One row per student | Simulated student enrolment records |
| Attendance | `attendance.csv` | One row per student per month | Monthly attendance records |
| Assessment Results | `assessment_results.csv` | One row per student per year per domain | Reading, Numeracy, and Writing results |
| School Events | `school_events.json` | One row per school event | API-style semi-structured school event data |

## `schools.csv`

| Column | Type | Description |
|---|---|---|
| `school_id` | string | Synthetic school identifier |
| `school_name` | string | Simulated school name |
| `region` | string | ACT region |
| `school_type` | string | Primary, High School, College, or Specialist |
| `open_date` | date | Simulated school opening date |
| `status` | string | Active or Closed |

## `students.csv`

| Column | Type | Description |
|---|---|---|
| `student_id` | string | Synthetic student identifier |
| `school_id` | string | School currently associated with the student |
| `year_level` | integer | Student year level, where 0 represents Kindergarten/Foundation |
| `gender` | string | Synthetic gender category |
| `enrolment_date` | date | Simulated enrolment date |
| `status` | string | Active, Transferred, or Left |

## `attendance.csv`

| Column | Type | Description |
|---|---|---|
| `attendance_id` | string | Synthetic attendance record identifier |
| `student_id` | string | Student identifier |
| `school_id` | string | School identifier |
| `attendance_month` | date | First day of the attendance month |
| `possible_days` | integer | Number of possible school attendance days in the month |
| `attended_days` | integer | Number of days attended |
| `absence_reason` | string | Simulated absence reason, blank if no absence |

## `assessment_results.csv`

| Column | Type | Description |
|---|---|---|
| `assessment_id` | string | Synthetic assessment record identifier |
| `student_id` | string | Student identifier |
| `school_id` | string | School identifier |
| `assessment_year` | integer | Assessment year |
| `domain` | string | Reading, Numeracy, or Writing |
| `score` | integer | Simulated assessment score |
| `proficiency_band` | string | Low, Medium, or High |

## `school_events.json`

| Field | Type | Description |
|---|---|---|
| `event_id` | string | Synthetic event identifier |
| `school_id` | string | School identifier |
| `event_type` | string | Attendance campaign, wellbeing program, or assessment intervention |
| `event_date` | date | Simulated event date |
| `description` | string | Synthetic event description |

## Intentional Data Quality Issues

The generated data intentionally includes a small number of bad records so SQL validation checks can be demonstrated.

| Issue | Dataset | Purpose |
|---|---|---|
| Missing `school_id` | `students.csv` | Tests required foreign key validation |
| Missing `student_id` | `students.csv` | Tests required primary key validation |
| Duplicate attendance record | `attendance.csv` | Tests duplicate business grain detection |
| `attended_days > possible_days` | `attendance.csv` | Tests attendance business rule validation |
| Orphan student reference | `attendance.csv` | Tests referential integrity validation |
| Invalid assessment score | `assessment_results.csv` | Tests numeric range validation |

## Privacy Note

All data is synthetic and generated for demonstration purposes only. The dataset does not contain real students, real families, addresses, contact details, or sensitive personal information.
