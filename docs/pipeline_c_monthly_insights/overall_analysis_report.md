# Pipeline C Overall Analysis Report

## Purpose

Pipeline C extends the education data lakehouse into monthly analytics reporting. It uses synthetic monthly education data, Azure SQL Database serverless processing, and a Power BI semantic model to answer a stakeholder question:

```text
What changed this month, which cohorts or schools need attention, and how confident are we in the data?
```

This report summarises the patterns shown in the Power BI dashboard and explains how the dashboard pages support monthly education insights.

## Audience

This report is written for:

- education reporting stakeholders;
- school operations or performance monitoring users;
- portfolio reviewers assessing analytics, reporting, and stakeholder communication capability.

The report avoids student-level detail and interprets aggregate trends only.

## Executive Summary

The dashboard shows a clear monthly attendance story across 2024 and 2025:

- attendance declines during winter months, especially June to August;
- Year 7 transition and senior secondary cohorts show different attendance behaviour from other year levels;
- senior secondary year levels have the highest share of student-months below the 80% attendance threshold;
- higher attendance bands are associated with stronger assessment scores across Reading, Numeracy, and Writing;
- data quality caveats are visible and explain which months require reporting notes.

The Power BI dashboard is therefore suitable for stakeholder-facing monthly reporting. It does not only show raw counts; it explains trends, cohort risk, assessment associations, and confidence in the data.

## Data And Reporting Context

Pipeline C uses a production-style monthly load pattern:

- initial snapshot: January 2024;
- monthly change batches: February 2024 to December 2025;
- raw files land by monthly folder, such as `month=2024-01`;
- Azure Data Factory triggers processing when `_READY.json` is uploaded;
- Azure SQL layers process the data through `bronze`, `silver`, `quality`, `gold`, `reporting`, and `audit`;
- Power BI uses Gold tables as the primary semantic model.

The data is synthetic and intentionally shaped to demonstrate realistic reporting patterns and controlled data quality caveats.

## Key Findings

### 1. Attendance Shows A Winter Decline

The Attendance Seasonality page shows a consistent winter pattern. Overall attendance is lower during June, July, and August than in non-winter months.

In the dashboard evidence, the all-period attendance rate is about 88.8%, while winter attendance is about 83.9% and non-winter attendance is about 90.7%. This creates a winter gap of about -6.8 percentage points.

This is a useful stakeholder finding because it turns monthly attendance data into an operational question:

```text
Which regions, cohorts, or schools need extra engagement support before and during winter?
```

The regional winter dip chart also shows that the winter effect is not identical across regions. This supports targeted follow-up rather than treating the winter decline as a system-wide average only.

### 2. Year-Level Patterns Identify Cohorts For Monitoring

The Year-Level Patterns page shows that year levels do not behave uniformly.

Year 7 attendance is lower than the broader Years 8-10 group, supporting the transition story. Senior secondary attendance is also lower and more volatile, which is visible through the senior attendance KPI and the at-risk student-month share.

The at-risk chart uses a student-month definition: one student attendance record for one reporting month. This avoids overcounting a student as at risk across a long period simply because they were below the threshold once.

The highest at-risk shares appear in Years 11 and 12. This supports a practical monitoring question:

```text
Which senior secondary groups require closer attendance monitoring, and should engagement strategies differ from junior year levels?
```

### 3. Cohort Tracking Adds More Context Than Static Year-Level Averages

The cohort trend follows groups based on their starting year level in February 2024. This helps separate current year-level patterns from the movement of the same starting cohort over time.

This matters because a static Year 7 view only shows students who are currently in Year 7. A starting-cohort trend can show how a group moves after transition and whether attendance stabilises, declines, or remains volatile.

This is a stronger analytics story than a single year-level bar chart because it asks:

```text
Are the same students improving or declining over time?
```

### 4. Attendance Bands Are Associated With Assessment Outcomes

The Attendance And Assessment page shows that higher attendance bands are associated with stronger assessment outcomes.

In the dashboard evidence:

- average assessment score is about 418.9;
- high-attendance students average about 431.3;
- low-attendance students average about 381.7;
- the high-low score gap is about 49.6 points.

The relationship appears across Reading, Numeracy, and Writing, with a similar high-low score gap by domain.

This finding should be interpreted carefully. The dashboard shows an association between attendance and assessment score, not proof that attendance alone caused the score difference. Other factors may also contribute.

The stakeholder value is still strong:

```text
Attendance bands can help identify groups where learning outcomes may need closer monitoring.
```

### 5. Data Confidence Is Visible And Reportable

The Data Confidence page shows that reporting readiness is not hidden from users.

Across the displayed dashboard evidence:

- rejected record count is 10;
- warning caveats count is 4;
- error caveats count is 6;
- blocker caveats count is 0.

