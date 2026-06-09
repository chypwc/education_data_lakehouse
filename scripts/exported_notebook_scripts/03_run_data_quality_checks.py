# Databricks notebook source
from datetime import datetime, timezone
from pyspark.sql import functions as F
from pyspark.sql import types as T

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

catalog = "dbw_edu_qa_dev"
storage_account = "steduqadblakehouse"
container = "education-data-lake"

lake_root = f"abfss://{container}@{storage_account}.dfs.core.windows.net"

qa_result_write_mode = "append"

print(f"environment: {environment}")
print(f"batch_id: {batch_id}")
print(f"run_mode: {run_mode}")
print(f"job_run_id: {job_run_id}")
print(f"run_id: {run_id}")

# COMMAND ----------

# Idempotency guard for QA reruns with the same run_id.
# QA keeps history by run_id, but a repaired/rerun notebook should not duplicate the same run_id output.

if run_mode == "incremental":
    for table_name in ["dq_validation_results", "dq_failed_records", "defect_log"]:
        if (
            spark.sql(f"SHOW TABLES IN {catalog}.qa LIKE '{table_name}'")
            .count() > 0
        ):
            spark.sql(
                f"""
                DELETE FROM {catalog}.qa.{table_name}
                WHERE run_id = '{run_id}'
                """
            )
            print(f"Deleted existing QA rows for run_id={run_id} from qa.{table_name}")

# COMMAND ----------

# MAGIC %md
# MAGIC ### dq_rules

# COMMAND ----------

dq_rules = [
    ("DQ001", "Missing student ID", "silver.students", "High", "student_id must not be null or blank", "No missing student IDs"),
    ("DQ002", "Missing school ID", "silver.students", "High", "school_id must not be null or blank", "No missing school IDs"),
    ("DQ003", "Invalid attendance days", "silver.attendance", "High", "attended_days must be between 0 and possible_days", "Attendance days are within valid range"),
    ("DQ004", "Duplicate attendance business record", "silver.attendance", "Medium", "student_id, school_id, attendance_month should be unique", "No duplicate attendance records"),
    ("DQ005", "Attendance references missing student", "silver.attendance", "High", "attendance.student_id must exist in silver.students", "No orphan attendance records"),
    ("DQ006", "Assessment references missing student", "silver.assessment_results", "High", "assessment_results.student_id must exist in silver.students", "No orphan assessment records"),
    ("DQ007", "Invalid assessment score", "silver.assessment_results", "High", "score must be between 250 and 700", "Assessment scores are within the valid 250 to 700 scale"),
    ("DQ008", "Invalid proficiency band", "silver.assessment_results", "Medium", "proficiency_band must be one of Low, Medium, High", "Proficiency bands are valid"),
    ("DQ009", "Invalid school status", "silver.schools", "Medium", "status must be Active or Closed", "School status values are valid"),
    ("DQ010", "Future attendance month", "silver.attendance", "Medium", "attendance_month must not be in the future", "No future attendance month"),
    ("DQ011", "School event linked to inactive or missing school", "silver.school_events", "Low", "school_events.school_id should link to an active school", "Events link to active schools")
]

dq_rule_schema = T.StructType([
    T.StructField("rule_id", T.StringType(), False),
    T.StructField("rule_name", T.StringType(), False),
    T.StructField("target_table", T.StringType(), False),
    T.StructField("severity", T.StringType(), False),
    T.StructField("business_rule", T.StringType(), False),
    T.StructField("expected_outcome", T.StringType(), False)
])

dq_rule_catalog_df = spark.createDataFrame(dq_rules, schema=dq_rule_schema)

target_path = f"{lake_root}/qa/dq_rule_catalog"

(
    dq_rule_catalog_df.write
    .format("delta")
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .option("path", target_path)
    .saveAsTable(f"{catalog}.qa.dq_rule_catalog")
)

display(
    spark.table(f"{catalog}.qa.dq_rule_catalog")
    .orderBy("rule_id")
)

