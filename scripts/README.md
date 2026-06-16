# Scripts Folder Structure

Scripts are grouped by pipeline or shared use.

| Folder | Purpose |
|---|---|
| `shared/` | Synthetic data generation scripts used by the existing portfolio data batches. |
| `pipeline_a_synapse_baseline/` | Reserved for future Pipeline A helper scripts, if needed. |
| `pipeline_b_databricks_qa/` | Script-format exports of Databricks notebooks and other Pipeline B helpers. |
| `pipeline_c_monthly_insights/` | Reserved for future Pipeline C analytics-story data generation and validation scripts. |

The canonical Databricks notebook exports remain in the top-level `databricks_notebooks/` folder because only Pipeline B uses Databricks notebooks.
