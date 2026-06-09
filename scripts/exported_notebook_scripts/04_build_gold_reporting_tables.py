# Databricks notebook source
from pyspark.sql import functions as F
from pyspark.sql import types as T
from pyspark.sql.window import Window
from functools import reduce
from delta.tables import DeltaTable
from datetime import datetime, timezone

# COMMAND ----------

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

if run_mode == "initial":
    gold_write_mode = "overwrite"
elif run_mode == "incremental":
    gold_write_mode = "merge"
else:
    raise ValueError(f"Unsupported run_mode: {run_mode}")

catalog = "dbw_edu_qa_dev"
storage_account = "steduqadblakehouse"
container = "education-data-lake"

lake_root = f"abfss://{container}@{storage_account}.dfs.core.windows.net"

print(f"environment: {environment}")
print(f"batch_id: {batch_id}")
print(f"run_mode: {run_mode}")
print(f"job_run_id: {job_run_id}")
print(f"run_id: {run_id}")
print(f"gold_write_mode: {gold_write_mode}")

# COMMAND ----------

source_tables = [
    "silver.schools",
    "silver.students",
    "silver.attendance",
    "silver.assessment_results",
    "silver.school_events",
    "qa.dq_validation_results",
    "qa.dq_failed_records",
    "qa.defect_log"
]

for table_name in source_tables:
    print(f"\n=== {catalog}.{table_name} ===")
    spark.table(f"{catalog}.{table_name}").printSchema()

# COMMAND ----------

