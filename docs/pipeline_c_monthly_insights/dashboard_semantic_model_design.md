# Pipeline C Dashboard And Semantic Model Design

## Purpose

This document defines the Power BI semantic model and stakeholder dashboard design for Pipeline C: Monthly Education Insights Reporting.

It should be used after the Azure SQL reporting views are designed and before the Power BI file is built. The aim is to make sure the dashboard answers stakeholder questions, not just displays raw tables.

Related documents:

- [SQL layer design](sql_layer_design.md)
- [ETL design](etl_design.md)
- [Synthetic quality issue register](synthetic_quality_issue_register.md)

## Design Scope

Power BI uses Azure SQL `gold` tables as the primary semantic model because slicers, relationships, and reusable DAX measures are easier to manage with a star-schema-style model.

Power BI may also use selected Azure SQL `reporting` views where a view provides a stable business-facing output that is awkward to recreate in DAX, such as monthly reporting readiness.

Power BI should not connect directly to:

- raw files;
- bronze tables;
- silver tables;
- internal audit tables;
- student-level validation tables.

The dashboard is stakeholder-facing and aggregate by default. It should not expose `student_id` or `student_key`.

## Business Audience

Primary audience:

- education reporting stakeholders;
- school operations or performance monitoring stakeholders;
- analytics reviewers assessing the project as a portfolio example.

The dashboard should help answer:

```text
What changed this month, which cohorts or schools need attention, and how confident are we in the data?
```

## Semantic Model Inputs

Implemented Power BI inputs:

| Table or view | Purpose in Power BI |
|---|---|
| `gold.dim_month` | Reporting month, year, calendar month, chronological sorting, and time slicers |
| `gold.dim_school` | Region, school, and school context slicers |
| `gold.dim_year_level` | Year-level labels, cohort groups, and year-level sort order |
| `gold.dim_attendance_band` | Attendance band labels and distribution visuals |
| `gold.dim_assessment_domain` | Assessment domain filtering for the assessment page |
| `gold.fact_attendance_monthly` | Attendance measures, trends, year-level patterns, cohort tracking, and at-risk attendance share |
| `gold.fact_student_snapshot` | Monthly student snapshot measures |
| `gold.fact_assessment_result` | Attendance and assessment relationship analysis |
| `gold.fact_data_quality_caveat` | Caveat counts and quality confidence visuals |
| `reporting.vw_monthly_reporting_readiness` | Monthly readiness status text and reporting confidence context |

Reporting views remain useful as SQL validation and stable reporting outputs, but the dashboard visuals built so far use the Gold star model for most slicers and measures.

## Semantic Model Principles

- Use a simple star-style model where practical.
- Use Gold dimensions and facts as the Power BI semantic model.
- Use reporting views selectively for stable readiness or validation-style outputs.
- Keep field names business-friendly.
- Hide technical fields, keys, audit IDs, load timestamps, and source file names unless needed for a technical evidence page.
- Avoid student-level identifiers.
- Prefer measures over calculated columns for KPIs and movement.
- Make slicers consistent across pages.
- Use caveat/readiness measures to prevent overclaiming.

## Relationship Design

The implemented model uses dimension-to-fact relationships:

| Dimension | Fact relationship intent |
|---|---|
| `gold.dim_month` | Filters monthly attendance, student snapshot, assessment, and caveat facts by reporting period |
| `gold.dim_school` | Filters attendance, student snapshot, assessment, and caveat facts by school and region |
| `gold.dim_year_level` | Filters attendance, student snapshot, and assessment facts by year level or cohort group |
| `gold.dim_attendance_band` | Filters attendance and attendance-to-assessment outputs by attendance band |
| `gold.dim_assessment_domain` | Filters assessment outputs by assessment domain |

Recommended relationship behaviour:

- use single-direction filters from dimension to fact where possible;
- avoid many-to-many relationships unless unavoidable;
- avoid bidirectional filters that create ambiguous paths between dimensions and multiple fact tables;
- use a month sort column so month labels display chronologically.

Implementation note:

The dashboard initially showed ambiguous relationship and inactive relationship issues. The model was corrected by using star-schema relationships from dimensions to facts, avoiding unnecessary bidirectional filters, and using the active `dim_year_level` to `fact_attendance_monthly` relationship for year-level visuals.

## Core Measures

Implemented core measures:

