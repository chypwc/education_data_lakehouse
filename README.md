# ACT Education Azure Lakehouse Portfolio

This repository demonstrates three Azure education data pipelines using synthetic school, student, attendance, assessment, and school event data.

The project is best read as one portfolio with three distinct evidence streams:

| Pipeline | Main focus | Portfolio evidence |
|---|---|---|
| Pipeline A: ADF + Synapse Baseline | Azure ingestion and serverless SQL reporting | ADLS, ADF, Synapse serverless SQL, SQL validation, curated reporting views, and baseline Power BI |
| Pipeline B: Databricks QA Lakehouse | QA Analyst delivery | Databricks, Delta Lake, Bronze/Silver/QA/Gold layers, rule checks, rejected records, defect evidence, orchestration, and dashboard testing |
| Pipeline C: Monthly Education Insights | Analytics Officer reporting | Azure SQL Database serverless, monthly merge/upsert processing, Power BI semantic model, stakeholder dashboard pages, data caveats, analysis report, and monthly briefs |

All data is synthetic. It does not represent real ACT Education Directorate schools, students, staff, families, addresses, or outcomes.

## Architecture

The architecture is organised as three related but separate pipelines over the same synthetic education domain. Pipeline A establishes the original Azure ingestion and Synapse reporting baseline. Pipeline B extends the project into a Databricks QA lakehouse, where the main evidence is validation, failed-record handling, defect tracking, and reporting test coverage. Pipeline C adds an Analytics Officer-style reporting path, where monthly data is processed into stakeholder-facing Power BI insights, caveats, and written briefs.

Full architecture notes are in [docs/shared/architecture.md](docs/shared/architecture.md).

| Pipeline | Processing pattern | Reporting output |
|---|---|---|
| Pipeline A | Source files are uploaded to ADLS, copied by ADF, queried through Synapse serverless SQL, validated, and exposed through reporting views. | Baseline Power BI dashboard |
| Pipeline B | ADLS batch files are processed by Databricks Jobs through Bronze, Silver, QA, Gold, and Reporting layers; ADF is used as an enterprise wrapper to trigger the Databricks job from a storage marker file. | QA-focused Power BI dashboard and validation evidence |
| Pipeline C | Monthly `month=YYYY-MM` raw folders trigger ADF, load Azure SQL Bronze tables, merge into Silver, record Quality/Audit evidence, refresh Gold/Reporting outputs, and feed Power BI. | Monthly insights dashboard, overall analysis report, and monthly briefs |

Short pipeline view:

```text
Pipeline A:
synthetic files
-> ADLS raw zone
-> ADF copy pipeline
-> Synapse serverless SQL staging, quality, curated, reporting
-> Power BI baseline dashboard

Pipeline B:
ADLS batch files + _READY marker
-> ADF storage event trigger wrapper
-> Databricks Jobs API
-> Databricks Bronze, Silver, QA, Gold, Reporting layers
-> Power BI QA dashboard and validation evidence

Pipeline C:
monthly raw folders + _READY marker
-> ADF storage event trigger
-> Azure SQL bronze load tables
-> silver merge/upsert tables
-> quality and audit evidence
-> gold dimensions/facts and reporting views
-> Power BI insights dashboard
-> analysis report and monthly briefs
```

## Tools Used

| Tool | Used for |
|---|---|
| Azure Data Lake Storage Gen2 | Raw synthetic file storage and monthly batch folders |
| Azure Data Factory | Pipeline A ingestion, Pipeline B Databricks trigger wrapper, and Pipeline C event-driven monthly orchestration |
| Azure Synapse Analytics serverless SQL | Pipeline A SQL querying, validation, and reporting views |
| Azure Databricks and Delta Lake | Pipeline B lakehouse processing, QA rules, failed-record handling, and Gold/Reporting outputs |
| Azure SQL Database serverless | Pipeline C production-style monthly merge/upsert processing, audit, quality, Gold tables, and reporting views |
| Power BI Desktop | Semantic models, dashboards, validation screenshots, and stakeholder-facing reporting |
| Python | Synthetic data generation, validation plotting, and helper scripts |
| SQL | Data modelling, quality checks, reconciliation, stored procedures, and reporting views |

