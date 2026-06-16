# Databricks notebook source
from pyspark.sql import functions as F
from pyspark.sql import types as T
from functools import reduce
from delta.tables import DeltaTable
from pyspark.sql import Window

from datetime import datetime, timezone

# COMMAND ----------

dbutils.widgets.text("environment", "dev")
dbutils.widgets.text("batch_id", "2025-01-15")
dbutils.widgets.dropdown("run_mode", "initial", ["initial", "incremental"])
dbutils.widgets.text("job_run_id", "")

environment = dbutils.widgets.get("environment")
batch_id = dbutils.widgets.get("batch_id")
run_mode = dbutils.widgets.get("run_mode")


pipeline_name = "education_qa_pipeline"

job_run_id = dbutils.widgets.get("job_run_id")

if job_run_id:
    run_id = f"{environment}_education_qa_pipeline_{batch_id}_{run_mode}_job_{job_run_id}"
else:
    run_timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_id = f"{environment}_{pipeline_name}_{batch_id}_{run_mode}_{run_timestamp}"

if run_mode == "initial":
    write_mode = "overwrite"
elif run_mode == "incremental":
    write_mode = "append"
else:
    raise ValueError(f"Unsupported run_mode: {run_mode}")

catalog = "dbw_edu_qa_dev"
storage_account = "steduqadblakehouse"
container = "education-data-lake"

lake_root = f"abfss://{container}@{storage_account}.dfs.core.windows.net"

print(f"environment: {environment}")
print(f"batch_id: {batch_id}")
print(f"run_mode: {run_mode}")
print(f"write_mode: {write_mode}")
print(f"job_run_id: {job_run_id}")
print(f"run_id: {run_id}")

# COMMAND ----------

bronze_tables = [
    "schools",
    "students",
    "attendance",
    "assessment_results",
    "school_events"
]

for table_name in bronze_tables:
    print(f"\n=== {catalog}.bronze.{table_name} ===")
    spark.table(f"{catalog}.bronze.{table_name}").printSchema()

# COMMAND ----------

# Idempotency guard for incremental Silver loads.
# If the same batch is rerun, remove existing Silver rows for that batch before appending replacement rows.

silver_target_tables = [
    "schools",
    "students",
    "attendance",
    "assessment_results",
    "school_events"
]

def table_exists(schema_name, table_name):
    return (
        spark.sql(f"SHOW TABLES IN {catalog}.{schema_name} LIKE '{table_name}'")
        .count() > 0
    )

if run_mode == "incremental":
    for table_name in silver_target_tables:
        if table_exists("silver", table_name):
            spark.sql(
                f"""
                DELETE FROM {catalog}.silver.{table_name}
                WHERE batch_id = '{batch_id}'
                """
            )
            print(f"Deleted existing Silver rows for batch_id={batch_id} from silver.{table_name}")
        else:
            print(f"Skipped delete because silver.{table_name} does not exist yet")


# COMMAND ----------

def dedupe_latest_bronze_batch(df, business_key_columns):
    """Keep one latest Bronze row per batch and business key."""
    dedupe_window = (
        Window
        .partitionBy(["batch_id"] + business_key_columns)
        .orderBy(
            F.col("load_timestamp").desc(),
            F.col("run_id").desc(),
            F.col("bronze_record_id").desc()
        )
    )

    return (
        df
        .withColumn("silver_dedupe_row_number", F.row_number().over(dedupe_window))
        .filter(F.col("silver_dedupe_row_number") == 1)
        .drop("silver_dedupe_row_number")
    )

# COMMAND ----------

# MAGIC %md
# MAGIC ### silver schema

# COMMAND ----------

# silver.schools

target_path = f"{lake_root}/silver/schools"