| Measure | Purpose |
|---|---|
| `Attendance Rate` | Main attendance KPI |
| `Prior Month Attendance Rate` | Previous month comparison |
| `Attendance Rate Change` | Current month minus prior month |
| `Student Count` | Monthly student population KPI |
| `Caveat Count` | Number of quality caveats for the selected context |
| `Reporting Readiness Status` | Ready, Ready with caveats, or Not ready |
| `Winter Attendance Rate` | Attendance rate for June, July, and August |
| `Non-Winter Attendance Rate` | Attendance rate outside June, July, and August |
| `Winter Gap` | Winter attendance rate minus non-winter attendance rate |
| `Year 7 Attendance Rate` | Year 7 attendance KPI |
| `Year 8-10 Attendance Rate` | Years 8 to 10 attendance KPI |
| `Senior Attendance Rate` | Years 11 and 12 attendance KPI |
| `Students With Attendance` | Distinct students with attendance in the selected context |
| `Attendance Student-Month Count` | Count of monthly attendance records at student-month grain |
| `At-Risk Student-Month Count` | Count of student-month records below the high-concern threshold |
| `At-Risk Student-Month Share` | Share of student-month records below the high-concern threshold |
| `Cohort Attendance Rate` | Attendance rate for selected starting cohorts |

Measures planned for the assessment page:

| Measure | Purpose |
|---|---|
| `Average Assessment Score` | Main assessment KPI |
| `Assessment Score Gap` | Difference between high and low attendance bands |
| `Assessment Record Count` | Assessment record volume for selected filters |

Optional measures:

| Measure | Purpose |
|---|---|
| `Attendance Rate YoY Change` | Compare same month across years |
| `Senior Volatility Indicator` | Highlight senior secondary month-to-month movement |

## Page 1: Monthly Overview

Business question:

```text
What changed this month?
```

Implemented visuals:

- KPI cards:
  - Selected reporting month
  - Attendance Rate
  - Prior Month Attendance Rate
  - Attendance Rate Change
  - Student Count
  - Caveat Count
  - Reporting Readiness Status
- Attendance Trend Line:
  - attendance rate across available reporting months
  - not restricted to a single selected month, so users can see trend context
- Attendance Rate by Year Level:
  - selected-month year-level comparison
- Attendance Rate by Region:
  - selected-month regional comparison
- Caveat table:
  - caveat code, severity, affected area, reporting month, and failed record count

Implemented slicers:

- year;
- month.

Expected takeaway:

Stakeholders can quickly see whether the selected month improved or declined, whether any cohort needs attention, and whether the data is ready for review.

Evidence:

- `powerbi/pipeline_c_monthly_insights/01_monthly_overview.png`

## Page 2: Attendance Seasonality

Business question:

```text
Is attendance following a seasonal pattern?
```

Implemented visuals:

- KPI cards:
  - Attendance Rate
  - Winter Attendance Rate
  - Non-Winter Attendance Rate
  - Winter Gap
- Winter Dip by Region:
  - region-level winter gap ranking
- Seasonal Pattern by Month:
  - attendance rate by calendar month and cohort group
- Monthly Attendance Trend:
  - reporting-month trend across 2024 and 2025
- Month x Year Level Heatmap:
  - attendance rate by month and year level

Implemented slicers:

- year;
- region;
- cohort.

Expected takeaway:

The winter attendance decline is visible and explainable, without requiring the user to inspect raw attendance rows.

Evidence:

- `powerbi/pipeline_c_monthly_insights/02_attendance_seasonality.png`

## Page 3: Year-Level Patterns

Business question:

```text
Which cohorts need closer monitoring?
```

Implemented visuals:

- KPI cards:
  - Attendance Rate
  - Year 7 Attendance Rate
  - Year 8-10 Attendance Rate
  - Senior Attendance Rate
- Share of Student-Months Below 80% Attendance:
  - bar chart showing the percentage of monthly attendance records below the high-concern threshold by year level
- Attendance Band Distribution by Year Level:
  - stacked bar chart showing low, medium, and high attendance band counts by year level
- Attendance Trend by Starting Cohort:
  - line chart tracking students grouped by their year level in February 2024
- Year 7 Transition Compared With Years 8-10:
  - line chart comparing Year 7 transition attendance with Years 8-10

Implemented slicers:

- year;
- month;
- region;
- cohort.

Expected takeaway:

Year 7 transition and senior secondary attendance risk are visible, and the cohort trend shows how selected starting cohorts move over time rather than only comparing current year-level averages.

Evidence:

