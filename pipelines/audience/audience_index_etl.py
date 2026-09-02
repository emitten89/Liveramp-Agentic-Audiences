"""
Pipeline: audience_index_etl
Domain: audience
Source: raw files landed in the dev Unity Catalog volume
        (/Volumes/{catalog}/{schema}/raw_files) — e.g. LiveRamp clean-room
        exports or partner audience index extracts.
Target: {catalog}.{schema}.audience_index_reports
Refresh: manual (dev) / TBD cadence once promoted to production

Starting skeleton for building agentic audience pipelines against the dev
Databricks environment provisioned in infra/terraform/dev/. Catalog/schema
names come from Terraform outputs, not hardcoded, so this same code targets
the production catalog/schema after promotion just by changing config.

Follows the bronze -> silver -> gold convention used across MRCL Databricks
pipelines: raw ingestion, then cleanse/conform, then business logic, each
step keeping the standard metadata columns for lineage and dedup.
"""

import hashlib
from datetime import datetime, timezone

import pyspark.sql.functions as F
from pyspark.sql import DataFrame, SparkSession
from pyspark.sql.types import DoubleType, StringType, StructField, StructType

# ============================================================
# CONFIGURATION
# ============================================================
# Values here should come from Terraform outputs (see
# infra/terraform/dev/outputs.tf: catalog_name, schema_full_name,
# raw_files_volume) rather than being re-hardcoded as the environment changes.

CONFIG = {
    "catalog": "liveramp_agentic_audiences",
    "schema": "dev",
    "source_path": "/Volumes/liveramp_agentic_audiences/dev/raw_files/audience_index",
    "target_table": "liveramp_agentic_audiences.dev.audience_index_reports",
    "staging_table": "liveramp_agentic_audiences._staging.dev_audience_index_reports",
    "partition_col": "load_date",
    "dedup_cols": ["brand", "segment", "attribute"],
}

SOURCE_SCHEMA = StructType(
    [
        StructField("brand", StringType(), True),
        StructField("segment", StringType(), True),
        StructField("attribute", StringType(), True),
        StructField("index_value", StringType(), True),
        StructField("audience_proportion", StringType(), True),
    ]
)


# ============================================================
# BRONZE: Raw ingestion
# ============================================================


def read_source(spark: SparkSession, config: dict) -> DataFrame:
    """Read raw data from the landing volume. No transformations."""
    return (
        spark.read.format("csv")
        .option("header", "true")
        .option("inferSchema", "false")
        .schema(SOURCE_SCHEMA)
        .load(config["source_path"])
        .withColumn("_ingested_at", F.current_timestamp())
        .withColumn("_source_file", F.input_file_name())
    )


# ============================================================
# SILVER: Cleanse & conform
# ============================================================


def cleanse(df: DataFrame) -> DataFrame:
    """Type casting, null handling, dedup."""
    return (
        df.withColumn("index_value", F.col("index_value").cast(DoubleType()))
        .withColumn(
            "audience_proportion", F.col("audience_proportion").cast(DoubleType())
        )
        .withColumn("brand", F.upper(F.trim(F.col("brand"))))
        .withColumn("load_date", F.to_date(F.col("_ingested_at")))
        .dropDuplicates(CONFIG["dedup_cols"])
    )


def add_metadata(df: DataFrame, run_id: str) -> DataFrame:
    """Standard lineage/dedup metadata columns."""
    hash_cols = CONFIG["dedup_cols"]
    return df.withColumn("_pipeline_run", F.lit(run_id)).withColumn(
        "_data_hash", F.sha2(F.concat_ws("|", *[F.col(c) for c in hash_cols]), 256)
    )


# ============================================================
# GOLD: Business logic
# ============================================================


def apply_business_logic(df: DataFrame) -> DataFrame:
    """Significance filtering, matching the MRCL audience-index convention:
    index > 120 and represents a meaningful share of the audience."""
    return df.filter(
        (F.col("index_value") > 120) & (F.col("audience_proportion") > 0.05)
    ).withColumn("significance", F.lit("SIGNIFICANT"))


# ============================================================
# WRITE
# ============================================================


def write_to_catalog(df: DataFrame, config: dict, mode: str = "overwrite") -> None:
    (
        df.write.format("delta")
        .mode(mode)
        .option("mergeSchema", "true")
        .partitionBy(config["partition_col"])
        .saveAsTable(config["target_table"])
    )


# ============================================================
# ORCHESTRATION ENTRY POINT
# ============================================================


def run(spark: SparkSession, run_id: str | None = None) -> dict:
    if run_id is None:
        run_id = f"manual_{datetime.now(timezone.utc).isoformat()}"

    raw = read_source(spark, CONFIG)
    clean = cleanse(raw)
    enriched = add_metadata(clean, run_id)
    final = apply_business_logic(enriched)
    write_to_catalog(final, CONFIG)

    row_count = final.count()
    return {
        "pipeline": "audience_index_etl",
        "run_id": run_id,
        "rows_written": row_count,
        "target_table": CONFIG["target_table"],
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


if __name__ == "__main__":
    spark = SparkSession.builder.getOrCreate()
    result = run(spark)
    print(result)