schools_silver_df = (
    dedupe_latest_bronze_batch(
        spark.table(f"{catalog}.bronze.schools")
        .filter(F.col("batch_id") == batch_id),
        ["school_id"]
    )
    .select(
        F.trim(F.col("school_id")).alias("school_id"),
        F.trim(F.col("school_name")).alias("school_name"),
        F.trim(F.col("region")).alias("region"),
        F.trim(F.col("school_type")).alias("school_type"),
        F.to_date(F.col("open_date"), "yyyy-MM-dd").alias("open_date"),
        F.trim(F.col("status")).alias("status"),
        F.col("batch_id"),
        F.col("run_id"),
        F.col("load_timestamp"),
        F.col("source_file_name"),
        F.col("bronze_record_id")
    )
    .withColumn("silver_load_timestamp", F.current_timestamp())
)

writer = (
    schools_silver_df.write
    .format("delta")
    .mode(write_mode)
    .option("path", target_path)
)

if write_mode == "overwrite":
    writer = writer.option("overwriteSchema", "true").partitionBy("batch_id")
    
writer.saveAsTable(f"{catalog}.silver.schools")

display(
    spark.table(f"{catalog}.silver.schools")
    .orderBy("batch_id", "school_id")
    .limit(20)
)

# COMMAND ----------

spark.table(f"{catalog}.silver.schools").printSchema()

(
    spark.table(f"{catalog}.silver.schools")
    .groupBy("batch_id")
    .count()
    .orderBy("batch_id")
    .show()
)

# COMMAND ----------

# silver.students

target_path = f"{lake_root}/silver/students"

students_silver_df = (
    dedupe_latest_bronze_batch(
        spark.table(f"{catalog}.bronze.students")
        .filter(F.col("batch_id") == batch_id),
        ["student_id"]
    )
    .select(
        F.trim(F.col("student_id")).alias("student_id"),
        F.trim(F.col("school_id")).alias("school_id"),
        F.col("year_level").cast("int").alias("year_level"),
        F.trim(F.col("gender")).alias("gender"),
        F.to_date(F.col("enrolment_date"), "yyyy-MM-dd").alias("enrolment_date"),
        F.trim(F.col("status")).alias("status"),
        F.col("batch_id"),
        F.col("run_id"),
        F.col("load_timestamp"),
        F.col("source_file_name"),
        F.col("bronze_record_id")
    )
    .withColumn("silver_load_timestamp", F.current_timestamp())
)

writer = (
    students_silver_df.write
    .format("delta")
    .mode(write_mode)
    .option("path", target_path)
)

if write_mode == "overwrite":
    writer = writer.option("overwriteSchema", "true").partitionBy("batch_id")
    
writer.saveAsTable(f"{catalog}.silver.students")

display(
    spark.table(f"{catalog}.silver.students")
    .orderBy("batch_id", "student_id")
    .limit(20)
)

# COMMAND ----------

spark.table(f"{catalog}.silver.students").printSchema()

(
    spark.table(f"{catalog}.silver.students")
    .groupBy("batch_id")
    .count()
    .orderBy("batch_id")
    .show()
)

# COMMAND ----------

# silver.attendance

target_path = f"{lake_root}/silver/attendance"

attendance_silver_df = (
    dedupe_latest_bronze_batch(
        spark.table(f"{catalog}.bronze.attendance")
        .filter(F.col("batch_id") == batch_id),
        ["attendance_id"]
    )
    .select(
        F.trim(F.col("attendance_id")).alias("attendance_id"),
        F.trim(F.col("student_id")).alias("student_id"),
        F.trim(F.col("school_id")).alias("school_id"),
        F.to_date(F.col("attendance_month"), "yyyy-MM-dd").alias("attendance_month"),
        F.col("possible_days").cast("int").alias("possible_days"),
        F.col("attended_days").cast("int").alias("attended_days"),
        F.trim(F.col("absence_reason")).alias("absence_reason"),
        F.col("batch_id"),
        F.col("run_id"),
        F.col("load_timestamp"),
        F.col("source_file_name"),
        F.col("bronze_record_id")
    )
    .withColumn("silver_load_timestamp", F.current_timestamp())
)

writer = (
    attendance_silver_df.write
    .format("delta")
    .mode(write_mode)
    .option("path", target_path)
)

if write_mode == "overwrite":
    writer = writer.option("overwriteSchema", "true").partitionBy("batch_id")
    
writer.saveAsTable(f"{catalog}.silver.attendance")