- `powerbi/pipeline_c_monthly_insights/03_year_level_patterns.png`

## Page 4: Attendance And Assessment

Business question:

```text
How do attendance bands relate to assessment outcomes?
```

Implemented visuals:

- KPI cards:
  - Average Assessment Score
  - Assessment Record Count
  - High Attendance Avg Score
  - Low Attendance Avg Score
  - High-Low Score Gap
- Assessment Score by Attendance Band:
  - bar chart showing average assessment score by attendance band
- Assessment Score by Year Level and Attendance Band:
  - point/line-style comparison showing score differences by year level and attendance band
- Assessment Score by Domain and Attendance Band:
  - clustered bar chart comparing Reading, Numeracy, and Writing by attendance band
- High-Low Score Gap by Domain:
  - bar chart showing the score gap between high-attendance and low-attendance groups by domain

Implemented slicers:

- assessment year;
- year level;
- region.

Expected takeaway:

Higher attendance bands are associated with stronger assessment outcomes across domains, while the page avoids claiming causation.

Evidence:

- `powerbi/pipeline_c_monthly_insights/04_attendance_assessment.png`

## Page 5: Data Confidence

Business question:

```text
How confident should users be in this month's figures?
```

Implemented visuals:

- KPI cards:
  - Rejected Record Count
  - Warning Caveats
  - Error Caveats
  - Blocker Caveats
  - Reporting Readiness
- Caveats by Reporting Month and Severity:
  - stacked column chart showing caveat counts over time
- Caveats by Affected Area:
  - stacked bar chart showing caveat counts by affected business area
- Readiness by Reporting Month:
  - table showing monthly readiness status
- Caveat Detail Table:
  - table showing reporting month, caveat code, severity, affected area, and failed record count

Implemented slicers:

- year;
- month;
- severity;
- affected area.

Expected takeaway:

Most reporting months are ready for release. Months with caveats are visible, no blocker-level issues remain, and stakeholders can see which limitations need to be disclosed.

Evidence:

- `powerbi/pipeline_c_monthly_insights/05_data_confidence.png`

## Page Navigation

Recommended page order:

1. Monthly Overview
2. Attendance Seasonality
3. Year-Level Patterns
4. Attendance And Assessment
5. Data Confidence

This order starts with the executive monthly question, then supports deeper investigation, then ends with data confidence.

## Visual Design Principles

- Use plain-English page titles.
- Use restrained, work-focused styling.
- Avoid student-level detail.
- Avoid technical pipeline fields on stakeholder pages.
- Use consistent month, region, school type, and year-level slicers.
- Put caveats near the metrics they affect.
- Use visual emphasis for movement, readiness, and caveats.
- Keep charts readable without explanatory paragraphs on the page.

## Data Quality And Caveat Handling

The dashboard should not hide data quality issues.

Minimum requirements:

- all pages should be filterable by reporting month;
- Monthly Overview should show readiness status;
- Data Confidence should show issue counts and caveat details;
- Attendance And Assessment should exclude invalid assessment scores;
- attendance visuals should exclude invalid attendance rows;
- caveat counts should reconcile to the quality layer.

The dashboard should explain quality limitations in business language, for example:

```text
June 2025 attendance includes excluded records where attended days exceeded possible days.
```

## Brief Support

The dashboard should support a short monthly insights brief after it is built.

The brief should draw from:

- selected reporting month;
- key attendance movement;
- cohorts or schools requiring attention;
- attendance-to-assessment finding;
- caveats and readiness status;
- recommended actions.

The final brief should be written after the Power BI dashboard is created and validated, not before.

## Evidence To Capture

Portfolio evidence should include:

- Power BI model view screenshot;
- measure list or notes;
- each dashboard page screenshot;
- data quality caveat page screenshot;
- evidence that student identifiers are not exposed;
- final monthly insights brief.

Captured dashboard screenshots so far:

- `powerbi/pipeline_c_monthly_insights/01_monthly_overview.png`
- `powerbi/pipeline_c_monthly_insights/02_attendance_seasonality.png`
- `powerbi/pipeline_c_monthly_insights/03_year_level_patterns.png`

## Open Implementation Decisions

Decide during Power BI implementation:

- whether all fields come from reporting views or whether small helper dimensions are imported;
- whether Power BI refresh is triggered automatically from ADF/Fabric or manually for portfolio evidence;
- exact visual formatting and colour choices;
- whether the dashboard uses one selected reporting month or defaults to the latest successful month.
