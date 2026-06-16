# Databricks notebook source
from pyspark.sql import functions as F
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

# Idempotency guard for incremental Bronze loads.
# If the same batch is rerun, remove existing Bronze rows for that batch before appending replacement rows.

bronze_target_tables = [
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
    for table_name in bronze_target_tables:
        if table_exists("bronze", table_name):
            spark.sql(
                f"""
                DELETE FROM {catalog}.bronze.{table_name}
                WHERE batch_id = '{batch_id}'
                """
            )
            print(f"Deleted existing Bronze rows for batch_id={batch_id} from bronze.{table_name}")
        else:
            print(f"Skipped delete because bronze.{table_name} does not exist yet")

# COMMAND ----------

# bronze.schools
source_path = f"{lake_root}/raw/schools/batch_id={batch_id}/schools.csv"
target_path = f"{lake_root}/bronze/schools"

schools_df = (
    spark.read
    .option("header", True)
    .csv(source_path)
    .withColumn("source_file_name",  F.col("_metadata.file_path"))
    .withColumn("load_timestamp", F.current_timestamp())
    .withColumn("run_id", F.lit(run_id))
    .withColumn("batch_id", F.lit(batch_id))
    .withColumn(
        "bronze_record_id",
        F.sha2(
            F.concat_ws(
                "||",
                F.coalesce(F.col("school_id"), F.lit("")),
                F.coalesce(F.col("source_file_name"), F.lit("")),
                F.coalesce(F.col("batch_id"), F.lit("")),
                F.coalesce(F.col("run_id"), F.lit(""))
            ),
            256
        )
    )
)

writer = (
    schools_df.write
    .format("delta")
    .mode(write_mode)
    .option("path", target_path)
)

if write_mode == "overwrite":
    writer = writer.option("overwriteSchema", "true").partitionBy("batch_id")

writer.saveAsTable(f"{catalog}.bronze.schools")

display(spark.table(f"{catalog}.bronze.schools"))

# COMMAND ----------

spark.table(f"{catalog}.bronze.schools").groupBy("batch_id").count().show()

# COMMAND ----------

# bronze.students
source_path = f"{lake_root}/raw/students/batch_id={batch_id}/students.csv"
target_path = f"{lake_root}/bronze/students"

students_df = (
    spark.read
    .option("header", True)
    .csv(source_path)
    .withColumn("source_file_name", F.col("_metadata.file_path"))
    .withColumn("load_timestamp", F.current_timestamp())
    .withColumn("run_id", F.lit(run_id))
    .withColumn("batch_id", F.lit(batch_id))
    .withColumn(
        "bronze_record_id",
        F.sha2(
            F.concat_ws(
                "||",
                F.coalesce(F.col("student_id"), F.lit("")),
                F.coalesce(F.col("source_file_name"), F.lit("")),
                F.coalesce(F.col("batch_id"), F.lit("")),
                F.coalesce(F.col("run_id"), F.lit(""))
            ),
            256
        )
    )
)

writer = (
    students_df.write
    .format("delta")
    .mode(write_mode)
    .option("path", target_path)
)

if write_mode == "overwrite":
    writer = writer.option("overwriteSchema", "true").partitionBy("batch_id")

writer.saveAsTable(f"{catalog}.bronze.students")

display(spark.table(f"{catalog}.bronze.students"))

# COMMAND ----------

spark.table(f"{catalog}.bronze.students").groupBy("batch_id").count().show()

# COMMAND ----------

# bronze.attendance
source_path = f"{lake_root}/raw/attendance/batch_id={batch_id}/attendance.csv"
target_path = f"{lake_root}/bronze/attendance"

attendance_df = (
    spark.read
    .option("header", True)
    .csv(source_path)
    .withColumn("source_file_name", F.col("_metadata.file_path"))
    .withColumn("load_timestamp", F.current_timestamp())
    .withColumn("run_id", F.lit(run_id))
    .withColumn("batch_id", F.lit(batch_id))
    .withColumn(
        "bronze_record_id",
        F.sha2(
            F.concat_ws(
                "||",
                F.coalesce(F.col("attendance_id"), F.lit("")),
                F.coalesce(F.col("source_file_name"), F.lit("")),
                F.coalesce(F.col("batch_id"), F.lit("")),
                F.coalesce(F.col("run_id"), F.lit(""))
            ),
            256
        )
    )
)

writer = (
    attendance_df.write
    .format("delta")
    .mode(write_mode)
    .option("path", target_path)
)

if write_mode == "overwrite":
    writer = writer.option("overwriteSchema", "true").partitionBy("batch_id")

writer.saveAsTable(f"{catalog}.bronze.attendance")

display(spark.table(f"{catalog}.bronze.attendance"))

# COMMAND ----------

spark.table(f"{catalog}.bronze.attendance").groupBy("batch_id").count().show()

# COMMAND ----------

# bronze.assessment_resuls
source_path = f"{lake_root}/raw/assessment_results/batch_id={batch_id}/assessment_results.csv"
target_path = f"{lake_root}/bronze/assessment_results"

assessment_results_df = (
    spark.read
    .option("header", True)
    .csv(source_path)
    .withColumn("source_file_name", F.col("_metadata.file_path"))
    .withColumn("load_timestamp", F.current_timestamp())
    .withColumn("run_id", F.lit(run_id))
    .withColumn("batch_id", F.lit(batch_id))
    .withColumn(
        "bronze_record_id",
        F.sha2(
            F.concat_ws(
                "||",
                F.coalesce(F.col("assessment_id"), F.lit("")),
                F.coalesce(F.col("source_file_name"), F.lit("")),
                F.coalesce(F.col("batch_id"), F.lit("")),
                F.coalesce(F.col("run_id"), F.lit(""))
            ),
            256
        )
    )
)

writer = (
    assessment_results_df.write
    .format("delta")
    .mode(write_mode)
    .option("path", target_path)
)

if write_mode == "overwrite":
    writer = writer.option("overwriteSchema", "true").partitionBy("batch_id")

writer.saveAsTable(f"{catalog}.bronze.assessment_results")

display(spark.table(f"{catalog}.bronze.assessment_results"))

# COMMAND ----------

spark.table(f"{catalog}.bronze.assessment_results").groupBy("batch_id").count().show()

# COMMAND ----------

# bronze.school_events
source_path = f"{lake_root}/raw/school_events/batch_id={batch_id}/school_events.json"
target_path = f"{lake_root}/bronze/school_events"

school_events_df = (
    spark.read
    .option("multiline", True)
    .json(source_path)
    .withColumn("source_file_name", F.col("_metadata.file_path"))
    .withColumn("load_timestamp", F.current_timestamp())
    .withColumn("run_id", F.lit(run_id))
    .withColumn("batch_id", F.lit(batch_id))
    .withColumn(
        "bronze_record_id",
        F.sha2(
            F.concat_ws(
                "||",
                F.coalesce(F.col("event_id"), F.lit("")),
                F.coalesce(F.col("source_file_name"), F.lit("")),
                F.coalesce(F.col("batch_id"), F.lit("")),
                F.coalesce(F.col("run_id"), F.lit(""))
            ),
            256
        )
    )
)

writer = (
    school_events_df.write
    .format("delta")
    .mode(write_mode)
    .option("path", target_path)
)

if write_mode == "overwrite":
    writer = writer.option("overwriteSchema", "true").partitionBy("batch_id")

writer.saveAsTable(f"{catalog}.bronze.school_events")
display(spark.table(f"{catalog}.bronze.school_events"))

# COMMAND ----------

spark.table(f"{catalog}.bronze.school_events").groupBy("batch_id").count().show()

# COMMAND ----------

from functools import reduce

bronze_tables = [
    "schools",
    "students",
    "attendance",
    "assessment_results",
    "school_events"
]

count_dfs = []

for table_name in bronze_tables:
    count_df = (
        spark.table(f"{catalog}.bronze.{table_name}")
        .groupBy("batch_id")
        .count()
        .withColumn("table_name", F.lit(table_name))
        .select("table_name", "batch_id", "count")
    )

    count_dfs.append(count_df)

bronze_count_summary = reduce(
    lambda df1, df2: df1.unionByName(df2),
    count_dfs
)

display(
    bronze_count_summary
    .orderBy("table_name", "batch_id")
)

# COMMAND ----------

# Validatoin
from functools import reduce
from pyspark.sql import functions as F

bronze_tables = [
    "schools",
    "students",
    "attendance",
    "assessment_results",
    "school_events"
]

audit_validation_dfs = []

for table_name in bronze_tables:
    df = spark.table(f"{catalog}.bronze.{table_name}")

    validation_df = df.agg(
        F.count("*").alias("total_records"),
        F.sum(F.when(F.col("batch_id").isNull(), 1).otherwise(0)).alias("missing_batch_id"),
        F.sum(F.when(F.col("run_id").isNull(), 1).otherwise(0)).alias("missing_run_id"),
        F.sum(F.when(F.col("load_timestamp").isNull(), 1).otherwise(0)).alias("missing_load_timestamp"),
        F.sum(F.when(F.col("source_file_name").isNull(), 1).otherwise(0)).alias("missing_source_file_name"),
        F.sum(F.when(F.col("bronze_record_id").isNull(), 1).otherwise(0)).alias("missing_bronze_record_id"),
        F.countDistinct("bronze_record_id").alias("distinct_bronze_record_ids")
    ).withColumn("table_name", F.lit(table_name))

    audit_validation_dfs.append(validation_df)

bronze_audit_validation = reduce(
    lambda df1, df2: df1.unionByName(df2),
    audit_validation_dfs
)

display(
    bronze_audit_validation.select(
        "table_name",
        "total_records",
        "missing_batch_id",
        "missing_run_id",
        "missing_load_timestamp",
        "missing_source_file_name",
        "missing_bronze_record_id",
        "distinct_bronze_record_ids"
    )
)

# COMMAND ----------

for table_name in ["schools", "students", "attendance", "assessment_results", "school_events"]:
    print(f"\nbronze.{table_name}")
    display(
        spark.table(f"{catalog}.bronze.{table_name}")
        .groupBy("batch_id")
        .count()
        .orderBy("batch_id")
    )

# COMMAND ----------