def write_delta_table(df, table_name, target_path, merge_condition=None):
    full_table_name = f"{catalog}.{table_name}"

    if gold_write_mode == "overwrite":
        (
            df.write
            .format("delta")
            .mode("overwrite")
            .option("overwriteSchema", "true")
            .option("path", target_path)
            .saveAsTable(full_table_name)
        )

    elif gold_write_mode == "append":
        (
            df.write
            .format("delta")
            .mode("append")
            .option("path", target_path)
            .saveAsTable(full_table_name)
        )

    elif gold_write_mode == "merge":
        if not spark.catalog.tableExists(full_table_name):
            (
                df.write
                .format("delta")
                .mode("overwrite")
                .option("path", target_path)
                .saveAsTable(full_table_name)
            )
        else:
            # gets an existing Delta table from the catalog.
            delta_table = DeltaTable.forName(spark, full_table_name)

            (
                delta_table.alias("target")
                .merge(
                    df.alias("source"),
                    merge_condition
                )
                .whenMatchedUpdateAll()
                .whenNotMatchedInsertAll()
                .execute()
            )

    else:
        raise ValueError(f"Unsupported gold_write_mode: {gold_write_mode}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Dimension tables
# MAGIC ### dim_batch, dim_date, dim_school, dim_student, dim_year_level, dim_assessment_domain, dim_proficiency_band, dim_dq_rule

# COMMAND ----------

# gold.dim_batch
# Grain: one row per source batch.

batch_df = spark.createDataFrame(
    [
        ("2025-01-15", 1, "Batch 1 - 2024 data", 2024, "Initial load"),
        ("2026-01-15", 2, "Batch 2 - 2025 data", 2025, "Incremental load"),
    ],
    ["batch_id", "batch_sequence", "batch_label", "data_period_year", "batch_load_type"]
)

dim_batch_df = (
    batch_df
    .filter(F.col("batch_id") == batch_id)
    .withColumn(
        "batch_key",
        F.sha2(F.col("batch_id"), 256)
    )
    .withColumn("environment", F.lit(environment))
    .withColumn("gold_load_timestamp", F.current_timestamp())
    .select(
        "batch_key",
        "batch_id",
        "batch_sequence",
        "batch_label",
        "data_period_year",
        "batch_load_type",
        "environment",
        "gold_load_timestamp"
    )
)

target_path = f"{lake_root}/gold/dim_batch"

merge_condition = """
target.batch_id = source.batch_id
"""

write_delta_table(
    df=dim_batch_df,
    table_name="gold.dim_batch",
    target_path=target_path,
    merge_condition=merge_condition
)

display(
    spark.table(f"{catalog}.gold.dim_batch")
    .orderBy("batch_sequence")
)

# COMMAND ----------

# gold.dim_date
# Grain: one row per calendar date needed by attendance, assessment, school, student, and event data.

date_sources = []

date_sources.append(
    spark.table(f"{catalog}.silver.attendance")
    .filter(F.col("batch_id") == batch_id)
    .select(
        F.col("attendance_month").alias("date_value")
    )
)

date_sources.append(
    spark.table(f"{catalog}.silver.assessment_results")
    .filter(F.col("batch_id") == batch_id)
    .select(
        F.to_date(
            F.concat(F.col("assessment_year").cast("string"), F.lit("-01-01"))
        )
        .alias("date_value")
    )
)

# date_sources.append(
#     spark.table(f"{catalog}.silver.schools")
#     .filter(F.col("batch_id") == batch_id)
#     .select(
#         F.col("open_date").alias("date_value")
#     )
# )

# date_sources.append(
#     spark.table(f"{catalog}.silver.students")
#     .filter(F.col("batch_id") == batch_id)
#     .select(F.col("enrolment_date").alias("date_value"))
# )

date_sources.append(
    spark.table(f"{catalog}.silver.school_events")
    .filter(F.col("batch_id") == batch_id)
    .select(F.col("event_date").alias("date_value"))
)


date_bounds_df = (
    reduce(lambda df1, df2: df1.unionByName(df2), date_sources)
    .filter(F.col("date_value").isNotNull())
    .agg(
        F.min("date_value").alias("min_date"),
        F.max("date_value").alias("max_date")
    )
)

dim_date_df = (
    date_bounds_df
    .select(F.explode(F.sequence(F.col("min_date"), F.col("max_date"))).alias("full_date"))
    .withColumn("date_key", F.date_format("full_date", "yyyyMMdd").cast("int"))
    .withColumn("calendar_year", F.year("full_date"))
    .withColumn("quarter_number", F.quarter("full_date"))
    .withColumn("month_number", F.month("full_date"))
    .withColumn("month_name", F.monthname("full_date"))
    .withColumn("month_start_date", F.trunc("full_date", "month"))
    .withColumn("day_of_month", F.dayofmonth("full_date"))
    .withColumn("day_of_week_number", F.dayofweek("full_date"))
    .withColumn("day_of_week_name", F.date_format("full_date", "E"))
    .withColumn(
        "is_month_start",
        F.col("full_date") == F.col("month_start_date")
    )
    .withColumn("gold_load_timestamp", F.current_timestamp())
    .select(
        "date_key",
        "full_date",
        "calendar_year",
        "quarter_number",
        "month_number",
        "month_name",
        "month_start_date",
        "day_of_month",
        "day_of_week_number",
        "day_of_week_name",
        "is_month_start",
        "gold_load_timestamp"
    )    
)
   

target_path = f"{lake_root}/gold/dim_date"

merge_condition = """
target.date_key = source.date_key
"""

write_delta_table(
    df=dim_date_df,
    table_name="gold.dim_date",
    target_path=target_path,
    merge_condition=merge_condition
)

display(
    spark.table(f"{catalog}.gold.dim_date")
    .orderBy("full_date")
    .limit(50)
)

# COMMAND ----------

display(
    spark.table(f"{catalog}.gold.dim_date")
    .agg(
        F.count("*").alias("date_rows"),
        F.min("full_date").alias("min_date"),
        F.max("full_date").alias("max_date")
    )
)

# COMMAND ----------

# gold.dim_school
# Grain: one row per school version.
# SCD Type 2 behaviour:
# - unchanged schools are not reinserted
# - changed schools expire the old current row and insert a new current row
# - new schools are inserted as current rows

from delta.tables import DeltaTable

source_school_df = (
    spark.table(f"{catalog}.silver.schools")
    .filter(F.col("batch_id") == batch_id)
)

duplicate_school_count = (
    source_school_df
    .groupBy("school_id")
    .count()
    .filter(F.col("count") > 1)
    .count()
)

if duplicate_school_count > 0:
    raise ValueError("Duplicate school_id values found in the incoming school batch.")

incoming_school_df = (
    source_school_df
    .select(
        "school_id",
        "school_name",
        "region",
        "school_type",
        "status",
        "open_date",
        "bronze_record_id",
        "source_file_name",
        "run_id",
        "silver_load_timestamp"
    )
    .withColumn(
        "school_key",
        F.sha2(F.coalesce(F.col("school_id"), F.lit("")), 256)
    )
    .withColumn(
        "school_attribute_hash",
        F.sha2(
            F.concat_ws(
                "||",
                F.coalesce(F.col("school_name"), F.lit("")),
                F.coalesce(F.col("region"), F.lit("")),
                F.coalesce(F.col("school_type"), F.lit("")),
                F.coalesce(F.col("status"), F.lit("")),
                F.coalesce(F.col("open_date").cast("string"), F.lit(""))
            ),
            256
        )
    )
    .withColumn("effective_from_batch_id", F.lit(batch_id))
    .withColumn("effective_from_date", F.to_date(F.lit(batch_id)))
    .withColumn("effective_to_date", F.lit(None).cast("date"))
    .withColumn("is_current", F.lit(True))
    .withColumn(
        "school_scd_key",
        F.sha2(
            F.concat_ws(
                "||",
                F.coalesce(F.col("school_id"), F.lit("")),
                F.coalesce(F.col("effective_from_batch_id"), F.lit(""))
            ),
            256
        )
    )
    .withColumn(
        "is_active_school",
        F.when(F.col("status") == "Active", F.lit(True)).otherwise(F.lit(False))
    )
    .withColumn("gold_load_timestamp", F.current_timestamp())
    .select(
        "school_scd_key",
        "school_key",
        "school_id",
        "school_name",
        "region",
        "school_type",
        "status",
        "is_active_school",
        "open_date",
        "school_attribute_hash",
        "effective_from_batch_id",
        "effective_from_date",
        "effective_to_date",
        "is_current",
        "bronze_record_id",
        "source_file_name",
        "run_id",
        "silver_load_timestamp",
        "gold_load_timestamp"
    )
)

full_table_name = f"{catalog}.gold.dim_school"
target_path = f"{lake_root}/gold/dim_school"

if run_mode == "initial":
    (
        incoming_school_df.write
        .format("delta")
        .mode("overwrite")
        .option("overwriteSchema", "true")
        .option("path", target_path)
        .saveAsTable(full_table_name)
    )

elif run_mode == "incremental":
    current_school_df = (
        spark.table(full_table_name)
        .filter(F.col("is_current") == True)
        .select(
            "school_key",
            "school_attribute_hash"
        )
    )

    changed_or_new_school_df = (
        incoming_school_df.alias("source")
        .join(
            current_school_df.alias("target"),
            on="school_key",
            how="left"
        )
        .filter(
            F.col("target.school_key").isNull()
            | (F.col("source.school_attribute_hash") != F.col("target.school_attribute_hash"))
        )
        .select("source.*")
    )

    changed_existing_school_keys_df = (
        changed_or_new_school_df.alias("source")
        .join(
            current_school_df.alias("target"),
            on="school_key",
            how="inner"
        )
        .select("school_key")
        .distinct()
    )

    changed_or_new_count = changed_or_new_school_df.count()

    if changed_or_new_count > 0:
        delta_table = DeltaTable.forName(spark, full_table_name)

        (
            delta_table.alias("target")
            .merge(
                changed_existing_school_keys_df.alias("source"),
                """
                target.school_key = source.school_key
                AND target.is_current = true
                """
            )
            .whenMatchedUpdate(
                set={
                    "is_current": "false",
                    "effective_to_date": f"date_sub(to_date('{batch_id}'), 1)",
                    "gold_load_timestamp": "current_timestamp()"
                }
            )
            .execute()
        )

        (
            changed_or_new_school_df.write
            .format("delta")
            .mode("append")
            .saveAsTable(full_table_name)
        )

    print(f"Changed or new school rows inserted: {changed_or_new_count}")

else:
    raise ValueError(f"Unsupported run_mode: {run_mode}")

display(
    spark.table(full_table_name)
    .orderBy("school_id", "effective_from_date")
)

# COMMAND ----------

display(
    spark.table(f"{catalog}.gold.dim_school")
    .agg(
        F.count("*").alias("school_rows"),
        F.countDistinct("school_key").alias("distinct_school_keys"),
        F.countDistinct("school_id").alias("distinct_school_ids")
    )
)

# COMMAND ----------

display(
    spark.table(f"{catalog}.gold.dim_school")
    .groupBy("status")
    .count()
    .orderBy("status")
)

# COMMAND ----------

# gold.dim_year_level
# Grain: one row per year level.

year_level_df = (
    spark.table(f"{catalog}.silver.students")
    .filter(F.col("batch_id") == batch_id)
    .select("year_level")
    .where(F.col("year_level").isNotNull())
    .distinct()
)

dim_year_level_df = (
    year_level_df
    .withColumn(
        "year_level_key",
        F.sha2(F.col("year_level").cast("string"), 256)
    )
    .withColumn(
        "year_level_label",
        F.when(F.col("year_level") == 0, F.lit("Kindergarten"))
        .otherwise(F.concat(F.lit("Year "), F.col("year_level").cast("string")))
    )
    .withColumn(
        "year_level_sort_order",
        F.col("year_level")
    )
    .withColumn("gold_load_timestamp", F.current_timestamp())
    .select(
        "year_level_key",
        "year_level",
        "year_level_label",
        "year_level_sort_order",
        "gold_load_timestamp"
    )
)

target_path = f"{lake_root}/gold/dim_year_level"

merge_condition = """
target.year_level_key = source.year_level_key
"""

write_delta_table(
    df=dim_year_level_df,
    table_name="gold.dim_year_level",
    target_path=target_path,
    merge_condition=merge_condition
)

display(
    spark.table(f"{catalog}.gold.dim_year_level")
    .orderBy("year_level_sort_order")
)

# COMMAND ----------

# gold.dim_student
# Grain: one row per student per batch.
# Production note: student_id is synthetic in this portfolio.
# In production, hide/restrict raw student_id and expose student_key/student_batch_key.

students_df = (
    spark.table(f"{catalog}.silver.students")
    .filter(F.col("batch_id") == batch_id)
)

school_version_df = (
    spark.table(f"{catalog}.gold.dim_school")
    .select(
        F.col("school_key").alias("dim_school_key"),
        "school_scd_key",
        "effective_from_date",
        "effective_to_date"
    )
)

dim_student_df = (
    students_df
    .select(
        "batch_id",
        "student_id",
        "school_id",
        "year_level",
        "gender",
        "enrolment_date",
        "status",
        "bronze_record_id",
        "source_file_name",
        "run_id",
        "silver_load_timestamp"
    )
    .withColumn("batch_date", F.to_date(F.lit(batch_id)))
    .withColumn("student_key", F.sha2(F.coalesce(F.col("student_id"), F.lit("")), 256))
    .withColumn(
        "student_batch_key",
        F.sha2(
            F.concat_ws(
                "||",
                F.coalesce(F.col("batch_id"), F.lit("")),
                F.coalesce(F.col("student_id"), F.lit(""))
            ),
            256
        )
    )
    .withColumn("school_key", F.sha2(F.coalesce(F.col("school_id"), F.lit("")), 256))
    .withColumn("year_level_key", F.sha2(F.coalesce(F.col("year_level").cast("string"), F.lit("")), 256))
    .join(
        school_version_df,
        (F.col("school_key") == F.col("dim_school_key"))
        & (F.col("batch_date") >= F.col("effective_from_date"))
        & (
            F.col("effective_to_date").isNull()
            | (F.col("batch_date") <= F.col("effective_to_date"))
        ),
        "left"
    )
    .withColumn(
        "is_active_student",
        F.when(F.col("status") == "Active", F.lit(True)).otherwise(F.lit(False))
    )
    .withColumn("gold_load_timestamp", F.current_timestamp())
    .select(
        "student_batch_key",
        "student_key",
        "batch_id",
        "student_id",
        "school_key",
        "school_scd_key",
        "school_id",
        "year_level_key",
        "year_level",
        "gender",
        "enrolment_date",
        "status",
        "is_active_student",
        "bronze_record_id",
        "source_file_name",
        "run_id",
        "silver_load_timestamp",
        "gold_load_timestamp"
    )
)

target_path = f"{lake_root}/gold/dim_student"

merge_condition = """
target.student_batch_key = source.student_batch_key
"""

write_delta_table(
    df=dim_student_df,
    table_name="gold.dim_student",
    target_path=target_path,
    merge_condition=merge_condition
)

display(
    spark.table(f"{catalog}.gold.dim_student")
    .groupBy("batch_id")
    .agg(
        F.count("*").alias("student_batch_rows"),
        F.countDistinct("student_key").alias("distinct_students"),
        F.countDistinct("student_batch_key").alias("distinct_student_batch_keys"),
        F.sum(F.when(F.col("school_scd_key").isNull(), 1).otherwise(0)).alias("missing_school_scd_key")
    )
    .orderBy("batch_id")
)

# COMMAND ----------

# gold.dim_assessment_domain
# Grain: one row per assessment domain.

domain_df = (
    spark.table(f"{catalog}.silver.assessment_results")
    .filter(F.col("batch_id") == batch_id)
    .select("domain")
    .where(F.col("domain").isNotNull())
    .distinct()
)

dim_assessment_domain_df = (
    domain_df
    .withColumn(
        "domain_key",
        F.sha2(F.coalesce(F.col("domain"), F.lit("")), 256)
    )
    .withColumn(
        "domain_sort_order",
        F.when(F.col("domain") == "Reading", F.lit(1))
        .when(F.col("domain") == "Writing", F.lit(2))
        .when(F.col("domain") == "Numeracy", F.lit(3))
        .otherwise(F.lit(99))
    )
    .withColumn("gold_load_timestamp", F.current_timestamp())
    .select(
        "domain_key",
        "domain",
        "domain_sort_order",
        "gold_load_timestamp"
    )
)

target_path = f"{lake_root}/gold/dim_assessment_domain"

merge_condition = """
target.domain_key = source.domain_key
"""

write_delta_table(
    df=dim_assessment_domain_df,
    table_name="gold.dim_assessment_domain",
    target_path=target_path,
    merge_condition=merge_condition
)

display(
    spark.table(f"{catalog}.gold.dim_assessment_domain")
    .orderBy("domain_sort_order")
)

# COMMAND ----------

# COMMAND ----------

# gold.dim_proficiency_band
# Grain: one row per proficiency band.

proficiency_band_df = (
    spark.table(f"{catalog}.silver.assessment_results")
    .filter(F.col("batch_id") == batch_id)
    .select("proficiency_band")
    .where(F.col("proficiency_band").isNotNull())
    .distinct()
)

dim_proficiency_band_df = (
    proficiency_band_df
    .withColumn(
        "proficiency_band_key",
        F.sha2(F.coalesce(F.col("proficiency_band"), F.lit("")), 256)
    )
    .withColumn(
        "proficiency_band_sort_order",
        F.when(F.col("proficiency_band") == "Low", F.lit(1))
        .when(F.col("proficiency_band") == "Medium", F.lit(2))
        .when(F.col("proficiency_band") == "High", F.lit(3))
        .otherwise(F.lit(99))
    )
    .withColumn(
        "score_range_label",
        F.when(F.col("proficiency_band") == "Low", F.lit("250 to 399"))
        .when(F.col("proficiency_band") == "Medium", F.lit("400 to 549"))
        .when(F.col("proficiency_band") == "High", F.lit("550 and above"))
        .otherwise(F.lit("Unknown"))
    )
    .withColumn("gold_load_timestamp", F.current_timestamp())
    .select(
        "proficiency_band_key",
        "proficiency_band",
        "proficiency_band_sort_order",
        "score_range_label",
        "gold_load_timestamp"
    )
)

target_path = f"{lake_root}/gold/dim_proficiency_band"

merge_condition = """
target.proficiency_band_key = source.proficiency_band_key
"""

write_delta_table(
    df=dim_proficiency_band_df,
    table_name="gold.dim_proficiency_band",
    target_path=target_path,
    merge_condition=merge_condition
)

display(
    spark.table(f"{catalog}.gold.dim_proficiency_band")
    .orderBy("proficiency_band_sort_order")
)

# COMMAND ----------

# gold.dim_dq_rule
# Grain: one row per data quality rule.

dq_rule_df = spark.table(f"{catalog}.qa.dq_rule_catalog")

dim_dq_rule_df = (
    dq_rule_df
    .select(
        "rule_id",
        "rule_name",
        "target_table",
        "severity",
        "business_rule",
        "expected_outcome"
    )
    .withColumn(
        "dq_rule_key",
        F.sha2(F.coalesce(F.col("rule_id"), F.lit("")), 256)
    )
    .withColumn(
        "severity_sort_order",
        F.when(F.col("severity") == "High", F.lit(1))
         .when(F.col("severity") == "Medium", F.lit(2))
         .when(F.col("severity") == "Low", F.lit(3))
         .otherwise(F.lit(99))
    )
    .withColumn("gold_load_timestamp", F.current_timestamp())
    .select(
        "dq_rule_key",
        "rule_id",
        "rule_name",
        "target_table",
        "severity",
        "severity_sort_order",
        "business_rule",
        "expected_outcome",
        "gold_load_timestamp"
    )
)

target_path = f"{lake_root}/gold/dim_dq_rule"

merge_condition = """
target.dq_rule_key = source.dq_rule_key
"""

write_delta_table(
    df=dim_dq_rule_df,
    table_name="gold.dim_dq_rule",
    target_path=target_path,
    merge_condition=merge_condition
)

display(
    spark.table(f"{catalog}.gold.dim_dq_rule")
    .orderBy("rule_id")
)

# COMMAND ----------

# MAGIC %md
# MAGIC ### gold.fact_attendance, gold.fact_assessment_result, gold.fact_data_quality_result, gold.fact_defect

# COMMAND ----------

# gold.fact_attendance
# Grain: one row per valid attendance record.
# Excludes attendance records failed by DQ003, DQ004, or DQ005.

latest_qa_run_row = (
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("batch_id") == batch_id)
    .orderBy(F.col("run_timestamp").desc())
    .select("run_id")
    .first()
)

