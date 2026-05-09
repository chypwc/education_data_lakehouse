# Power BI Report Notes

## Purpose

This Power BI report demonstrates how curated education data from the Azure lakehouse can be presented for attendance, assessment, and data quality monitoring.

## Data Disclaimer

All data in this report is synthetic. School, student, attendance, assessment, and event records were generated for portfolio demonstration purposes only. The results do not represent real ACT Education Directorate schools, students, or outcomes.

## Data Source

The report imports data from Synapse serverless SQL reporting views:

- `vw_attendance_by_school`
- `vw_attendance_by_year_level`
- `vw_assessment_by_school`
- `vw_assessment_by_domain`
- `vw_data_quality_summary`

## Report Pages

- Attendance Overview
- Attendance Details
- Assessment Overview
- Assessment Details
- Data Quality Monitor

## Notes

The dashboard is designed to demonstrate Power BI readiness, curated SQL reporting views, and data quality visibility. It is not intended for real operational analysis.
