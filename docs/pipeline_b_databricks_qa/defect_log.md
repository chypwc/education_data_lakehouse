# Defect Log

## Purpose

This document summarises defects detected by the Databricks QA layer. The source of truth is the project QA and Gold tables:

- `qa.dq_validation_results`
- `qa.dq_failed_records`
- `qa.defect_log`
- `gold.fact_data_quality_result`
- `gold.fact_defect`
- `reporting.vw_defect_log`

## Defect Summary

| Batch | Data Period | Defect Count | Failed or Warning Records | Open Defects |
|---|---:|---:|---:|---:|
| Batch 1 - 2024 data | 2024 | 7 | 14 | 7 |
| Batch 2 - 2025 data | 2025 | 5 | 8 | 5 |
| Total | 2024-2025 | 12 | 22 | 12 |

## Defects by Rule

| Rule ID | Rule Name | Severity | Batch 1 Failed Records | Batch 2 Failed Records | Status | Recommended Action |
|---|---|---|---:|---:|---|---|
| DQ001 | Missing student ID | High | 1 | 0 | Open | Investigate source student extract and require `student_id` for all student records. |
| DQ002 | Missing school ID | High | 1 | 1 | Open | Investigate student enrolment extract and require a valid `school_id` for each student. |
| DQ003 | Invalid attendance days | High | 1 | 1 | Open | Enforce valid `possible_days` and `attended_days` before publishing. |
| DQ004 | Duplicate attendance business record | Medium | 4 | 4 | Open | Deduplicate monthly attendance records by student, school, and month. |
| DQ005 | Attendance references missing student | High | 1 | 1 | Open | Correct source-system referential integrity for attendance student references. |
| DQ007 | Invalid assessment score | High | 1 | 1 | Open | Review assessment scoring scale and confirm invalid score handling. |
| DQ011 | School event linked to inactive or missing school | Low | 5 | 0 | Open | Review whether events should be linked only to active schools. |

## Defects by Severity

| Batch | High Failed Records | Medium Failed Records | Low Warning Records |
|---|---:|---:|---:|
| Batch 1 - 2024 data | 5 | 4 | 5 |
| Batch 2 - 2025 data | 4 | 4 | 0 |

## Handling Notes

- High-severity defects should block trusted reporting for affected records.
- Medium-severity defects should be reviewed and remediated before operational reporting sign-off.
- Low-severity warnings should be triaged with a business owner because they may represent valid historical activity.
- The Gold attendance and assessment facts exclude records failed by relevant blocking QA rules.
- Defect records remain open in this project to demonstrate evidence capture and triage workflow.

## Production Recommendation

In production, defects should move through a managed lifecycle:

```text
Open -> Triaged -> Assigned -> Fixed -> Retested -> Closed
```

Each defect should include an owner, target resolution date, source-system reference, retest evidence, and closure approval.