if latest_qa_run_row is None:
    raise ValueError(f"No QA run found for batch_id={batch_id}")

latest_qa_run_id = latest_qa_run_row["run_id"]

attendance_df = (
    spark.table(f"{catalog}.silver.attendance")
    .filter(F.col("batch_id") == batch_id)
)

dim_student_keys_df = (
    spark.table(f"{catalog}.gold.dim_student")
    .filter(F.col("batch_id") == batch_id)
    .select(
        "batch_id",
        "student_id",
        "student_key",
        "student_batch_key",
        "year_level_key"
    )
)

dim_school_versions_df = (
    spark.table(f"{catalog}.gold.dim_school")
    .select(
        F.col("school_key").alias("dim_school_key"),
        "school_scd_key",
        "effective_from_date",
        "effective_to_date"
    )
)

invalid_attendance_records_df = (
    spark.table(f"{catalog}.qa.dq_failed_records")
    .filter(
        (F.col("run_id") == latest_qa_run_id)
        & (F.col("batch_id") == batch_id)
        & (F.col("target_table") == "silver.attendance")
        & (F.col("rule_id").isin(["DQ003", "DQ004", "DQ005"]))
    )
    .select("bronze_record_id")
    .distinct()
)

valid_attendance_df = (
    attendance_df
    .join(
        invalid_attendance_records_df,
        on="bronze_record_id",
        how="left_anti"
    )
)

