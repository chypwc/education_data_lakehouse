# Interview Notes

## Short Project Explanation

I built this project to bridge my existing SQL, analytics, Power BI, and cloud data engineering experience into the Azure stack used in the ACT data engineer role.

The project simulates an education data platform for school, student, attendance, assessment, and school event data. I generated synthetic data, loaded it into Azure Data Lake Storage Gen2, used Azure Data Factory to copy raw files into a staging zone, and used Synapse serverless SQL to validate, model, and expose the data for reporting.

The final output includes materialised Parquet layers in ADLS, SQL reporting views, and a Power BI dashboard covering attendance, assessment, and data quality.

## Why This Project

The role mentions Azure Data Factory, Synapse, SQL development, data quality, ELT, Data Vault, dimensional modelling, and Power BI-style reporting. My previous experience was stronger in SQL, analytics, Power BI, and AWS-oriented data engineering, so I created a focused Azure project to show that the core concepts transfer quickly.

## Architecture Talking Point

The implemented flow is:

```text
Synthetic files
-> ADLS Gen2 raw zone
-> ADF raw-to-staging copy pipeline
-> Synapse staging views
-> SQL data quality checks
-> materialised Data Vault-style Parquet layer
-> materialised curated dimensional Parquet layer
-> Synapse reporting views
-> Power BI dashboard
```

I used Synapse serverless SQL with a Managed Identity-backed external data source so that SQL objects could read and write lake files securely through the Synapse workspace identity.

## Data Quality Talking Point

I intentionally injected bad records into the synthetic data so the project could demonstrate realistic validation checks. The checks include:

- Missing `student_id`
- Missing `school_id`
- Duplicate attendance business records
- Invalid attendance values where attended days exceed possible days
- Attendance records referencing a missing student
- Invalid assessment scores
- Invalid categorical values
- Future attendance dates

The validation output is exposed as a SQL view and also materialised to the lake as Parquet.

## Modelling Talking Point

I included a lightweight Data Vault-style layer to demonstrate awareness of hubs, links, and satellites. It is not intended to be a full enterprise Data Vault implementation. The main purpose is to show that I understand how to separate business keys, relationships, and descriptive attributes.

The curated layer then converts the data into a dimensional model with dimensions and facts suitable for reporting.

## Power BI Talking Point

The Power BI report connects to Synapse serverless SQL reporting views rather than raw files. This keeps the report layer simple and lets SQL handle the business logic.

The report includes:

- Attendance overview and detail pages
- Assessment overview and detail pages
- Data quality monitor

The dashboard is based on synthetic data, so the results are demonstration-only and should not be interpreted as real school performance.

## Honest Tradeoffs

- I uploaded the original synthetic files to the raw zone using Azure CLI, then used ADF for the raw-to-staging ingestion pipeline.
- The project is batch-based and intentionally small.
- The security model is simplified, but I did use Managed Identity for Synapse-to-ADLS access.
- The Power BI report uses imported SQL reporting views, not a full semantic model over every fact and dimension table.
- The Data Vault layer is lightweight and educational, not a production-grade enterprise vault.

## Resume Bullets

- Built an Azure education lakehouse mini project using ADLS Gen2, Azure Data Factory, Synapse serverless SQL, and Power BI to ingest, validate, model, and report on synthetic school, student, attendance, assessment, and event data.

- Created SQL-based staging, data quality, lightweight Data Vault, curated dimensional, and reporting layers, materialising quality, vault, and curated outputs as Parquet files in ADLS Gen2.

- Implemented data quality checks for missing keys, duplicate attendance records, invalid attendance values, orphan records, and invalid assessment scores, then surfaced the results through Synapse reporting views and a Power BI data quality monitor.

## Interview Answer: Why Azure?

I wanted to show that although my prior cloud data engineering experience was more AWS-oriented, the underlying data engineering concepts are transferable. This project helped me practise Azure-specific services, especially Data Factory, ADLS Gen2, Synapse serverless SQL, Managed Identity access, and Power BI integration.

## Interview Answer: What Would You Improve Next?

I would add metadata-driven ingestion, incremental loading, automated ADF triggers, CI/CD, monitoring, and more formal governance documentation. I would also expand the Power BI model with row-level security if the report were used for real education reporting.
