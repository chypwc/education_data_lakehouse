# SQL Folder Structure

This folder separates SQL artefacts by portfolio pipeline.

| Folder | Purpose |
|---|---|
| `pipeline_a_synapse_baseline/` | Existing ADF + Synapse baseline SQL scripts for external objects, staging, data quality, vault, curated, and reporting views. |
| `pipeline_c_monthly_insights/` | Planned Synapse serverless SQL scripts for the Monthly Education Insights Reporting pipeline. |

Pipeline B uses Databricks notebooks and exported notebook scripts rather than this SQL folder.
