# Power BI Report Notes

## Purpose

This folder contains Power BI evidence for the education lakehouse portfolio. Power BI artefacts are grouped by pipeline so the baseline dashboard, QA dashboard, and planned monthly insights dashboard stay separate.

## Data Disclaimer

All data in this report is synthetic. School, student, attendance, assessment, and event records were generated for portfolio demonstration purposes only. The results do not represent real ACT Education Directorate schools, students, or outcomes.

## Data Source

Pipeline A imports data from Synapse serverless SQL reporting views:

- `vw_attendance_by_school`
- `vw_attendance_by_year_level`
- `vw_assessment_by_school`
- `vw_assessment_by_domain`
- `vw_data_quality_summary`

## Report Pages

Pipeline A baseline dashboard:

- Attendance Overview
- Attendance Details
- Assessment Overview
- Assessment Details
- Data Quality Monitor

Pipeline B QA dashboard:

- Data Quality Overview
- Rule Failure Details
- Attendance Validation
- Assessment Validation

Pipeline C monthly insights dashboard is planned and will focus on stakeholder-facing monthly reporting, a Power BI semantic model, data quality caveats, and a short insights brief.

## Artefact Locations

| Pipeline | Report | Screenshots |
|---|---|---|
| Pipeline A | `powerbi/pipeline_a_synapse_baseline/lakehouse_dashboard.pbix` | `powerbi/pipeline_a_synapse_baseline/screenshots/` |
| Pipeline B | `powerbi/pipeline_b_databricks_qa/QA_dashboard.pbix` | `powerbi/pipeline_b_databricks_qa/screenshots/` |
| Pipeline C | Planned | `powerbi/pipeline_c_monthly_insights/` |

## Notes

The dashboards are designed to demonstrate Power BI readiness, curated reporting views, data quality visibility, and stakeholder communication. They are not intended for real operational analysis.