fact_attendance_df = (
    valid_attendance_df.alias("a")
    .withColumn("batch_date", F.to_date(F.lit(batch_id)))
    .withColumn("school_key", F.sha2(F.coalesce(F.col("a.school_id"), F.lit("")), 256))
    .join(
        dim_student_keys_df.alias("stu"),
        on=["batch_id", "student_id"],
        how="left"
    )
    .join(
        dim_school_versions_df.alias("sch"),
        (F.col("school_key") == F.col("sch.dim_school_key"))
        & (F.col("batch_date") >= F.col("sch.effective_from_date"))
        & (
            F.col("sch.effective_to_date").isNull()
            | (F.col("batch_date") <= F.col("sch.effective_to_date"))
        ),
        how="left"
    )
    .withColumn(
        "attendance_fact_key",
        F.sha2(
            F.concat_ws(
                "||",
                F.coalesce(F.col("a.batch_id"), F.lit("")),
                F.coalesce(F.col("a.attendance_id"), F.lit(""))
            ),
            256
        )
    )
    .withColumn("batch_key", F.sha2(F.coalesce(F.col("a.batch_id"), F.lit("")), 256))
    .withColumn(
        "attendance_month_date_key",
        F.date_format(F.col("a.attendance_month"), "yyyyMMdd").cast("int")
    )
    .withColumn(
        "attendance_rate",
        F.when(
            F.col("a.possible_days") > 0,
            F.round(F.col("a.attended_days") / F.col("a.possible_days"), 4)
        ).otherwise(F.lit(None))
    )
    .withColumn("gold_load_timestamp", F.current_timestamp())
    .select(
        "attendance_fact_key",
        "batch_key",
        "school_key",
        "school_scd_key",
        "student_key",
        "student_batch_key",
        "year_level_key",
        "attendance_month_date_key",
        F.col("a.batch_id").alias("batch_id"),
        F.col("a.attendance_id").alias("attendance_id"),
        F.col("a.student_id").alias("student_id"),
        F.col("a.school_id").alias("school_id"),
        F.col("a.attendance_month").alias("attendance_month"),
        F.col("a.possible_days").alias("possible_days"),
        F.col("a.attended_days").alias("attended_days"),
        "attendance_rate",
        F.col("a.absence_reason").alias("absence_reason"),
        F.col("a.bronze_record_id").alias("bronze_record_id"),
        F.col("a.run_id").alias("source_run_id"),
        F.col("a.silver_load_timestamp").alias("silver_load_timestamp"),
        "gold_load_timestamp"
    )
)

target_path = f"{lake_root}/gold/fact_attendance"

merge_condition = """
target.attendance_fact_key = source.attendance_fact_key
"""

write_delta_table(
    df=fact_attendance_df,
    table_name="gold.fact_attendance",
    target_path=target_path,
    merge_condition=merge_condition
)