Most months are ready for release, while selected months are marked `READY_WITH_CAVEATS`. This means reporting can proceed, but notes should explain excluded or caveated records.

The caveat detail table is important because it turns data quality from a technical issue into a reporting disclosure. Examples include duplicate attendance business keys, invalid attendance days, invalid assessment scores, and missing student reference fields.

## Dashboard Page Interpretation

### Monthly Overview

The Monthly Overview page answers:

```text
What changed this month?
```

It combines selected-month KPI cards with trend context, year-level breakdowns, regional comparison, and caveat visibility. This page should be the first page used in a monthly reporting meeting.

The key value is that stakeholders can see both the selected month and the broader trend before deciding whether a change is meaningful.

Evidence:

- `powerbi/pipeline_c_monthly_insights/01_monthly_overview.png`

### Attendance Seasonality

The Attendance Seasonality page answers:

```text
Is attendance following a seasonal pattern?
```

It shows winter attendance, non-winter attendance, winter gap, regional winter dip, monthly trend, and a month-by-year-level heatmap.

The key value is that it explains the recurring winter decline and shows where the decline is stronger.

Evidence:

- `powerbi/pipeline_c_monthly_insights/02_attendance_seasonality.png`

### Year-Level Patterns

The Year-Level Patterns page answers:

```text
Which cohorts need closer monitoring?
```

It shows Year 7 transition patterns, Years 8-10 comparison, senior attendance, at-risk student-month share, attendance band distribution, and starting-cohort trends.

The key value is that it shifts the analysis from overall attendance to cohort-specific monitoring.

Evidence:

- `powerbi/pipeline_c_monthly_insights/03_year_level_patterns.png`

### Attendance And Assessment

The Attendance And Assessment page answers:

```text
How do attendance bands relate to assessment outcomes?
```

It shows assessment score differences by attendance band, year level, and domain. The page makes the attendance-to-learning outcome relationship visible without overclaiming causality.

The key value is that it gives stakeholders a learning-outcome signal linked to attendance patterns.

Evidence:

- `powerbi/pipeline_c_monthly_insights/04_attendance_assessment.png`

### Data Confidence

The Data Confidence page answers:

```text
Can this dashboard be released, and what caveats should stakeholders know?
```

It shows readiness status, rejected records, caveats by severity, caveats by affected area, monthly readiness, and caveat detail.

The key value is that users can distinguish a clean reporting month from a month that should be released with notes.

Evidence:

- `powerbi/pipeline_c_monthly_insights/05_data_confidence.png`

## Recommended Stakeholder Actions

- Use the Monthly Overview page as the first page for routine monthly review.
- Monitor winter months early, especially June to August, rather than waiting until attendance has already declined.
- Review Year 7 and senior secondary attendance separately because their patterns differ from the system average.
- Use at-risk student-month share to identify year levels with repeated attendance concern.
- Treat attendance-assessment findings as a signal for further investigation, not as causal proof.
- Include data confidence notes in monthly reporting when readiness is `READY_WITH_CAVEATS`.

## Data Quality And Interpretation Caveats

The report is based on synthetic data created for a portfolio project. The patterns are intentionally shaped to demonstrate analytics storytelling, monthly reporting, and data quality handling.

Important interpretation limits:

- the data should not be treated as real school or student performance data;
- student-level identifiers are not shown in stakeholder-facing outputs;
- attendance and assessment results are associated, but causality is not claimed;
- caveated records are excluded or explained according to quality rules;
- `READY_WITH_CAVEATS` means reporting can continue with notes, while `NOT_READY` would mean reporting should not be released.

## Portfolio Evidence

Pipeline C demonstrates:

- monthly production-style data loading;
- Azure SQL Database serverless medallion-style processing;
- merge/upsert and reporting readiness logic;
- quality caveats and rejected record evidence;
- Gold semantic model design for Power BI;
- stakeholder-facing dashboard pages;
- analytics interpretation across attendance, assessment, and data confidence.

Dashboard evidence:

- `powerbi/pipeline_c_monthly_insights/01_monthly_overview.png`
- `powerbi/pipeline_c_monthly_insights/02_attendance_seasonality.png`
- `powerbi/pipeline_c_monthly_insights/03_year_level_patterns.png`
- `powerbi/pipeline_c_monthly_insights/04_attendance_assessment.png`
- `powerbi/pipeline_c_monthly_insights/05_data_confidence.png`

## Suggested Monthly Briefs

The next step is to write two or three short monthly briefs. Suggested months:

| Month | Why this month is useful |
|---|---|
| 2024-03 | Shows `READY_WITH_CAVEATS` due to a student reference issue |
| 2024-06 | Shows winter attendance decline and attendance quality caveats |
| 2024-11 | Shows assessment data caveat and supports the attendance-assessment story |

An optional clean month, such as 2024-09, can also be used to show what a normal `READY` reporting month looks like.