# COMMAND ----------

# MAGIC %md
# MAGIC ### dq_validation_results, dq_failed_records, defect_log

# COMMAND ----------

# QA output table schemas

dq_validation_results_schema = T.StructType([
    T.StructField("run_id", T.StringType(), False),
    T.StructField("batch_id", T.StringType(), True),
    T.StructField("rule_id", T.StringType(), False),
    T.StructField("rule_name", T.StringType(), False),
    T.StructField("target_table", T.StringType(), False),
    T.StructField("severity", T.StringType(), False),
    T.StructField("failed_record_count", T.LongType(), False),
    T.StructField("status", T.StringType(), False),
    T.StructField("run_timestamp", T.TimestampType(), False)
])

dq_failed_records_schema = T.StructType([
    T.StructField("run_id", T.StringType(), False),
    T.StructField("batch_id", T.StringType(), True),
    T.StructField("rule_id", T.StringType(), False),
    T.StructField("target_table", T.StringType(), False),
    T.StructField("business_key", T.StringType(), True),
    T.StructField("bronze_record_id", T.StringType(), True),
    T.StructField("failure_reason", T.StringType(), False),
    T.StructField("failed_record_json", T.StringType(), True),
    T.StructField("run_timestamp", T.TimestampType(), False)
])

defect_log_schema = T.StructType([
    T.StructField("defect_id", T.StringType(), False),
    T.StructField("run_id", T.StringType(), False),
    T.StructField("batch_id", T.StringType(), True),
    T.StructField("rule_id", T.StringType(), False),
    T.StructField("severity", T.StringType(), False),
    T.StructField("target_table", T.StringType(), False),
    T.StructField("defect_title", T.StringType(), False),
    T.StructField("defect_status", T.StringType(), False),
    T.StructField("failed_record_count", T.LongType(), False),
    T.StructField("recommended_action", T.StringType(), False),
    T.StructField("created_timestamp", T.TimestampType(), False)
])

# COMMAND ----------

empty_validation_results_df = spark.createDataFrame([], dq_validation_results_schema)
empty_failed_records_df = spark.createDataFrame([], dq_failed_records_schema)
empty_defect_log_df = spark.createDataFrame([], defect_log_schema)

if run_mode == "initial":
    (
        empty_validation_results_df.write
        .format("delta")
        .mode("overwrite")
        .option("overwriteSchema", "true")
        .option("path", f"{lake_root}/qa/dq_validation_results")
        .saveAsTable(f"{catalog}.qa.dq_validation_results")
    )

    (
        empty_failed_records_df.write
        .format("delta")
        .mode("overwrite")
        .option("overwriteSchema", "true")
        .option("path", f"{lake_root}/qa/dq_failed_records")
        .saveAsTable(f"{catalog}.qa.dq_failed_records")
    )

    (
        empty_defect_log_df.write
        .format("delta")
        .mode("overwrite")
        .option("overwriteSchema", "true")
        .option("path", f"{lake_root}/qa/defect_log")
        .saveAsTable(f"{catalog}.qa.defect_log")
    )

    print("QA output tables created.")

# COMMAND ----------

for table_name in ["dq_validation_results", "dq_failed_records", "defect_log"]:
    print(f"\nqa.{table_name}")
    spark.table(f"{catalog}.qa.{table_name}").printSchema()

# COMMAND ----------

# Helper Functions

def get_rule_metadata(rule_id):
    """This reads one rule from qa.dq_rule_catalog and returns it as a Python dictionary."""
    row = (
        spark.table(f"{catalog}.qa.dq_rule_catalog")
        .filter(F.col("rule_id") == rule_id)
        .first()
    )
    if row is None:
        raise ValueError(f"Rule {rule_id} not found in catalog")

    return {
        "rule_id": row["rule_id"],
        "rule_name": row["rule_name"],
        "target_table": row["target_table"],
        "severity": row["severity"],
        "business_rule": row["business_rule"],
        "expected_outcome": row["expected_outcome"]
    }


