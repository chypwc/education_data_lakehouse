# Power BI Dashboard Test Results

## Purpose

This document records the dashboard validation completed for the Azure Databricks Education QA project. The tests confirm that the Power BI report is consistent with the Databricks reporting views and supports QA evidence for data quality, defect handling, attendance validation, and assessment validation.

## Source Views Tested

- `reporting.vw_data_quality_summary`
- `reporting.vw_data_quality_rule_detail`
- `reporting.vw_defect_log`
- `reporting.vw_attendance_by_school_month`
- `reporting.vw_attendance_by_year_level`
- `reporting.vw_assessment_by_school`
- `reporting.vw_assessment_by_domain`

## Test Results

| Test Area | Test Performed | Expected Result | Actual Result | Status |
|---|---|---:|---:|---|
| Data quality totals | Total rule result rows | 22 | 22 | PASS |
| Data quality totals | Distinct rules tested | 11 | 11 | PASS |
| Data quality totals | Total failed records | 22 | 22 | PASS |
| Data quality totals | Open defects | 12 | 12 | PASS |
| Batch filtering | Batch slicer filters QA, defect, attendance, and assessment pages | Consistent filtering | Consistent filtering | PASS |
| Severity and status filtering | Severity and status slicers filter rule results and defect evidence | Consistent filtering | Consistent filtering | PASS |
| Attendance validation | Attendance rates remain within 0% to 100% | Valid range | Valid range | PASS |
| Attendance validation | Attendance records excluded | 12 | 12 | PASS |
| Attendance validation | School-month reporting rows for Batch 1 | 600 | 600 | PASS |
| Attendance validation | School-month reporting rows for Batch 2 | 576 | 576 | PASS |
| Assessment validation | Assessment scores remain within 250 to 700 | Valid range | Valid range | PASS |
| Assessment validation | Assessment records excluded | 2 | 2 | PASS |
| Assessment validation | Assessment school rows for Batch 1 | 50 | 50 | PASS |
| Assessment validation | Assessment school rows for Batch 2 | 48 | 48 | PASS |
| Assessment validation | Domain and proficiency rows for Batch 1 | 9 | 9 | PASS |
| Assessment validation | Domain and proficiency rows for Batch 2 | 9 | 9 | PASS |
| Accessibility and readability | Dashboard titles, labels, slicers, and status colours reviewed | Clear and consistent | Clear and consistent | PASS |

## Dashboard Pages Validated

- Data Quality Overview
- Rule Failure Details
- Attendance Validation
- Assessment Validation

## Evidence Screenshots

- `powerbi/screenshots/powerbi_data_quality_overview.png`
- `powerbi/screenshots/powerbi_rule_failure_details.png`
- `powerbi/screenshots/powerbi_attendance_validation.png`
- `powerbi/screenshots/powerbi_assessment_validation.png`
- The final Power BI dashboard was refreshed after the Batch 2 incremental Databricks Job run. The screenshots above represent the final two-batch dashboard state.

## Notes

- The report uses Power BI Import mode from Databricks reporting views.
- The Databricks SQL Warehouse was stopped after import to control cost.
- Attendance and assessment reporting views exclude records identified by relevant QA rules before producing trusted reporting outputs.
- PASS and WARN/FAIL status colours were reviewed and adjusted for clearer dashboard interpretation.
- Batch 1 represents 2024 data loaded through `batch_id=2025-01-15`.
- Batch 2 represents 2025 data loaded through `batch_id=2026-01-15`.
