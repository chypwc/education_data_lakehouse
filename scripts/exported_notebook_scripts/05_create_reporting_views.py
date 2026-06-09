# Databricks notebook source
from datetime import datetime, timezone

dbutils.widgets.text("environment", "dev")
dbutils.widgets.text("batch_id", "2025-01-15")
dbutils.widgets.dropdown("run_mode", "initial", ["initial", "incremental"])
dbutils.widgets.text("job_run_id", "")

environment = dbutils.widgets.get("environment")
batch_id = dbutils.widgets.get("batch_id")
run_mode = dbutils.widgets.get("run_mode")
job_run_id = dbutils.widgets.get("job_run_id")

pipeline_name = "education_qa_pipeline"

if job_run_id:
    run_id = f"{environment}_{pipeline_name}_{batch_id}_{run_mode}_job_{job_run_id}"
else:
    run_timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_id = f"{environment}_{pipeline_name}_{batch_id}_{run_mode}_{run_timestamp}"

catalog = "dbw_edu_qa_dev"

print(f"environment: {environment}")
print(f"batch_id: {batch_id}")
print(f"run_mode: {run_mode}")
print(f"job_run_id: {job_run_id}")
print(f"run_id: {run_id}")

spark.sql(f"CREATE SCHEMA IF NOT EXISTS {catalog}.reporting")