def status_from_failure_count(failed_record_count, severity):
    "Convert failure count into QA status."
    if failed_record_count == 0:
        return "PASS"
    elif severity.lower() == "low":
        return "WARN"
    
    return "FAIL"


def append_validation_result(rule_metadata, batch_id, failed_record_count):
    """Append one row to qa.dq_validation_results.
    This stores the rule summary: how many records failed and whether the rule passed, warned, or failed."""
    status = status_from_failure_count(failed_record_count, rule_metadata["severity"])
    
    result_df = spark.createDataFrame(
        [(
            run_id,
            batch_id,
            rule_metadata["rule_id"],
            rule_metadata["rule_name"],
            rule_metadata["target_table"],
            rule_metadata["severity"],
            failed_record_count,
            status,
            datetime.now(timezone.utc)
        )],
        schema=dq_validation_results_schema
    )

    (
        result_df.write
        .format("delta")
        .mode(qa_result_write_mode)
        .saveAsTable(f"{catalog}.qa.dq_validation_results")
    )


def append_failed_records(rule_metadata, failed_df, business_key_col, failure_reason):
    """append failed record details to qa.dq_failed_records"""
    failed_records_df = (
        failed_df
        .withColumn("run_id", F.lit(run_id))
        .withColumn("rule_id", F.lit(rule_metadata["rule_id"]))
        .withColumn("target_table", F.lit(rule_metadata["target_table"]))
        .withColumn("business_key", F.col(business_key_col).cast("string"))
        .withColumn("failure_reason", F.lit(failure_reason))
        .withColumn(
            "failed_record_json", 
            F.to_json(F.struct([F.col(c) for c in failed_df.columns])))
        .withColumn("run_timestamp", F.current_timestamp())
        .select(
            "run_id",
            "batch_id",
            "rule_id",
            "target_table",
            "business_key",
            "bronze_record_id",
            "failure_reason",
            "failed_record_json",
            "run_timestamp"
        )
    )

    (
        failed_records_df.write
        .format("delta")
        .mode(qa_result_write_mode)
        .saveAsTable(f"{catalog}.qa.dq_failed_records")
    )



def append_defect_log(rule_metadata, batch_id, failed_record_count, recommended_action):
    """Append one defect record to qa.defect_log when a rule has failed records."""
    if failed_record_count == 0:
        return

    defect_id = f"{rule_metadata['rule_id']}_{batch_id}_{run_id}"

    defect_df = spark.createDataFrame(
        [(
            defect_id,
            run_id,
            batch_id,
            rule_metadata["rule_id"],
            rule_metadata["severity"],
            rule_metadata["target_table"],
            rule_metadata["rule_name"],
            "Open",
            failed_record_count,
            recommended_action,
            datetime.now(timezone.utc)
        )],
        schema=defect_log_schema
    )

    (
        defect_df.write
        .format("delta")
        .mode(qa_result_write_mode)
        .saveAsTable(f"{catalog}.qa.defect_log")
    )


def process_dq_rule_results(
    rule_metadata,
    source_df,
    failed_df,
    business_key_col,
    failure_reason,
    recommended_action
):
    """Write validation results, failed records, and defect log rows for one DQ rule."""
    failed_counts = (
        failed_df
        .groupBy("batch_id")
        .count()
        .collect()
    )

    for row in failed_counts:
        batch_id = row["batch_id"]
        failed_record_count = row["count"]

        batch_failed_df = failed_df.filter(F.col("batch_id") == batch_id)

        append_validation_result(rule_metadata, batch_id, failed_record_count)

        append_failed_records(
            rule_metadata,
            batch_failed_df,
            business_key_col,
            failure_reason
        )

        append_defect_log(
            rule_metadata,
            batch_id,
            failed_record_count,
            recommended_action
        )

    all_batches = [
        row["batch_id"]
        for row in source_df.select("batch_id").distinct().collect()
    ]

    failed_batches = [row["batch_id"] for row in failed_counts]

    for batch_id in all_batches:
        if batch_id not in failed_batches:
            append_validation_result(rule_metadata, batch_id, 0)