display(
    spark.table(f"{catalog}.silver.attendance")
    .orderBy("batch_id", "attendance_id")
    .limit(20)
)

# COMMAND ----------

spark.table(f"{catalog}.silver.attendance").printSchema()

(
    spark.table(f"{catalog}.silver.attendance")
    .groupBy("batch_id")
    .count()
    .orderBy("batch_id")
    .show()
)

# COMMAND ----------

# silver.assessment_results

target_path = f"{lake_root}/silver/assessment_results"

assessment_results_silver_df  = (
    dedupe_latest_bronze_batch(
        spark.table(f"{catalog}.bronze.assessment_results")
        .filter(F.col("batch_id") == batch_id),
        ["assessment_id"]
    )
    .select(
        F.trim(F.col("assessment_id")).alias("assessment_id"),
        F.trim(F.col("student_id")).alias("student_id"),
        F.trim(F.col("school_id")).alias("school_id"),
        F.col("assessment_year").cast("int").alias("assessment_year"),
        F.trim(F.col("domain")).alias("domain"),
        F.col("score").cast("int").alias("score"),
        F.trim(F.col("proficiency_band")).alias("proficiency_band"),
        F.col("batch_id"),
        F.col("run_id"),
        F.col("load_timestamp"),
        F.col("source_file_name"),
        F.col("bronze_record_id")
    )
    .withColumn("silver_load_timestamp", F.current_timestamp())
)

writer = (
    assessment_results_silver_df .write
    .format("delta")
    .mode(write_mode)
    .option("path", target_path)
)

if write_mode == "overwrite":
    writer = writer.option("overwriteSchema", "true").partitionBy("batch_id")
    
writer.saveAsTable(f"{catalog}.silver.assessment_results")

display(
    spark.table(f"{catalog}.silver.assessment_results")
    .orderBy("batch_id", "assessment_id")
    .limit(20)
)

# COMMAND ----------

spark.table(f"{catalog}.silver.assessment_results").printSchema()

(
    spark.table(f"{catalog}.silver.assessment_results")
    .groupBy("batch_id")
    .count()
    .orderBy("batch_id")
    .show()
)

# COMMAND ----------

# silver.school_events

target_path = f"{lake_root}/silver/school_events"

school_events_silver_df = (
    dedupe_latest_bronze_batch(
        spark.table(f"{catalog}.bronze.school_events")
        .filter(F.col("batch_id") == batch_id),
        ["event_id"]
    )
    .select(
        F.trim(F.col("event_id")).alias("event_id"),
        F.trim(F.col("school_id")).alias("school_id"),
        F.to_date(F.col("event_date"), "yyyy-MM-dd").alias("event_date"),
        F.trim(F.col("event_type")).alias("event_type"),
        F.trim(F.col("description")).alias("description"),
        F.col("batch_id"),
        F.col("run_id"),
        F.col("load_timestamp"),
        F.col("source_file_name"),
        F.col("bronze_record_id")
    )
    .withColumn("silver_load_timestamp", F.current_timestamp())
)

writer = (
    school_events_silver_df.write
    .format("delta")
    .mode(write_mode)
    .option("path", target_path)
)

if write_mode == "overwrite":
    writer = writer.option("overwriteSchema", "true").partitionBy("batch_id")

writer.saveAsTable(f"{catalog}.silver.school_events")

display(
    spark.table(f"{catalog}.silver.school_events")
    .orderBy("batch_id", "event_id")
    .limit(20)
)

# COMMAND ----------

spark.table(f"{catalog}.silver.school_events").printSchema()

(
    spark.table(f"{catalog}.silver.school_events")
    .groupBy("batch_id")
    .count()
    .orderBy("batch_id")
    .show()
)

# COMMAND ----------

# Validation

silver_tables = [
    "schools",
    "students",
    "attendance",
    "assessment_results",
    "school_events"
]

count_dfs = []

for table_name in silver_tables:
    count_df = (
        spark.table(f"{catalog}.silver.{table_name}")
        .groupBy("batch_id")
        .count()
        .withColumn("table_name", F.lit(table_name))
        .select("table_name", "batch_id", "count")
    )

    count_dfs.append(count_df)

