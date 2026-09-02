# Dev Terraform — LiveRamp Agentic Audiences

Provisions the AWS + Unity Catalog resources needed to actually *use* the
existing Databricks workspace for building clean-room agentic audience
pipelines: an S3 landing bucket, the IAM role Unity Catalog uses to reach it,
a storage credential + external location, a catalog/schema/volume, and a
small SQL warehouse + cluster policy for pipeline runs.

This is the **dev/temporary** environment. It is intentionally structured to
mirror the naming and resource shape of Publicis's production MRCL Databricks
Terraform (`mrcl_catalog.{client}.{domain}_{entity}`, storage-credential /
external-location pattern, cluster-policy tags) so that migrating this out to
production is a lift-and-rename, not a redesign. See
[docs/aws-databricks-dev-setup.md](../../../docs/aws-databricks-dev-setup.md)
for the full narrative walkthrough, including the manual AWS/Databricks
account-console steps this Terraform can't do for you.

## Prerequisites

- An AWS account with credentials available to Terraform (`aws configure` /
  SSO profile / env vars). This is the one piece that has to exist before
  anything here can run — Terraform provisions *into* an AWS account, it
  doesn't create the account itself.
- Admin access to the existing AWS Databricks workspace, plus a personal
  access token or service-principal OAuth token exported as
  `DATABRICKS_TOKEN` (and `DATABRICKS_HOST` set to the workspace URL, or set
  via `databricks_workspace_url` below).
- Metastore already assigned to the workspace (ask a Databricks account
  admin if unsure — `databricks_catalog` will fail with a clear error if not).

## Usage

```bash
cd infra/terraform/dev
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your AWS account ID, workspace URL, bucket name

terraform init
terraform plan
terraform apply   # first apply: role trusts a placeholder external ID

terraform output storage_credential_external_id
# copy that value into terraform.tfvars as unity_catalog_external_id

terraform apply   # second apply: tightens the IAM trust policy for real
```

After the second apply, `terraform output` gives you the catalog/schema name,
SQL warehouse ID, and raw-files volume path to point pipeline code at.

## Why two applies?

Unity Catalog storage credentials on AWS generate a credential-specific
external ID that Databricks only assigns once the credential exists. The IAM
role's trust policy needs that ID in its `sts:ExternalId` condition to be
secure. There's no way around the chicken-and-egg without either accepting a
placeholder external ID permanently (insecure) or applying twice. This is
normal for Unity Catalog on AWS, not specific to this repo.

## Migrating to production

When this environment is ready to move onto Publicis's production Databricks
+ Terraform:

1. Port `unity_catalog.tf` / `iam.tf` / `s3.tf` resource shapes into the
   production stack's module conventions (they likely already have a shared
   module for storage-credential + external-location — check before
   duplicating).
2. Rename `catalog_name` from `liveramp_agentic_audiences` /
   `schema_name = "dev"` to whatever client/project schema production uses.
3. Replace the `account users` grant with the real service principal/group.
4. Point the backend at production's remote state (see the comment in
   `versions.tf`).
5. Decommission this dev stack (`terraform destroy`) once the pipelines are
   confirmed working in production, since it's explicitly temporary.