# COMMAND ----------

# MAGIC %md
# MAGIC Clean qa tables.
# MAGIC ```
# MAGIC rules_to_rerun = [f"DQ{i:03d}" for i in range(1, 12)]
# MAGIC
# MAGIC for rule_id in rules_to_rerun:
# MAGIC     spark.sql(f"DELETE FROM {catalog}.qa.dq_validation_results WHERE run_id = '{run_id}' AND rule_id = '{rule_id}'")
# MAGIC     spark.sql(f"DELETE FROM {catalog}.qa.dq_failed_records WHERE run_id = '{run_id}' AND rule_id = '{rule_id}'")
# MAGIC     spark.sql(f"DELETE FROM {catalog}.qa.defect_log WHERE run_id = '{run_id}' AND rule_id = '{rule_id}'")
# MAGIC ```

# COMMAND ----------

# DQ001: Missing student ID

rule_metadata = get_rule_metadata("DQ001")

source_df = (
    spark.table(f"{catalog}.silver.students")
    .filter(F.col("batch_id") == batch_id)
)

failed_df = (
    source_df
    .filter(
        F.col("student_id").isNull()
        | (F.trim(F.col("student_id")) == "")
    )
)
        
process_dq_rule_results(
    rule_metadata=rule_metadata,
    source_df=source_df,
    failed_df=failed_df,
    business_key_col="student_id",
    failure_reason="student_id is null or blank",
    recommended_action="Investigate source student extract and require student_id for all student records."
)

display(
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("rule_id") == "DQ001")
    .orderBy("batch_id")
)


# COMMAND ----------

# DQ002: Missing school ID

rule_metadata = get_rule_metadata("DQ002")
source_df = (
    spark.table(f"{catalog}.silver.students")
    .filter(F.col("batch_id") == batch_id)
)

failed_df = source_df.filter(
    F.col("school_id").isNull()
    | (F.trim(F.col("school_id")) == "")
)

process_dq_rule_results(
    rule_metadata,
    source_df,
    failed_df,
    "student_id",
    "school_id is null or blank",
    "Investigate student enrolment extract and require a valid school_id for each student."
)

display(
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("rule_id") == "DQ002")
    .orderBy("batch_id")
)

# COMMAND ----------

# DQ003: Invalid attendance days

# possible_days must be >= 0
# attended_days must be >= 0
# attended_days must be <= possible_days

rule_metadata = get_rule_metadata("DQ003")
source_df = spark.table(f"{catalog}.silver.attendance").filter(F.col("batch_id") == batch_id)

failed_df = source_df.filter(
    F.col("possible_days").isNull()
    | F.col("attended_days").isNull()
    | (F.col("possible_days") < 0)
    | (F.col("attended_days") < 0)
    | (F.col("attended_days") > F.col("possible_days"))
)

process_dq_rule_results(
    rule_metadata,
    source_df,
    failed_df,
    "attendance_id",
    "Attendance days are missing, negative, or attended_days is greater than possible_days.",
    "Review attendance source extract and enforce valid possible_days and attended_days values before publishing."
)

display(
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("rule_id") == "DQ003")
    .orderBy("batch_id")
)

# COMMAND ----------

# DQ004: Duplicate attendance business record

rule_metadata = get_rule_metadata("DQ004")
source_df = spark.table(f"{catalog}.silver.attendance").filter(F.col("batch_id") == batch_id)

duplicate_keys_df = (
    source_df
    .groupBy("batch_id", "student_id", "school_id", "attendance_month")
    .count()
    .filter(F.col("count") > 1)
    .select("batch_id", "student_id", "school_id", "attendance_month")
)

