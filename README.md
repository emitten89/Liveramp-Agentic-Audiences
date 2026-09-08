# Liveramp-Agentic-Audiences
LiveRamp clean room gone agentic goodness

## Cloud environment

This project builds against a dedicated AWS Databricks dev environment,
intended to later move onto Publicis's production AWS Databricks + Terraform
infrastructure. Start here:

- [`docs/aws-databricks-dev-setup.md`](docs/aws-databricks-dev-setup.md) —
  full walkthrough, from "workspace exists, nothing else does" to a working
  dev environment.
- [`infra/terraform/dev/`](infra/terraform/dev/) — the Terraform that
  provisions it (S3 landing bucket, IAM, Unity Catalog storage
  credential/external location/catalog/schema, SQL warehouse).
- [`pipelines/`](pipelines/) — pipeline code, following the medallion
  (bronze/silver/gold) pattern used across MRCL Databricks pipelines.
