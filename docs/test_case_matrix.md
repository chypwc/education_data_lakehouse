# Test Case Matrix

## Purpose

This matrix records the main test cases used to validate the Azure Databricks Education QA project. It links the pipeline layer, expected result, evidence, and status.

## Test Cases

| Test ID | Area | Test Objective | Expected Result | Evidence | Status |
|---|---|---|---|---|---|
| TC001 | Azure foundation | Confirm ADLS Gen2 storage, Databricks workspace, schemas, and external location are configured | Resources are available and Databricks can list ADLS paths | Azure and Databricks setup screenshots | PASS |
| TC002 | Raw data | Confirm Batch 1 and Batch 2 files are uploaded to batch-specific folders | All five source datasets exist for both batches | ADLS file listing | PASS |
| TC003 | Bronze ingestion | Confirm Bronze tables contain audit metadata | `batch_id`, `run_id`, `load_timestamp`, `source_file_name`, and `bronze_record_id` populated | Bronze metadata validation | PASS |
| TC004 | Bronze counts | Confirm Bronze row counts match expected batch scale | Schools 50/51, students 10002/10502, attendance 120003/96939, assessments 30001/24235, events 146/135 | Bronze counts screenshot | PASS |
| TC005 | Incremental idempotency | Rerun Batch 2 incremental ingestion without duplicating rows | Counts remain stable after rerun | Bronze and Silver count checks | PASS |
| TC006 | Silver typing | Confirm Silver applies standard data types | Dates, integers, strings, and audit columns are typed consistently | Silver schemas | PASS |
| TC007 | Silver reconciliation | Reconcile Bronze to Silver by table and batch | All table/batch combinations return `PASS` | `qa.row_count_reconciliation` | PASS |
| TC008 | DQ001 | Detect missing student ID | Batch 1 fails 1 record; Batch 2 passes | `qa.dq_validation_results` | PASS |
| TC009 | DQ002 | Detect missing school ID on student records | Batch 1 fails 1 record; Batch 2 fails 1 record | `qa.dq_validation_results` | PASS |
| TC010 | DQ003 | Detect invalid attendance days | Batch 1 fails 1 record; Batch 2 fails 1 record | `qa.dq_validation_results` | PASS |
| TC011 | DQ004 | Detect duplicate attendance business records | Batch 1 fails 4 records; Batch 2 fails 4 records | `qa.dq_validation_results` | PASS |
| TC012 | DQ005 | Detect attendance records with missing student references | Batch 1 fails 1 record; Batch 2 fails 1 record | `qa.dq_validation_results` | PASS |
| TC013 | DQ006 | Detect assessment records with missing student references | Both batches pass | `qa.dq_validation_results` | PASS |
| TC014 | DQ007 | Detect invalid assessment scores | Batch 1 fails 1 record; Batch 2 fails 1 record | `qa.dq_validation_results` | PASS |
| TC015 | DQ008 | Detect invalid proficiency bands | Both batches pass | `qa.dq_validation_results` | PASS |
| TC016 | DQ009 | Detect invalid school status values | Both batches pass | `qa.dq_validation_results` | PASS |
| TC017 | DQ010 | Detect future attendance months | Both batches pass | `qa.dq_validation_results` | PASS |
| TC018 | DQ011 | Flag school events linked to inactive or missing schools | Batch 1 warns 5 records; Batch 2 passes | `qa.dq_validation_results` | PASS |
| TC019 | Failed record evidence | Confirm failed records are traceable to business key and Bronze record | Failed records include rule, batch, business key, source JSON, and `bronze_record_id` | `qa.dq_failed_records` | PASS |
| TC020 | Defect logging | Confirm failed and warning rules generate defect records | Batch 1 has 7 defects; Batch 2 has 5 defects | `gold.fact_defect`, `reporting.vw_defect_log` | PASS |
| TC021 | Gold dimensions | Confirm shared dimensions build successfully | Batch, date, school, student, year level, domain, proficiency band, and DQ rule dimensions created | Gold dimension validation | PASS |
| TC022 | Gold attendance fact | Confirm invalid attendance records are excluded from trusted fact | Batch 1 has 119998 rows; Batch 2 has 96934 rows; no missing school/student keys | `gold.fact_attendance` validation | PASS |
| TC023 | Gold assessment fact | Confirm invalid assessment records are excluded from trusted fact | Batch 1 has 30000 rows; Batch 2 has 24234 rows; no missing dimension keys | `gold.fact_assessment_result` validation | PASS |
| TC024 | Gold QA facts | Confirm latest QA run per batch is represented in Gold | 11 DQ result rows per batch; defect counts 7/5 | `gold.fact_data_quality_result`, `gold.fact_defect` | PASS |
| TC025 | Reporting views | Confirm reporting views return expected row counts | All reporting views match expected batch counts | Reporting view validation query | PASS |
| TC026 | Power BI totals | Confirm dashboard totals match reporting views | 22 rule results, 11 distinct rules, 22 failed records, 12 open defects | `docs/power_bi_dashboard_test_results.md` | PASS |
| TC027 | Power BI slicers | Confirm batch, severity, status, region, school type, year level, and domain slicers work | Slicers filter related visuals consistently | Power BI manual test | PASS |
| TC028 | Attendance dashboard | Confirm attendance metrics remain within valid range | Attendance rate stays between 0% and 100%; excluded record count is 12 | Attendance dashboard | PASS |
| TC029 | Assessment dashboard | Confirm assessment metrics remain within valid range | Scores remain 250 to 700; excluded record count is 2 | Assessment dashboard | PASS |
| TC030 | Databricks Job | Confirm end-to-end Databricks Job execution | All five tasks succeed | Job run screenshots | PASS |
| TC031 | ADF wrapper | Confirm ADF can trigger the Databricks Job | ADF Web activity succeeds | ADF pipeline run screenshot | PASS |

## Summary

All core functional, data quality, reconciliation, reporting, and orchestration tests passed for the project evidence set.