# COMMAND ----------

display(
    spark.table(f"{catalog}.gold.fact_attendance")
    .groupBy("batch_id")
    .agg(
        F.count("*").alias("fact_attendance_rows"),
        F.countDistinct("attendance_fact_key").alias("distinct_fact_keys"),
        F.sum(F.when(F.col("school_scd_key").isNull(), 1).otherwise(0)).alias("missing_school_scd_key"),
        F.sum(F.when(F.col("student_batch_key").isNull(), 1).otherwise(0)).alias("missing_student_batch_key"),
        F.min("attendance_rate").alias("min_attendance_rate"),
        F.max("attendance_rate").alias("max_attendance_rate")
    )
    .orderBy("batch_id")
)

# COMMAND ----------

# gold.fact_assessment_result
# Grain: one row per valid assessment result.
# Excludes assessment records failed by DQ006, DQ007, or DQ008.

latest_qa_run_row = (
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("batch_id") == batch_id)
    .orderBy(F.col("run_timestamp").desc())
    .select("run_id")
    .first()
)

if latest_qa_run_row is None:
    raise ValueError(f"No QA run found for batch_id={batch_id}")

latest_qa_run_id = latest_qa_run_row["run_id"]

assessment_df = (
    spark.table(f"{catalog}.silver.assessment_results")
    .filter(F.col("batch_id") == batch_id)
)

dim_student_keys_df = (
    spark.table(f"{catalog}.gold.dim_student")
    .filter(F.col("batch_id") == batch_id)
    .select(
        "batch_id",
        "student_id",
        "student_key",
        "student_batch_key",
        "school_key",
        "school_scd_key"
    )
)

dim_domain_df = (
    spark.table(f"{catalog}.gold.dim_assessment_domain")
    .select(
        "domain",
        "domain_key"
    )
)

dim_proficiency_band_df = (
    spark.table(f"{catalog}.gold.dim_proficiency_band")
    .select(
        "proficiency_band",
        "proficiency_band_key"
    )
)

invalid_assessment_records_df = (
    spark.table(f"{catalog}.qa.dq_failed_records")
    .filter(
        (F.col("run_id") == latest_qa_run_id)
        & (F.col("batch_id") == batch_id)
        & (F.col("target_table") == "silver.assessment_results")
        & (F.col("rule_id").isin(["DQ006", "DQ007", "DQ008"]))
    )
    .select("bronze_record_id")
    .distinct()
)

valid_assessment_df = (
    assessment_df
    .join(
        invalid_assessment_records_df,
        on="bronze_record_id",
        how="left_anti"
    )
)

fact_assessment_result_df = (
    valid_assessment_df.alias("a")
    .join(
        dim_student_keys_df.alias("stu"),
        on=["batch_id", "student_id"],
        how="left"
    )
    .join(
        dim_domain_df.alias("dom"),
        F.col("a.domain") == F.col("dom.domain"),
        how="left"
    )
    .join(
        dim_proficiency_band_df.alias("band"),
        F.col("a.proficiency_band") == F.col("band.proficiency_band"),
        how="left"
    )
    .withColumn(
        "assessment_fact_key",
        F.sha2(
            F.concat_ws(
                "||",
                F.coalesce(F.col("a.batch_id"), F.lit("")),
                F.coalesce(F.col("a.assessment_id"), F.lit(""))
            ),
            256
        )
    )
    .withColumn("batch_key", F.sha2(F.coalesce(F.col("a.batch_id"), F.lit("")), 256))
    .withColumn(
        "assessment_year_date_key",
        F.date_format(
            F.to_date(F.concat(F.col("a.assessment_year").cast("string"), F.lit("-01-01"))),
            "yyyyMMdd"
        ).cast("int")
    )
    .withColumn("gold_load_timestamp", F.current_timestamp())
    .select(
        "assessment_fact_key",
        "batch_key",
        "school_key",
        "school_scd_key",
        "student_key",
        "student_batch_key",
        "domain_key",
        "proficiency_band_key",
        "assessment_year_date_key",
        F.col("a.batch_id").alias("batch_id"),
        F.col("a.assessment_id").alias("assessment_id"),
        F.col("a.student_id").alias("student_id"),
        F.col("a.school_id").alias("school_id"),
        F.col("a.assessment_year").alias("assessment_year"),
        F.col("a.domain").alias("domain"),
        F.col("a.score").alias("score"),
        F.col("a.proficiency_band").alias("proficiency_band"),
        F.col("a.bronze_record_id").alias("bronze_record_id"),
        F.col("a.run_id").alias("source_run_id"),
        F.col("a.silver_load_timestamp").alias("silver_load_timestamp"),
        "gold_load_timestamp"
    )
)

target_path = f"{lake_root}/gold/fact_assessment_result"

merge_condition = """
target.assessment_fact_key = source.assessment_fact_key
"""

write_delta_table(
    df=fact_assessment_result_df,
    table_name="gold.fact_assessment_result",
    target_path=target_path,
    merge_condition=merge_condition
)

display(
    spark.table(f"{catalog}.gold.fact_assessment_result")
    .groupBy("batch_id")
    .agg(
        F.count("*").alias("fact_assessment_rows"),
        F.countDistinct("assessment_fact_key").alias("distinct_fact_keys"),
        F.sum(F.when(F.col("school_scd_key").isNull(), 1).otherwise(0)).alias("missing_school_scd_key"),
        F.sum(F.when(F.col("student_batch_key").isNull(), 1).otherwise(0)).alias("missing_student_batch_key"),
        F.sum(F.when(F.col("domain_key").isNull(), 1).otherwise(0)).alias("missing_domain_key"),
        F.sum(F.when(F.col("proficiency_band_key").isNull(), 1).otherwise(0)).alias("missing_proficiency_band_key"),
        F.min("score").alias("min_score"),
        F.max("score").alias("max_score")
    )
    .orderBy("batch_id")
)

# COMMAND ----------

# gold.fact_data_quality_result
# Grain: one row per data quality rule result per batch for the latest QA run.

latest_qa_run_row = (
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("batch_id") == batch_id)
    .orderBy(F.col("run_timestamp").desc())
    .select("run_id")
    .first()
)

if latest_qa_run_row is None:
    raise ValueError(f"No QA run found for batch_id={batch_id}")

latest_qa_run_id = latest_qa_run_row["run_id"]

dq_results_df = (
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(
        (F.col("batch_id") == batch_id)
        & (F.col("run_id") == latest_qa_run_id)
    )
)

dim_dq_rule_df = (
    spark.table(f"{catalog}.gold.dim_dq_rule")
    .select(
        "rule_id",
        "dq_rule_key",
        "severity_sort_order"
    )
)

