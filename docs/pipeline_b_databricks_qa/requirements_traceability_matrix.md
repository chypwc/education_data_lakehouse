# Requirements Traceability Matrix

## Purpose

This matrix maps project requirements to implementation evidence and validation outcomes. It supports QA traceability from business need through pipeline implementation, testing, reporting, and evidence.

## Traceability Matrix

| Requirement ID | Requirement | Implementation | Validation Evidence | Status |
|---|---|---|---|---|
| REQ001 | Ingest synthetic education data from ADLS by batch | Raw files partitioned by `batch_id`; Bronze ingestion notebook | Bronze counts and ADLS evidence | Complete |
| REQ002 | Preserve raw lineage and audit metadata | Bronze tables include `source_file_name`, `load_timestamp`, `run_id`, `batch_id`, `bronze_record_id` | Bronze metadata validation | Complete |
| REQ003 | Support initial and incremental loads | `run_mode=initial` overwrites; `run_mode=incremental` deletes/replaces target batch then appends | Repeated Batch 2 rerun count stability | Complete |
| REQ004 | Standardise typed Silver tables | Silver notebook casts dates and numeric fields and trims key fields | Silver schema outputs | Complete |
| REQ005 | Reconcile Bronze to Silver counts | `qa.row_count_reconciliation` by table and batch | All reconciliation rows PASS | Complete |
| REQ006 | Maintain a data quality rule catalog | `qa.dq_rule_catalog` with DQ001-DQ011 | Rule catalog output | Complete |
| REQ007 | Validate required student and school keys | DQ001 and DQ002 | QA validation results and defects | Complete |
| REQ008 | Validate attendance measures and duplicates | DQ003 and DQ004 | QA validation results and failed records | Complete |
| REQ009 | Validate referential integrity | DQ005 and DQ006 | QA validation results | Complete |
| REQ010 | Validate assessment score and proficiency band | DQ007 and DQ008 | QA validation results | Complete |
| REQ011 | Validate school status and future dates | DQ009 and DQ010 | QA validation results | Complete |
| REQ012 | Flag activity linked to inactive or missing schools | DQ011 | WARN result and defect evidence | Complete |
| REQ013 | Capture failed record evidence | `qa.dq_failed_records` stores business key, rule, record JSON, and Bronze record ID | Failed record output | Complete |
| REQ014 | Create defect log for QA issues | `qa.defect_log` and `gold.fact_defect` | Defect counts: Batch 1 = 7, Batch 2 = 5 | Complete |
| REQ015 | Build a production-style Gold model | Gold dimensions and facts for batch, date, school, student, attendance, assessment, DQ, and defects | Gold validation queries | Complete |
| REQ016 | Use reporting views as stable dashboard contracts | `reporting.vw_*` views built from Gold facts/dimensions | Reporting view validation counts | Complete |
| REQ017 | Provide Power BI dashboard for QA and reporting validation | Four dashboard pages for QA overview, rule failures, attendance, and assessment | Power BI screenshots and test results | Complete |
| REQ018 | Validate dashboard filters and calculations | Manual Power BI tests against Databricks reporting views | `docs/pipeline_b_databricks_qa/power_bi_dashboard_test_results.md` | Complete |
| REQ019 | Orchestrate end-to-end pipeline in Databricks | `job_education_qa_pipeline` with five notebook tasks | Databricks Job run screenshots | Complete |
| REQ020 | Demonstrate optional ADF integration wrapper | ADF pipeline triggers Databricks Job through Web activity | ADF pipeline run screenshot | Complete |
| REQ021 | Protect privacy by using synthetic data | Synthetic generated datasets only | Governance checklist | Complete |
| REQ022 | Document governance, accessibility, and cost controls | Close-out documentation and checklist | Governance/accessibility/privacy checklist | Complete |

## Coverage Summary

| Area | Coverage |
|---|---|
| Ingestion QA | Covered |
| Transformation QA | Covered |
| Data quality rules | Covered |
| Defect handling | Covered |
| Gold data model | Covered |
| Reporting validation | Covered |
| UAT support | Covered |
| Governance and privacy | Covered |
| Orchestration evidence | Covered |

## Residual Gaps

The project is portfolio-ready. The following items would be required for a production service:

- Formal CI/CD deployment.
- Automated monitoring and alerting.
- Service support runbook and ownership model.
- Key Vault-backed secret management for all tokens.
- Formal data governance approval.
- Production privacy impact assessment.
