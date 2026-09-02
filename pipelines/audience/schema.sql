-- Unity Catalog DDL for the audience_index_etl pipeline's target table.
-- Run this once the catalog/schema from infra/terraform/dev/ exists.
-- Catalog/schema names below match the Terraform defaults
-- (liveramp_agentic_audiences.dev) -- update if yours differ.

CREATE TABLE IF NOT EXISTS liveramp_agentic_audiences.dev.audience_index_reports (
  brand                STRING    COMMENT 'Brand name, uppercased/trimmed',
  segment              STRING    COMMENT 'Audience segment identifier',
  attribute            STRING    COMMENT 'Audience attribute within the segment',
  index_value          DOUBLE    COMMENT 'Index score vs. general population baseline (100 = average)',
  audience_proportion  DOUBLE    COMMENT 'Proportion of the audience exhibiting this attribute',
  significance         STRING    COMMENT 'SIGNIFICANT once index_value > 120 and audience_proportion > 0.05',
  load_date            DATE      COMMENT 'Date this record was ingested, used as the partition column',

  -- Standard metadata columns (required on every table)
  _ingested_at   TIMESTAMP  COMMENT 'UTC timestamp of record ingestion',
  _source_file   STRING     COMMENT 'Source file path or API endpoint',
  _pipeline_run  STRING     COMMENT 'Pipeline run ID',
  _data_hash     STRING     COMMENT 'SHA-256 of business columns for dedup'
)
USING DELTA
COMMENT 'Audience index scores for LiveRamp clean-room agentic audience analysis.'
PARTITIONED BY (load_date)
TBLPROPERTIES (
  'delta.autoOptimize.optimizeWrite' = 'true',
  'delta.autoOptimize.autoCompact' = 'true',
  'mrcl.domain' = 'audience',
  'mrcl.refresh_cadence' = 'manual',
  'mrcl.source_system' = 'liveramp_clean_room',
  'mrcl.data_classification' = 'confidential'
);