fact_data_quality_result_df = (
    dq_results_df.alias("dq")
    .join(
        dim_dq_rule_df.alias("rule"),
        on="rule_id",
        how="left"
    )
    .withColumn(
        "dq_result_fact_key",
        F.sha2(
            F.concat_ws(
                "||",
                F.coalesce(F.col("dq.run_id"), F.lit("")),
                F.coalesce(F.col("dq.batch_id"), F.lit("")),
                F.coalesce(F.col("dq.rule_id"), F.lit(""))
            ),
            256
        )
    )
    .withColumn("batch_key", F.sha2(F.coalesce(F.col("dq.batch_id"), F.lit("")), 256))
    .withColumn(
        "status_sort_order",
        F.when(F.col("dq.status") == "FAIL", F.lit(1))
        .when(F.col("dq.status") == "WARN", F.lit(2))
        .when(F.col("dq.status") == "PASS", F.lit(3))
        .otherwise(F.lit(9))
    )
    .withColumn(
        "issue_flag",
        F.when(F.col("dq.status").isin("FAIL", "WARN"), F.lit(1)).otherwise(F.lit(0))
    )
    .withColumn("gold_load_timestamp", F.current_timestamp())
    .select(
        "dq_result_fact_key",
        "batch_key",
        "dq_rule_key",
        F.col("dq.run_id").alias("run_id"),
        F.col("dq.batch_id").alias("batch_id"),
        F.col("dq.rule_id").alias("rule_id"),
        F.col("dq.rule_name").alias("rule_name"),
        F.col("dq.target_table").alias("target_table"),
        F.col("dq.severity").alias("severity"),
        "severity_sort_order",
        F.col("dq.status").alias("status"),
        "status_sort_order",
        F.col("dq.failed_record_count").alias("failed_record_count"),
        "issue_flag",
        F.col("dq.run_timestamp").alias("run_timestamp"),
        "gold_load_timestamp"
    )
)

target_path = f"{lake_root}/gold/fact_data_quality_result"

merge_condition = """
target.dq_result_fact_key = source.dq_result_fact_key
"""

write_delta_table(
    df=fact_data_quality_result_df,
    table_name="gold.fact_data_quality_result",
    target_path=target_path,
    merge_condition=merge_condition
)

display(
    spark.table(f"{catalog}.gold.fact_data_quality_result")
    .groupBy("batch_id")
    .agg(
        F.count("*").alias("dq_result_rows"),
        F.countDistinct("dq_result_fact_key").alias("distinct_fact_keys"),
        F.sum("failed_record_count").alias("failed_record_count"),
        F.sum("issue_flag").alias("issue_rule_results"),
        F.sum(F.when(F.col("dq_rule_key").isNull(), 1).otherwise(0)).alias("missing_dq_rule_key")
    )
    .orderBy("batch_id")
)

# COMMAND ----------

# gold.fact_defect
# Grain: one row per defect per batch for the latest QA run.

latest_qa_run_row = (
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("batch_id") == batch_id)
    .orderBy(F.col("run_timestamp").desc())
    .select("run_id")
    .first()
)

if latest_qa_run_row is None:
    raise ValueError(f"No QA run found for batch_id={batch_id}")

latest_qa_run_id = latest_qa_run_row["run_id"]

defect_df = (
    spark.table(f"{catalog}.qa.defect_log")
    .filter(
        (F.col("batch_id") == batch_id)
        & (F.col("run_id") == latest_qa_run_id)
    )
)

dim_dq_rule_df = (
    spark.table(f"{catalog}.gold.dim_dq_rule")
    .select(
        "rule_id",
        "dq_rule_key",
        "rule_name",
        "target_table",
        "severity_sort_order"
    )
)

fact_defect_df = (
    defect_df.alias("d")
    .join(
        dim_dq_rule_df.alias("rule"),
        on="rule_id",
        how="left"
    )
    .withColumn(
        "defect_fact_key",
        F.sha2(
            F.concat_ws(
                "||",
                F.coalesce(F.col("d.defect_id"), F.lit("")),
                F.coalesce(F.col("d.run_id"), F.lit(""))
            ),
            256
        )
    )
    .withColumn("batch_key", F.sha2(F.coalesce(F.col("d.batch_id"), F.lit("")), 256))
    .withColumn(
        "defect_status_sort_order",
        F.when(F.col("d.defect_status") == "Open", F.lit(1))
        .when(F.col("d.defect_status") == "In Progress", F.lit(2))
        .when(F.col("d.defect_status") == "Resolved", F.lit(3))
        .when(F.col("d.defect_status") == "Closed", F.lit(4))
        .otherwise(F.lit(9))
    )
    .withColumn(
        "open_defect_flag",
        F.when(F.col("d.defect_status") == "Open", F.lit(1)).otherwise(F.lit(0))
    )
    .withColumn("gold_load_timestamp", F.current_timestamp())
    .select(
        "defect_fact_key",
        "batch_key",
        "dq_rule_key",
        F.col("d.defect_id").alias("defect_id"),
        F.col("d.run_id").alias("run_id"),
        F.col("d.batch_id").alias("batch_id"),
        F.col("d.rule_id").alias("rule_id"),
        F.col("rule.rule_name").alias("rule_name"),
        F.col("rule.target_table").alias("target_table"),
        F.col("d.severity").alias("severity"),
        "severity_sort_order",
        F.col("d.defect_title").alias("defect_title"),
        F.col("d.defect_status").alias("defect_status"),
        "defect_status_sort_order",
        "open_defect_flag",
        F.col("d.failed_record_count").alias("failed_record_count"),
        F.col("d.recommended_action").alias("recommended_action"),
        F.col("d.created_timestamp").alias("created_timestamp"),
        "gold_load_timestamp"
    )
)

target_path = f"{lake_root}/gold/fact_defect"

merge_condition = """
target.defect_fact_key = source.defect_fact_key
"""

write_delta_table(
    df=fact_defect_df,
    table_name="gold.fact_defect",
    target_path=target_path,
    merge_condition=merge_condition
)

display(
    spark.table(f"{catalog}.gold.fact_defect")
    .groupBy("batch_id")
    .agg(
        F.count("*").alias("defect_rows"),
        F.countDistinct("defect_fact_key").alias("distinct_fact_keys"),
        F.sum("failed_record_count").alias("defect_failed_record_count"),
        F.sum("open_defect_flag").alias("open_defects"),
        F.sum(F.when(F.col("dq_rule_key").isNull(), 1).otherwise(0)).alias("missing_dq_rule_key")
    )
    .orderBy("batch_id")
)

# COMMAND ----------

# MAGIC %md
# MAGIC ### gold.data_quality_summary, gold.data_quality_rule_detail