## Repository Map

```text
adf/                         Pipeline-specific ADF exports and screenshots
data/                        Synthetic generated data and batch folders
databricks_notebooks/        Databricks notebook exports
docs/                        Shared and pipeline-specific documentation
images/                      Azure, Databricks, validation, and evidence screenshots
powerbi/                     Power BI reports, screenshots, and report notes
reports/                     Analysis report outputs
scripts/                     Shared and pipeline-specific helper scripts
sql/                         Pipeline-specific SQL scripts
CHECKLIST.md                 Pipeline C execution and evidence tracker
```

## Key Evidence

### Pipeline A: ADF + Synapse Baseline

- [Pipeline A documentation](docs/pipeline_a_synapse_baseline/)
- [Pipeline A SQL scripts](sql/pipeline_a_synapse_baseline/)
- [Pipeline A Power BI evidence](powerbi/pipeline_a_synapse_baseline/)

### Pipeline B: Databricks QA Lakehouse

- [Databricks QA layer design](docs/pipeline_b_databricks_qa/databricks_qa_layer_design.md)
- [QA test strategy](docs/pipeline_b_databricks_qa/qa_test_strategy.md)
- [Test case matrix](docs/pipeline_b_databricks_qa/test_case_matrix.md)
- [Defect log](docs/pipeline_b_databricks_qa/defect_log.md)
- [UAT plan](docs/pipeline_b_databricks_qa/uat_plan.md)
- [Power BI dashboard test results](docs/pipeline_b_databricks_qa/power_bi_dashboard_test_results.md)
- [Databricks notebook exports](databricks_notebooks/)
- [Pipeline B Power BI evidence](powerbi/pipeline_b_databricks_qa/)

### Pipeline C: Monthly Education Insights

- [Pipeline C documentation index](docs/pipeline_c_monthly_insights/)
- [SQL layer design](docs/pipeline_c_monthly_insights/sql_layer_design.md)
- [ETL design](docs/pipeline_c_monthly_insights/etl_design.md)
- [Dashboard and semantic model design](docs/pipeline_c_monthly_insights/dashboard_semantic_model_design.md)
- [Overall analysis report](docs/pipeline_c_monthly_insights/overall_analysis_report.md)
- [Overall analysis report PDF](reports/pipeline_c_monthly_insights/analysis_report.pdf)
- [Monthly brief: August 2025](docs/pipeline_c_monthly_insights/monthly_insights_brief_2025_08.md)
- [Monthly brief: September 2025](docs/pipeline_c_monthly_insights/monthly_insights_brief_2025_09.md)
- [Monthly brief: October 2025](docs/pipeline_c_monthly_insights/monthly_insights_brief_2025_10.md)
- [Monthly brief: November 2025](docs/pipeline_c_monthly_insights/monthly_insights_brief_2025_11.md)
- [Pipeline C Power BI screenshots](powerbi/pipeline_c_monthly_insights/)
- [Pipeline C SQL scripts](sql/pipeline_c_monthly_insights/)

## Role Alignment

Pipeline B is the strongest ACT Education QA Analyst evidence because it demonstrates test strategy, rule validation, defect handling, failed-record evidence, dashboard validation, UAT planning, traceability, governance, privacy, and accessibility.

Pipeline C extends the same education domain into Analytics Officer evidence. It shows how monthly source data can be turned into stakeholder-ready Power BI pages and written insights about attendance seasonality, Year 7 transition patterns, senior secondary volatility, attendance-to-assessment association, and reporting confidence.

## Limitations

- The data is synthetic and intentionally portfolio-sized.
- Power BI uses import mode for portfolio convenience.
- Production CI/CD, alerting, Key Vault integration, Purview-style catalogue, and formal support runbooks are documented as future hardening areas rather than fully implemented services.