spark.sql(f"SHOW SCHEMAS IN {catalog}").show(truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ### vw_data_quality_rule_detail, vw_data_quality_summary

# COMMAND ----------

spark.sql(f"""
CREATE OR REPLACE VIEW {catalog}.reporting.vw_data_quality_rule_detail AS
SELECT
    dq.batch_id,
    b.batch_label,

    dq.rule_id,
    dq.rule_name,
    dq.target_table,
    dq.severity,
    dq.severity_sort_order,

    dq.status,
    dq.status_sort_order,

    dq.failed_record_count,
    dq.issue_flag,

    dq.run_id,
    dq.run_timestamp,
    dq.gold_load_timestamp
FROM {catalog}.gold.fact_data_quality_result dq
LEFT JOIN {catalog}.gold.dim_batch b
    ON dq.batch_key = b.batch_key
""")

# COMMAND ----------

display(
    spark.table(f"{catalog}.reporting.vw_data_quality_rule_detail")
    .orderBy("batch_id", "rule_id")
)


# COMMAND ----------

spark.sql(f"""
CREATE OR REPLACE VIEW {catalog}.reporting.vw_data_quality_summary AS
SELECT
    dq.batch_id,
    b.batch_label,

    dq.severity,
    dq.severity_sort_order,

    dq.status,
    dq.status_sort_order,

    COUNT(*) AS rule_count,
    SUM(dq.failed_record_count) AS failed_record_count,
    SUM(dq.issue_flag) AS issue_rule_count,

    MAX(dq.gold_load_timestamp) AS gold_load_timestamp
FROM {catalog}.gold.fact_data_quality_result dq
LEFT JOIN {catalog}.gold.dim_batch b
    ON dq.batch_key = b.batch_key
GROUP BY
    dq.batch_id,
    b.batch_label,
    dq.severity,
    dq.severity_sort_order,
    dq.status,
    dq.status_sort_order
""")


# COMMAND ----------

display(
    spark.table(f"{catalog}.reporting.vw_data_quality_summary")
    .orderBy("batch_id", "severity_sort_order", "status_sort_order")
)

# COMMAND ----------

spark.sql(f"""
CREATE OR REPLACE VIEW {catalog}.reporting.vw_defect_log AS
SELECT
    d.batch_id,
    b.batch_label,

    d.rule_id,
    d.rule_name,
    d.target_table,

    d.severity,
    d.severity_sort_order,

    d.defect_id,
    d.defect_title,
    d.defect_status,
    d.defect_status_sort_order,
    d.open_defect_flag,

    d.failed_record_count,
    d.recommended_action,
    d.created_timestamp,
    d.gold_load_timestamp
FROM {catalog}.gold.fact_defect d
LEFT JOIN {catalog}.gold.dim_batch b
    ON d.batch_key = b.batch_key
""")



# COMMAND ----------

display(
    spark.table(f"{catalog}.reporting.vw_defect_log")
    .orderBy("batch_id", "severity_sort_order", "rule_id")
)

# COMMAND ----------

display(
    spark.table(f"{catalog}.reporting.vw_data_quality_rule_detail")
    .groupBy("batch_id")
    .count()
    .orderBy("batch_id")
)

display(
    spark.table(f"{catalog}.reporting.vw_defect_log")
    .groupBy("batch_id")
    .count()
    .orderBy("batch_id")
)

# COMMAND ----------

# MAGIC %md
# MAGIC ### vw_attendance_by_school_month,  vw_attendance_by_year_level

# COMMAND ----------

spark.sql(f"""
CREATE OR REPLACE VIEW {catalog}.reporting.vw_attendance_by_school_month AS
SELECT
    f.batch_id,
    b.batch_label,

    s.school_id,
    s.school_name,
    s.region,
    s.school_type,
    s.status AS school_status,

    d.full_date AS attendance_month,
    d.calendar_year AS attendance_year,
    d.month_number AS attendance_month_number,
    d.month_name AS attendance_month_name,

    SUM(f.possible_days) AS possible_days,
    SUM(f.attended_days) AS attended_days,
    COUNT(DISTINCT f.student_batch_key) AS student_count,

    CASE
        WHEN SUM(f.possible_days) > 0
        THEN ROUND(SUM(f.attended_days) / SUM(f.possible_days), 4)
        ELSE NULL
    END AS attendance_rate,

    CASE
        WHEN SUM(f.possible_days) > 0
        THEN ROUND((SUM(f.attended_days) / SUM(f.possible_days)) * 100, 2)
        ELSE NULL
    END AS attendance_rate_percent,

    CASE
        WHEN SUM(f.possible_days) = 0 THEN 'No possible days'
        WHEN SUM(f.attended_days) / SUM(f.possible_days) < 0.80 THEN 'Below 80%'
        WHEN SUM(f.attended_days) / SUM(f.possible_days) < 0.85 THEN '80% to below 85%'
        WHEN SUM(f.attended_days) / SUM(f.possible_days) < 0.90 THEN '85% to below 90%'
        ELSE '90% and above'
    END AS attendance_band,

    CASE
        WHEN SUM(f.possible_days) = 0 THEN 0
        WHEN SUM(f.attended_days) / SUM(f.possible_days) < 0.80 THEN 1
        WHEN SUM(f.attended_days) / SUM(f.possible_days) < 0.85 THEN 2
        WHEN SUM(f.attended_days) / SUM(f.possible_days) < 0.90 THEN 3
        ELSE 4
    END AS attendance_band_sort_order,

    MAX(f.gold_load_timestamp) AS gold_load_timestamp
FROM {catalog}.gold.fact_attendance f
LEFT JOIN {catalog}.gold.dim_batch b
    ON f.batch_key = b.batch_key
LEFT JOIN {catalog}.gold.dim_school s
    ON f.school_scd_key = s.school_scd_key
LEFT JOIN {catalog}.gold.dim_date d
    ON f.attendance_month_date_key = d.date_key
GROUP BY
    f.batch_id,
    b.batch_label,
    s.school_id,
    s.school_name,
    s.region,
    s.school_type,
    s.status,
    d.full_date,
    d.calendar_year,
    d.month_number,
    d.month_name
""")

display(
    spark.table(f"{catalog}.reporting.vw_attendance_by_school_month")
    .orderBy("batch_id", "school_id", "attendance_month")
    .limit(50)
)


# COMMAND ----------

spark.sql(f"""
CREATE OR REPLACE VIEW {catalog}.reporting.vw_attendance_by_year_level AS
SELECT
    f.batch_id,
    b.batch_label,

    yl.year_level,
    yl.year_level_label,
    yl.year_level_sort_order,

    d.full_date AS attendance_month,
    d.calendar_year AS attendance_year,
    d.month_number AS attendance_month_number,
    d.month_name AS attendance_month_name,

    SUM(f.possible_days) AS possible_days,
    SUM(f.attended_days) AS attended_days,
    COUNT(DISTINCT f.student_batch_key) AS student_count,

    CASE
        WHEN SUM(f.possible_days) > 0
        THEN ROUND(SUM(f.attended_days) / SUM(f.possible_days), 4)
        ELSE NULL
    END AS attendance_rate,

    CASE
        WHEN SUM(f.possible_days) > 0
        THEN ROUND((SUM(f.attended_days) / SUM(f.possible_days)) * 100, 2)
        ELSE NULL
    END AS attendance_rate_percent,

    CASE
        WHEN SUM(f.possible_days) = 0 THEN 'No possible days'
        WHEN SUM(f.attended_days) / SUM(f.possible_days) < 0.80 THEN 'Below 80%'
        WHEN SUM(f.attended_days) / SUM(f.possible_days) < 0.85 THEN '80% to below 85%'
        WHEN SUM(f.attended_days) / SUM(f.possible_days) < 0.90 THEN '85% to below 90%'
        ELSE '90% and above'
    END AS attendance_band,

    CASE
        WHEN SUM(f.possible_days) = 0 THEN 0
        WHEN SUM(f.attended_days) / SUM(f.possible_days) < 0.80 THEN 1
        WHEN SUM(f.attended_days) / SUM(f.possible_days) < 0.85 THEN 2
        WHEN SUM(f.attended_days) / SUM(f.possible_days) < 0.90 THEN 3
        ELSE 4
    END AS attendance_band_sort_order,

    MAX(f.gold_load_timestamp) AS gold_load_timestamp
FROM {catalog}.gold.fact_attendance f
LEFT JOIN {catalog}.gold.dim_batch b
    ON f.batch_key = b.batch_key
LEFT JOIN {catalog}.gold.dim_year_level yl
    ON f.year_level_key = yl.year_level_key
LEFT JOIN {catalog}.gold.dim_date d
    ON f.attendance_month_date_key = d.date_key
GROUP BY
    f.batch_id,
    b.batch_label,
    yl.year_level,
    yl.year_level_label,
    yl.year_level_sort_order,
    d.full_date,
    d.calendar_year,
    d.month_number,
    d.month_name
""")

display(
    spark.table(f"{catalog}.reporting.vw_attendance_by_year_level")
    .orderBy("batch_id", "year_level_sort_order", "attendance_month")
    .limit(50)
)

# COMMAND ----------

display(
    spark.table(f"{catalog}.reporting.vw_attendance_by_school_month")
    .groupBy("batch_id")
    .count()
    .orderBy("batch_id")
)

display(
    spark.table(f"{catalog}.reporting.vw_attendance_by_year_level")
    .groupBy("batch_id")
    .count()
    .orderBy("batch_id")
)

# COMMAND ----------

# MAGIC %md
# MAGIC ### vw_assessment_by_school, vw_assessment_by_domain

# COMMAND ----------

spark.sql(f"""
CREATE OR REPLACE VIEW {catalog}.reporting.vw_assessment_by_school AS
SELECT
    f.batch_id,
    b.batch_label,

    d.calendar_year AS assessment_year,

    s.school_id,
    s.school_name,
    s.region,
    s.school_type,
    s.status AS school_status,

    COUNT(*) AS assessment_count,
    COUNT(DISTINCT f.student_batch_key) AS student_count,

    ROUND(AVG(f.score), 2) AS average_score,
    CAST(percentile_approx(f.score, 0.5) AS INT) AS median_score,
    MIN(f.score) AS min_score,
    MAX(f.score) AS max_score,

    CASE
        WHEN AVG(f.score) < 400 THEN 'Below 400'
        WHEN AVG(f.score) < 550 THEN '400 to below 550'
        ELSE '550 and above'
    END AS average_score_band,

    CASE
        WHEN AVG(f.score) < 400 THEN 1
        WHEN AVG(f.score) < 550 THEN 2
        ELSE 3
    END AS average_score_band_sort_order,

    MAX(f.gold_load_timestamp) AS gold_load_timestamp
FROM {catalog}.gold.fact_assessment_result f
LEFT JOIN {catalog}.gold.dim_batch b
    ON f.batch_key = b.batch_key
LEFT JOIN {catalog}.gold.dim_school s
    ON f.school_scd_key = s.school_scd_key
LEFT JOIN {catalog}.gold.dim_date d
    ON f.assessment_year_date_key = d.date_key
GROUP BY
    f.batch_id,
    b.batch_label,
    d.calendar_year,
    s.school_id,
    s.school_name,
    s.region,
    s.school_type,
    s.status
""")

display(
    spark.table(f"{catalog}.reporting.vw_assessment_by_school")
    .orderBy("batch_id", "assessment_year", "school_id")
    .limit(50)
)


# COMMAND ----------

spark.sql(f"""
CREATE OR REPLACE VIEW {catalog}.reporting.vw_assessment_by_domain AS
SELECT
    f.batch_id,
    b.batch_label,

    d.calendar_year AS assessment_year,

    dom.domain,
    dom.domain_sort_order,

    band.proficiency_band,
    band.proficiency_band_sort_order,
    band.score_range_label,

    COUNT(*) AS assessment_count,
    COUNT(DISTINCT f.student_batch_key) AS student_count,

    ROUND(AVG(f.score), 2) AS average_score,
    CAST(percentile_approx(f.score, 0.5) AS INT) AS median_score,
    MIN(f.score) AS min_score,
    MAX(f.score) AS max_score,

    MAX(f.gold_load_timestamp) AS gold_load_timestamp
FROM {catalog}.gold.fact_assessment_result f
LEFT JOIN {catalog}.gold.dim_batch b
    ON f.batch_key = b.batch_key
LEFT JOIN {catalog}.gold.dim_date d
    ON f.assessment_year_date_key = d.date_key
LEFT JOIN {catalog}.gold.dim_assessment_domain dom
    ON f.domain_key = dom.domain_key
LEFT JOIN {catalog}.gold.dim_proficiency_band band
    ON f.proficiency_band_key = band.proficiency_band_key
GROUP BY
    f.batch_id,
    b.batch_label,
    d.calendar_year,
    dom.domain,
    dom.domain_sort_order,
    band.proficiency_band,
    band.proficiency_band_sort_order,
    band.score_range_label
""")

display(
    spark.table(f"{catalog}.reporting.vw_assessment_by_domain")
    .orderBy(
        "batch_id",
        "assessment_year",
        "domain_sort_order",
        "proficiency_band_sort_order"
    )
)

# COMMAND ----------

display(
    spark.table(f"{catalog}.reporting.vw_assessment_by_school")
    .groupBy("batch_id")
    .count()
    .orderBy("batch_id")
)

display(
    spark.table(f"{catalog}.reporting.vw_assessment_by_domain")
    .groupBy("batch_id")
    .count()
    .orderBy("batch_id")
)

# COMMAND ----------

# Final Validation

from functools import reduce
from pyspark.sql import functions as F

reporting_views = [
    "vw_data_quality_rule_detail",
    "vw_data_quality_summary",
    "vw_defect_log",
    "vw_attendance_by_school_month",
    "vw_attendance_by_year_level",
    "vw_assessment_by_school",
    "vw_assessment_by_domain"
]

reporting_validation_dfs = []

for view_name in reporting_views:
    df = spark.table(f"{catalog}.reporting.{view_name}")

    validation_df = (
        df.groupBy("batch_id")
        .agg(F.count("*").alias("row_count"))
        .withColumn("reporting_view", F.lit(view_name))
        .select("reporting_view", "batch_id", "row_count")
    )

    reporting_validation_dfs.append(validation_df)

reporting_output_validation_df = reduce(
    lambda df1, df2: df1.unionByName(df2),
    reporting_validation_dfs
)

display(
    reporting_output_validation_df
    .orderBy("reporting_view", "batch_id")
)


# COMMAND ----------

