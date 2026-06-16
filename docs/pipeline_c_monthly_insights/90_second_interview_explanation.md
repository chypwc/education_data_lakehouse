# Pipeline C Interview Explanation

## Purpose

Use this as a 90-second interview answer for explaining Pipeline C as an Analytics Officer portfolio example. The focus should be on analytics storytelling, monthly reporting, dashboard interpretation, and stakeholder communication rather than the technical build alone.

## 90-Second Explanation

Pipeline C extends my education data lakehouse from data engineering and QA into monthly analytics reporting. Pipelines A and B show that I can build ingestion, transformation, validation, and quality evidence. Pipeline C adds the stakeholder-facing layer: it turns monthly education data into Power BI insights, caveats, and written reporting.

The scenario is an education attendance and assessment reporting process. I designed the synthetic data as a January 2024 initial snapshot followed by monthly change batches from February 2024 to December 2025. The data was intentionally shaped to support an analytics story: attendance declines in winter, Year 7 students show a transition pattern, senior secondary students show more attendance volatility, and assessment scores are associated with attendance bands.

The reporting process uses Azure SQL Database serverless with modern SQL layers: Bronze for source-shaped loaded records, Silver for cleaned and merged monthly data, Quality and Audit for validation evidence, Gold for analytics-ready facts and dimensions, and Reporting views for Power BI. Azure Data Factory triggers the monthly process when a `_READY.json` file is uploaded for a reporting month.

The final output is a Power BI dashboard with five pages: Monthly Overview, Attendance Seasonality, Year-Level Patterns, Attendance And Assessment, and Data Confidence. I also wrote an overall analysis report and monthly insights briefs. Together, these outputs answer the questions a non-technical stakeholder would ask: what changed this month, which cohorts or schools need attention, and how confident should we be in the data?

## Shorter Version

Pipeline C is the analytics reporting extension of the project. It uses monthly education data to tell a stakeholder-facing story about attendance seasonality, Year 7 transition patterns, senior secondary attendance risk, and the association between attendance and assessment outcomes. The technical pipeline supports that story with Azure SQL Database serverless, ADF orchestration, quality caveats, Gold reporting tables, and a Power BI semantic model. The main evidence is the dashboard, the overall analysis report, and the monthly insights briefs.

## Evidence To Mention

- Monthly data design: January 2024 initial snapshot, then February 2024 to December 2025 monthly change batches.
- Production-style flow: raw files in ADLS, ADF trigger, Azure SQL Bronze/Silver/Quality/Audit/Gold/Reporting layers.
- Dashboard pages: Monthly Overview, Attendance Seasonality, Year-Level Patterns, Attendance And Assessment, Data Confidence.
- Analysis outputs: overall analysis report plus monthly briefs for August to November 2025.
- Quality story: caveats and rejected records are visible to dashboard users rather than hidden inside the pipeline.

## Follow-Up Talking Points

### Why this fits an Analytics Officer role

The project goes beyond moving data. It frames business questions, designs reporting outputs, explains trends, and translates caveats into stakeholder-friendly findings and actions.

### Why synthetic data was shaped intentionally

The synthetic data was designed to make analytics behaviour testable. It includes realistic seasonality, cohort patterns, assessment relationships, and controlled data quality issues so the dashboard can demonstrate both insight and reporting confidence.

### How this differs from Pipelines A and B

Pipelines A and B mainly demonstrate engineering, QA, validation, and lakehouse capability. Pipeline C demonstrates monthly reporting, semantic modelling, dashboard design, written analysis, and stakeholder communication.

### What I would improve next

I would add stronger operational monitoring, automated link/evidence checks, a clearer Power BI model documentation screenshot, and a small deployment guide covering cost control, refresh scheduling, and access management.