silver_count_summary = reduce(
    lambda df1, df2: df1.unionByName(df2),
    count_dfs
)

display(
    silver_count_summary
    .orderBy("table_name", "batch_id")
)

# COMMAND ----------

# MAGIC %md
# MAGIC ### Reconciliation

# COMMAND ----------

tables = [
    "schools",
    "students",
    "attendance",
    "assessment_results",
    "school_events"
]

reconciliation_dfs = []


# COMMAND ----------

for table_name in tables:
    bronze_counts = (
        spark.table(f"{catalog}.bronze.{table_name}")
        .groupBy("batch_id")
        .count()
        .withColumnRenamed("count", "bronze_count")
    )

    silver_counts = (
        spark.table(f"{catalog}.silver.{table_name}")
        .groupBy("batch_id")
        .count()
        .withColumnRenamed("count", "silver_count")
    )

    reconciliation_df = (
        bronze_counts
        .join(silver_counts, on="batch_id", how="full")
        .withColumn("table_name", F.lit(table_name))
        .withColumn("reconciliation_timestamp", F.current_timestamp())
        .withColumn(
            "reconciliation_status",
            F.when(F.col("bronze_count") == F.col("silver_count"), F.lit("PASS"))
                .otherwise(F.lit("FAIL"))
        )
        .select(
            "table_name",
            "batch_id",
            "bronze_count",
            "silver_count",
            "reconciliation_status",
            "reconciliation_timestamp"
        )
    )

    reconciliation_dfs.append(reconciliation_df)

row_count_reconciliation_df = reduce(
    lambda df1, df2: df1.unionByName(df2),
    reconciliation_dfs
)

target_path = f"{lake_root}/qa/row_count_reconciliation"

(
    row_count_reconciliation_df.write
    .format("delta")
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .option("path", target_path)
    .saveAsTable(f"{catalog}.qa.row_count_reconciliation")
)

display(
    spark.table(f"{catalog}.qa.row_count_reconciliation")
    .orderBy("table_name", "batch_id")
)

# COMMAND ----------

# Summary

silver_type_checks = []

checks = [
    {
        "table_name": "schools",
        "checks": [
            ("open_date", "invalid_or_missing_open_date")
        ]
    },
    {
        "table_name": "students",
        "checks": [
            ("year_level", "invalid_or_missing_year_level"),
            ("enrolment_date", "invalid_or_missing_enrolment_date")
        ]
    },
    {
        "table_name": "attendance",
        "checks": [
            ("attendance_month", "invalid_or_missing_attendance_month"),
            ("possible_days", "invalid_or_missing_possible_days"),
            ("attended_days", "invalid_or_missing_attended_days")
        ]
    },
    {
        "table_name": "assessment_results",
        "checks": [
            ("assessment_year", "invalid_or_missing_assessment_year"),
            ("score", "invalid_or_missing_score")
        ]
    },
    {
        "table_name": "school_events",
        "checks": [
            ("event_date", "invalid_or_missing_event_date")
        ]
    }
]

for item in checks:
    table_name = item["table_name"]
    df = spark.table(f"{catalog}.silver.{table_name}")

    aggregations = [
        F.count("*").alias("total_records")
    ]

    for column_name, metric_name in item["checks"]:
        aggregations.append(
            F.sum(F.when(F.col(column_name).isNull(), 1).otherwise(0)).alias(metric_name)
        )

    check_df = (
        df.groupBy("batch_id")
        .agg(*aggregations)
        .withColumn("table_name", F.lit(table_name))
    )        

    silver_type_checks.append(check_df)

silver_type_validation = reduce(
    lambda df1, df2: df1.unionByName(df2, allowMissingColumns=True),
    silver_type_checks
)

# COMMAND ----------

display(
    silver_type_validation
    .select("table_name", "batch_id", "total_records",
            *[c for c in silver_type_validation.columns if c not in ["table_name", "batch_id", "total_records"]])
    .orderBy("table_name", "batch_id")
)

# COMMAND ----------