# COMMAND ----------

dq_results_df = (
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("run_id") == run_id)
)

data_quality_summary_df = (
    dq_results_df
    .groupBy(
        "run_id",
        "batch_id",
        "severity",
        "status",
    )
    .agg(
        F.countDistinct("rule_id").alias("rule_count"),
        F.sum("failed_record_count").alias("failed_record_count")
    )
    .withColumn("gold_load_timestamp", F.current_timestamp())
)

target_path = f"{lake_root}/gold/data_quality_summary"


merge_condition = """
target.run_id = source.run_id
AND target.batch_id = source.batch_id
AND target.severity = source.severity
AND target.status = source.status
"""

write_delta_table(
    data_quality_summary_df, 
    "gold.data_quality_summary", 
    target_path,
    merge_condition
)

display(
    spark.table(f"{catalog}.gold.data_quality_summary")
    .orderBy("batch_id", "severity", "status")
)

# COMMAND ----------

# gold.data_quality_rule_detail

dq_results_df = (
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("run_id") == run_id)
)

data_quality_rule_detail_df = (
    dq_results_df
    .select(
        "run_id",
        "batch_id",
        "rule_id",
        "rule_name",
        "target_table",
        "severity",
        "status",
        "failed_record_count",
        "run_timestamp"
    )
    .withColumn("gold_load_timestamp", F.current_timestamp())
)

target_path = f"{lake_root}/gold/data_quality_rule_detail"

merge_condition = """
target.run_id = source.run_id
AND target.batch_id = source.batch_id
AND target.rule_id = source.rule_id
"""

write_delta_table(
    df=data_quality_rule_detail_df,
    table_name="gold.data_quality_rule_detail",
    target_path=target_path,
    merge_condition=merge_condition
)

display(
    spark.table(f"{catalog}.gold.data_quality_rule_detail")
    .orderBy("rule_id", "batch_id")
)

# COMMAND ----------

# MAGIC %md
# MAGIC ### gold.attendance_by_school_month, gold.attendance_by_year_level

# COMMAND ----------

# gold.attendance_by_school_month

attendance_df = (
    spark.table(f"{catalog}.silver.attendance")
    .filter(F.col("batch_id") == batch_id)
)
schools_df = (
    spark.table(f"{catalog}.silver.schools")
    .filter(F.col("batch_id") == batch_id)
)

invalid_attendance_records_df = (
    spark.table(f"{catalog}.qa.dq_failed_records")
    .filter(
        (F.col("run_id") == run_id)
        & (F.col("target_table") == "silver.attendance")
        & (F.col("rule_id").isin(["DQ003", "DQ004", "DQ005"]))
    )
    .select("bronze_record_id")
    .distinct()
)

valid_attendance_df = (
    attendance_df.alias("a")
    .join(
        invalid_attendance_records_df.alias("bad"),
        on="bronze_record_id",
        how="left_anti"
    )
)

attendance_by_school_month_df = (
    valid_attendance_df.alias("a")
    .join(
        schools_df.select(
            "batch_id",
            "school_id",
            "school_name",
            "region",
            "school_type",
            "status"
        ).alias("s"),
        on=["batch_id", "school_id"],
        how="left"
    )
    .groupBy(
        "batch_id",
        "school_id",
        "school_name",
        "region",
        "school_type",
        "attendance_month"
    )
    .agg(
        F.sum("possible_days").alias("possible_days"),
        F.sum("attended_days").alias("attended_days"),
        F.countDistinct("student_id").alias("student_count")
    )
    .withColumn(
        "attendance_rate",
        F.when(
            F.col("possible_days") > 0,
            F.round(F.col("attended_days") / F.col("possible_days"), 4)
        ).otherwise(F.lit(None))
    )
    .withColumn("gold_load_timestamp", F.current_timestamp())
)


target_path = f"{lake_root}/gold/attendance_by_school_month"

merge_condition = """
target.batch_id = source.batch_id
AND target.school_id = source.school_id
AND target.attendance_month = source.attendance_month
"""

write_delta_table(
    df=attendance_by_school_month_df,
    table_name="gold.attendance_by_school_month",
    target_path=target_path,
    merge_condition=merge_condition
)

display(
    spark.table(f"{catalog}.gold.attendance_by_school_month")
    .orderBy("batch_id", "school_id", "attendance_month")
    .limit(50)
)

# COMMAND ----------

(
    spark.table(f"{catalog}.gold.attendance_by_school_month")
    .groupBy("batch_id")
    .agg(
        F.count("*").alias("school_month_rows"),
        F.min("attendance_rate").alias("min_attendance_rate"),
        F.max("attendance_rate").alias("max_attendance_rate")
    )
    .orderBy("batch_id")
    .show()
)

# COMMAND ----------

(
    valid_attendance_df
    .groupBy("batch_id")
    .agg(
        F.countDistinct("school_id").alias("schools_with_valid_attendance"),
        F.countDistinct("attendance_month").alias("attendance_months")
    )
    .orderBy("batch_id")
    .show()
)

# COMMAND ----------

# gold.attendance_by_year_level

attendance_df = (
    spark.table(f"{catalog}.silver.attendance")
    .filter(F.col("batch_id") == batch_id)
)
students_df = (
    spark.table(f"{catalog}.silver.students")
    .filter(F.col("batch_id") == batch_id)
)

invalid_attendance_records_df = (
    spark.table(f"{catalog}.qa.dq_failed_records")
    .filter(
        (F.col("run_id") == run_id)
        & (F.col("target_table") == "silver.attendance")
        & (F.col("rule_id").isin(["DQ003", "DQ004", "DQ005"]))
    )
    .select("bronze_record_id")
    .distinct()
)

valid_attendance_df = (
    attendance_df
    .join(
        invalid_attendance_records_df,
        on="bronze_record_id",
        how="left_anti"
    )
)


attendance_by_year_level_df = (
    valid_attendance_df.alias("a")
    .join(
        students_df.select(
            "batch_id",
            "student_id",
            "year_level",
            "status"
        ).alias("s"),
        on=["batch_id", "student_id"],
        how="left"
    )
    .groupBy(
        "batch_id",
        "year_level",
        "attendance_month"
    )
    .agg(
        F.sum("possible_days").alias("possible_days"),
        F.sum("attended_days").alias("attended_days"),
        F.countDistinct("student_id").alias("student_count")
    )
    .withColumn(
        "attendance_rate",
        F.when(
            F.col("possible_days") > 0,
            F.round(F.col("attended_days") / F.col("possible_days"), 4)
        ).otherwise(F.lit(None))
    )
    .withColumn("gold_load_timestamp", F.current_timestamp())
)

target_path = f"{lake_root}/gold/attendance_by_year_level"

