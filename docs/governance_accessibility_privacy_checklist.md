# Governance, Accessibility, and Privacy Checklist

## Purpose

This checklist records governance, accessibility, privacy, and production-readiness considerations for the Azure Databricks Education QA project.

## Privacy

| Check | Result | Notes |
|---|---|---|
| Data is synthetic | PASS | No real student, family, staff, address, contact, or sensitive personal data is used. |
| Student identifiers are synthetic | PASS | IDs such as `STU...` are generated test identifiers. |
| Failed record evidence excludes real PII | PASS | Failed record JSON contains only synthetic project data. |
| Privacy risk is documented | PASS | Production use would require approved privacy-preserving keys. |
| Key-map approach considered | PASS | Production recommendation is to use surrogate keys or approved tokenised identifiers rather than exposing source student IDs. |
| Raw data retention is controlled | REVIEW | This project keeps raw synthetic evidence. Production retention should follow agency records policy. |

## Access Control and Security

| Check | Result | Notes |
|---|---|---|
| ADLS uses Databricks external location | PASS | Databricks access was configured through managed identity and external location. |
| Managed identity used for storage access | PASS | Access connector and IAM roles were configured for ADLS access. |
| Least privilege considered | PASS | Production should narrow access to required users, groups, jobs, and service principals. |
| Personal access token lifetime limited | PASS | A short-lived token was used for the ADF wrapper demonstration. |
| Secrets stored in Key Vault | RECOMMENDED | Production should store Databricks tokens and secrets in Azure Key Vault. |
| SQL Warehouse stopped after import | PASS | SQL Warehouse was stopped after Power BI import to control cost. |
| Public access reviewed | RECOMMENDED | Production should use approved network controls and private endpoints where required. |

## Data Governance

| Check | Result | Notes |
|---|---|---|
| Data lineage is traceable | PASS | Raw -> Bronze -> Silver -> QA -> Gold -> Reporting -> Power BI is documented. |
| Batch lineage is available | PASS | `batch_id` and `run_id` support audit and replay analysis. |
| Failed records are traceable | PASS | Failed records include rule ID, business key, `bronze_record_id`, and record JSON. |
| Business rules are catalogued | PASS | `qa.dq_rule_catalog` and `gold.dim_dq_rule` define DQ001-DQ011. |
| Defect management exists | PASS | `qa.defect_log`, `gold.fact_defect`, and `reporting.vw_defect_log` provide defect evidence. |
| Data contracts are documented | PASS | Bronze, Silver, QA, Gold, and Reporting layer contracts are documented. |
| Production data ownership defined | RECOMMENDED | A production service should define data owners, stewards, and support roles. |

## Accessibility

| Check | Result | Notes |
|---|---|---|
| Dashboard pages have clear titles | PASS | Four pages use clear QA, rule, attendance, and assessment labels. |
| Visual labels are readable | PASS | Titles, slicers, and table headers were reviewed. |
| Colour is not the only indicator | PASS | Status labels such as PASS, FAIL, and WARN are visible alongside colours. |
| Status colours are reviewed | PASS | FAIL and WARN legend colours were adjusted for clearer interpretation. |
| Slicers are keyboard-friendly | PASS | Standard Power BI slicers are used. |
| Tables support detailed review | PASS | Rule and defect tables provide text evidence, not only chart summaries. |
| Formal WCAG review completed | RECOMMENDED | A production dashboard should receive formal accessibility testing. |

## Cost Control

| Check | Result | Notes |
|---|---|---|
| Serverless or small compute used | PASS | Compute was kept small for portfolio development. |
| SQL Warehouse stopped after import | PASS | Prevents unnecessary ongoing charges. |
| Clusters not left running | PASS | Cost-control note included in project plan. |
| ADF trigger scope limited | PASS | Trigger uses `raw/_triggers/` and `_READY.json` marker files to avoid broad event matching. |
| Resource cleanup documented | RECOMMENDED | Final project close-out should include delete/stop guidance for Azure resources. |

## Production Hardening Checklist

Recommended before production:

- Replace personal tokens with service principal or managed identity where supported.
- Store secrets in Azure Key Vault.
- Add monitoring and alerts for failed Databricks Jobs, ADF failures, and DQ rule breaches.
- Add release pipelines for notebooks, SQL, Power BI, and infrastructure.
- Add row-level or object-level security if users should see only approved subsets.
- Add data retention and archival rules for raw, quarantine, QA, and defect evidence.
- Add formal privacy, security, and accessibility reviews.
- Add operational runbooks for reruns, incident handling, and defect closure.

## Outcome

The project is suitable as a portfolio demonstration of governance-aware QA practice. It uses synthetic data, controlled access patterns, clear lineage, validated reporting views, and dashboard accessibility checks. Production use would require formal operational, security, privacy, and accessibility approvals.