failed_df = (
    source_df
    .join(
        duplicate_keys_df,
        on=["batch_id", "student_id", "school_id", "attendance_month"],
        how="inner"
    )
)

process_dq_rule_results(
    rule_metadata,
    source_df,
    failed_df,
    "attendance_id",
    "Duplicate attendance business record for student_id, school_id, and attendance_month.",
    "Review attendance source extract for duplicate monthly attendance submissions and deduplicate before reporting."
)

display(
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("rule_id") == "DQ004")
    .orderBy("batch_id")
)

# COMMAND ----------

# DQ005: Attendance references missing student
# This checks whether each attendance student_id exists in silver.students for the same batch_id.

rule_metadata = get_rule_metadata("DQ005")
source_df = spark.table(f"{catalog}.silver.attendance").filter(F.col("batch_id") == batch_id)
students_df = spark.table(f"{catalog}.silver.students").filter(F.col("batch_id") == batch_id)

valid_students_df = (
    students_df
    .filter(F.col("student_id").isNotNull() & (F.trim(F.col("student_id")) != ""))
    .select("batch_id", "student_id")
    .distinct()
)

failed_df = source_df.join(
    valid_students_df,
    on=["batch_id", "student_id"],
    how="left_anti"
)

process_dq_rule_results(
    rule_metadata,
    source_df,
    failed_df,
    "attendance_id",
    "attendance.student_id does not exist in silver.students for the same batch_id.",
    "Investigate attendance records with missing student references and correct source system referential integrity."
)

display(
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("rule_id") == "DQ005")
    .orderBy("batch_id")
)

# COMMAND ----------

# DQ006: Assessment references missing student
# This checks whether each assessment student_id exists in silver.students for the same batch_id.

rule_metadata = get_rule_metadata("DQ006")
source_df = spark.table(f"{catalog}.silver.assessment_results").filter(F.col("batch_id") == batch_id)
students_df = spark.table(f"{catalog}.silver.students").filter(F.col("batch_id") == batch_id)

valid_students_df = (
    students_df
    .filter(F.col("student_id").isNotNull() & (F.trim(F.col("student_id")) != ""))
    .select("batch_id", "student_id")
    .distinct()
)

failed_df = source_df.join(
    valid_students_df,
    on=["batch_id", "student_id"],
    how="left_anti"
)

process_dq_rule_results(
    rule_metadata,
    source_df,
    failed_df,
    "assessment_id",
    "assessment_results.student_id does not exist in silver.students for the same batch_id.",
    "Investigate assessment records with missing student references and correct source system referential integrity."
)

display(
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("rule_id") == "DQ006")
    .orderBy("batch_id")
)

# COMMAND ----------

# DQ007: Invalid assessment score
# score must not be null
# score must be between 250 and 700

rule_metadata = get_rule_metadata("DQ007")
source_df = spark.table(f"{catalog}.silver.assessment_results").filter(F.col("batch_id") == batch_id)

failed_df = source_df.filter(
    F.col("score").isNull()
    | (F.col("score") < 250)
    | (F.col("score") > 700)
)

process_dq_rule_results(
    rule_metadata,
    source_df,
    failed_df,
    "assessment_id",
    "score is null or outside the valid 250 to 700 range.",
    "Review assessment scoring scale and source extract. Confirm whether scores should be normalised before reporting."
)
display(
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("rule_id") == "DQ007")
    .orderBy("batch_id")
)

# COMMAND ----------

# DQ008: Invalid proficiency band: Low, Medium, High

rule_metadata = get_rule_metadata("DQ008")
source_df = spark.table(f"{catalog}.silver.assessment_results").filter(F.col("batch_id") == batch_id)

valid_bands = ["Low", "Medium", "High"]

failed_df = source_df.filter(
    F.col("proficiency_band").isNull()
    | (~F.col("proficiency_band").isin(valid_bands))
)