merge_condition = """
target.batch_id = source.batch_id
AND target.year_level = source.year_level
AND target.attendance_month = source.attendance_month
"""

write_delta_table(
    df=attendance_by_year_level_df,
    table_name="gold.attendance_by_year_level",
    target_path=target_path,
    merge_condition=merge_condition
)

display(
    spark.table(f"{catalog}.gold.attendance_by_year_level")
    .orderBy("batch_id", "year_level", "attendance_month")
    .limit(50)
)

# COMMAND ----------

(
    spark.table(f"{catalog}.gold.attendance_by_year_level")
    .groupBy("batch_id")
    .agg(
        F.count("*").alias("year_level_month_rows"),
        F.min("attendance_rate").alias("min_attendance_rate"),
        F.max("attendance_rate").alias("max_attendance_rate")
    )
    .orderBy("batch_id")
    .show()
)

# COMMAND ----------

# MAGIC %md
# MAGIC ### gold.assessment_by_school, gold.assessment_by_domain

# COMMAND ----------

# gold.assessment_by_school

assessment_df = (
    spark.table(f"{catalog}.silver.assessment_results")
    .filter(F.col("batch_id") == batch_id))
schools_df = (
    spark.table(f"{catalog}.silver.schools")
    .filter(F.col("batch_id") == batch_id))

invalid_assessment_records_df = (
    spark.table(f"{catalog}.qa.dq_failed_records")
    .filter(
        (F.col("run_id") == run_id)
        & (F.col("target_table") == "silver.assessment_results")
        & (F.col("rule_id").isin(["DQ006", "DQ007", "DQ008"]))
    )
    .select("bronze_record_id")
    .distinct()
)

valid_assessment_df = (
    assessment_df
    .join(
        invalid_assessment_records_df,
        on="bronze_record_id",
        how="left_anti"
    )
)

assessment_by_school_df = (
    valid_assessment_df.alias("a")
    .join(
        schools_df.select(
            "batch_id",
            "school_id",
            "school_name",
            "region",
            "school_type",
            "status"
        ).alias("s"),
        on=["batch_id", "school_id"],
        how="left"
    )
    .groupBy(
        "batch_id",
        "assessment_year",
        "school_id",
        "school_name",
        "region",
        "school_type"
    )
    .agg(
        F.countDistinct("assessment_id").alias("assessment_count"),
        F.countDistinct("student_id").alias("student_count"),
        F.round(F.avg("score"), 2).alias("average_score"),
        F.round(F.expr("percentile_approx(score, 0.5)"), 2).alias("median_score"),
        F.min("score").alias("min_score"),
        F.max("score").alias("max_score")
    )
    .withColumn("gold_load_timestamp", F.current_timestamp())
)

target_path = f"{lake_root}/gold/assessment_by_school"

merge_condition = """
target.batch_id = source.batch_id
AND target.assessment_year = source.assessment_year
AND target.school_id = source.school_id
"""

write_delta_table(
    df=assessment_by_school_df,
    table_name="gold.assessment_by_school",
    target_path=target_path,
    merge_condition=merge_condition
)

display(
    spark.table(f"{catalog}.gold.assessment_by_school")
    .orderBy("batch_id", "assessment_year", "school_id")
    .limit(50)
)

# COMMAND ----------

(
    spark.table(f"{catalog}.gold.assessment_by_school")
    .groupBy("batch_id")
    .agg(
        F.count("*").alias("school_assessment_rows"),
        F.min("average_score").alias("min_average_score"),
        F.max("average_score").alias("max_average_score")
    )
    .orderBy("batch_id")
    .show()
)

# COMMAND ----------

# gold.assessment_by_domain

assessment_df = (
    spark.table(f"{catalog}.silver.assessment_results")
    .filter(F.col("batch_id") == batch_id)
)

invalid_assessment_records_df = (
    spark.table(f"{catalog}.qa.dq_failed_records")
    .filter(
        (F.col("run_id") == run_id)
        & (F.col("target_table") == "silver.assessment_results")
        & (F.col("rule_id").isin(["DQ006", "DQ007", "DQ008"]))
    )
    .select("bronze_record_id")
    .distinct()
)

valid_assessment_df = (
    assessment_df
    .join(
        invalid_assessment_records_df,
        on="bronze_record_id",
        how="left_anti"
    )
)

assessment_by_domain_df = (
    valid_assessment_df
    .groupBy(
        "batch_id",
        "assessment_year",
        "domain",
        "proficiency_band"
    )
    .agg(
        F.countDistinct("assessment_id").alias("assessment_count"),
        F.countDistinct("student_id").alias("student_count"),
        F.round(F.avg("score"), 2).alias("average_score"),
        F.round(F.expr("percentile_approx(score, 0.5)"), 2).alias("median_score"),
        F.min("score").alias("min_score"),
        F.max("score").alias("max_score")
    )
    .withColumn("gold_load_timestamp", F.current_timestamp())
)

target_path = f"{lake_root}/gold/assessment_by_domain"

merge_condition = """
target.batch_id = source.batch_id
AND target.assessment_year = source.assessment_year
AND target.domain = source.domain
AND target.proficiency_band = source.proficiency_band
"""

write_delta_table(
    df=assessment_by_domain_df,
    table_name="gold.assessment_by_domain",
    target_path=target_path,
    merge_condition=merge_condition
)

display(
    spark.table(f"{catalog}.gold.assessment_by_domain")
    .orderBy("batch_id", "assessment_year", "domain", "proficiency_band")
)

# COMMAND ----------

(
    spark.table(f"{catalog}.gold.assessment_by_domain")
    .groupBy("batch_id")
    .agg(
        F.count("*").alias("domain_band_rows"),
        F.min("average_score").alias("min_average_score"),
        F.max("average_score").alias("max_average_score")
    )
    .orderBy("batch_id")
    .show()
)

# COMMAND ----------

# Validation

gold_tables = [
    "data_quality_summary",
    "data_quality_rule_detail",
    "attendance_by_school_month",
    "attendance_by_year_level",
    "assessment_by_school",
    "assessment_by_domain"
]

gold_validation_dfs = []

for table_name in gold_tables:
    df = spark.table(f"{catalog}.gold.{table_name}")

    validation_df = (
        df.groupBy("batch_id")
        .agg(F.count("*").alias("row_count"))
        .withColumn("gold_table", F.lit(table_name))
        .select("gold_table", "batch_id", "row_count")
    )

    gold_validation_dfs.append(validation_df)

gold_output_validation_df = reduce(
    lambda df1, df2: df1.unionByName(df2),
    gold_validation_dfs
)

display(
    gold_output_validation_df
    .orderBy("gold_table", "batch_id")
)

# COMMAND ----------

