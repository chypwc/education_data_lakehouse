# UAT Plan

## Purpose

This UAT plan defines how business users or project reviewers can validate that the Education QA lakehouse and Power BI dashboard meet the expected quality assurance outcomes.

## UAT Objectives

- Confirm the dashboard communicates data quality status clearly.
- Confirm failed and warning rules are traceable to defects and recommended actions.
- Confirm attendance and assessment reporting excludes invalid records consistently.
- Confirm Batch 1 and Batch 2 filtering supports initial and incremental comparison.
- Confirm the evidence is suitable for a QA Analyst portfolio demonstration.

## UAT Roles

| Role | Responsibility |
|---|---|
| Data QA Analyst | Prepare UAT evidence, explain rule outcomes, record issues |
| Business Reviewer | Validate dashboard meaning, labels, and business usefulness |
| Data Engineer | Support pipeline reruns and technical defect investigation |
| Report Developer | Validate Power BI visuals, slicers, and formatting |

## UAT Environment

| Component | Environment |
|---|---|
| Storage | Azure Data Lake Storage Gen2 |
| Processing | Azure Databricks |
| Orchestration | Databricks Job with optional Azure Data Factory wrapper |
| Reporting | Power BI Desktop using Databricks reporting views |
| Data | Synthetic education data only |

## UAT Scenarios

| UAT ID | Scenario | Expected Result | Status |
|---|---|---|---|
| UAT001 | Open the Data Quality Overview page | User can see total rules tested, failed records, issue rules, and open defects | PASS |
| UAT002 | Filter dashboard by Batch 1 | QA, defect, attendance, and assessment visuals show only Batch 1 data | PASS |
| UAT003 | Filter dashboard by Batch 2 | QA, defect, attendance, and assessment visuals show only Batch 2 data | PASS |
| UAT004 | Filter by severity and status | Rule and defect visuals respond consistently | PASS |
| UAT005 | Review Rule Failure Details | User can see failed rules, defect status, failed count, and recommended action | PASS |
| UAT006 | Review Attendance Validation | User can identify attendance trends, excluded records, and lowest attendance schools | PASS |
| UAT007 | Review Assessment Validation | User can compare domain scores, proficiency bands, and school assessment outcomes | PASS |
| UAT008 | Confirm dashboard totals against Databricks views | Dashboard totals match reporting view validation | PASS |
| UAT009 | Confirm visual readability | Titles, labels, colours, and slicers are understandable | PASS |
| UAT010 | Confirm pipeline evidence | Databricks Job and ADF wrapper screenshots prove repeatable execution | PASS |

## Acceptance Criteria

UAT is accepted when:

- Dashboard totals match validated Databricks reporting views.
- All slicers filter the expected visuals.
- Failed and warning records are explainable through rule details and defect evidence.
- Attendance and assessment metrics use trusted records after QA exclusions.
- The dashboard is readable and suitable for non-technical review.
- Evidence screenshots and documentation are saved.

## Issue Triage

If a reviewer identifies an issue:

1. Record the page, visual, filter state, and observed result.
2. Compare the Power BI value with the corresponding Databricks reporting view.
3. Classify as data issue, transformation issue, dashboard issue, or documentation issue.
4. Add the item to the defect log or project notes.
5. Retest after correction.

## Sign-Off Template

| Item | Response |
|---|---|
| Reviewer name |  |
| Review date |  |
| Dashboard version |  |
| Databricks batch IDs reviewed | `2025-01-15`, `2026-01-15` |
| Accepted for portfolio evidence | Yes / No |
| Open concerns |  |
| Sign-off comments |  |

## UAT Outcome

The UAT-style validation completed for this project passed. The dashboard was refreshed after the Batch 2 incremental run and validated against the Databricks reporting views.