process_dq_rule_results(
    rule_metadata,
    source_df,
    failed_df,
    "assessment_id",
    "proficiency_band is null or not one of Low, Medium, High.",
    "Review assessment proficiency band mapping and enforce controlled category values."
)

display(
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("rule_id") == "DQ008")
    .orderBy("batch_id")
)

# COMMAND ----------

# DQ009: Invalid school status

rule_metadata = get_rule_metadata("DQ009")
source_df = spark.table(f"{catalog}.silver.schools").filter(F.col("batch_id") == batch_id)

valid_statuses = ["Active", "Closed"]

failed_df = source_df.filter(
    F.col("status").isNull()
    | (~F.col("status").isin(valid_statuses))
)

process_dq_rule_results(
    rule_metadata,
    source_df,
    failed_df,
    "school_id",
    "status is null or not one of Active, Closed.",
    "Review school status reference data and enforce controlled status values."
)

display(
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("rule_id") == "DQ009")
    .orderBy("batch_id")
)

# COMMAND ----------

# DQ010: Future attendance month

rule_metadata = get_rule_metadata("DQ010")
source_df = spark.table(f"{catalog}.silver.attendance").filter(F.col("batch_id") == batch_id)

failed_df = source_df.filter(
    F.col("attendance_month").isNull()
    | (F.col("attendance_month") > F.current_date())
)

process_dq_rule_results(
    rule_metadata,
    source_df,
    failed_df,
    "attendance_id",
    "attendance_month is null or later than the current date.",
    "Review attendance period values and prevent future-dated attendance records from entering reporting."
)

display(
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("rule_id") == "DQ010")
    .orderBy("batch_id")
)

# COMMAND ----------

# DQ011: School event linked to inactive or missing school

rule_metadata = get_rule_metadata("DQ011")
source_df = spark.table(f"{catalog}.silver.school_events").filter(F.col("batch_id") == batch_id)
schools_df = spark.table(f"{catalog}.silver.schools").filter(F.col("batch_id") == batch_id)

active_schools_df = (
    schools_df
    .filter(F.col("status") == "Active")
    .select("batch_id", "school_id")
    .distinct()
)

failed_df = source_df.join(
    active_schools_df,
    on=["batch_id", "school_id"],
    how="left_anti"
)

process_dq_rule_results(
    rule_metadata,
    source_df,
    failed_df,
    "event_id",
    "school event is linked to an inactive or missing school.",
    "Review school event source data and confirm whether events should be linked only to active schools."
)
display(
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("rule_id") == "DQ011")
    .orderBy("batch_id")
)

# COMMAND ----------

display(
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("run_id") == run_id)
    .orderBy("rule_id", "batch_id")
)

# COMMAND ----------

display(
    spark.table(f"{catalog}.qa.dq_validation_results")
    .filter(F.col("run_id") == run_id)
    .groupBy("severity", "status")
    .agg(
        F.count("*").alias("rule_batch_count"),
        F.sum("failed_record_count").alias("total_failed_records")
    )
    .orderBy("severity", "status")
)

# COMMAND ----------

display(
    spark.table(f"{catalog}.qa.dq_failed_records")
    .filter(F.col("run_id") == run_id)
    .select(
        "batch_id",
        "rule_id",
        "target_table",
        "business_key",
        "bronze_record_id",
        "failure_reason",
        "run_timestamp"
    )
    .orderBy("rule_id", "batch_id", "business_key")
)

# COMMAND ----------

display(
    spark.table(f"{catalog}.qa.defect_log")
    .filter(F.col("run_id") == run_id)
    .orderBy("rule_id", "batch_id")
)


# COMMAND ----------

display(
    spark.table(f"{catalog}.qa.dq_validation_results")
    .groupBy("batch_id", "status")
    .agg(
        F.count("*").alias("rule_result_count"),
        F.sum("failed_record_count").alias("failed_record_count")
    )
    .orderBy("batch_id", "status")
)

# COMMAND ----------

