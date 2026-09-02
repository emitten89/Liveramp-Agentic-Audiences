# Setting up the AWS Databricks dev environment

**Status quo:** an AWS Databricks workspace already exists, but nothing else
does yet — no dedicated AWS account resources for it, no S3/IAM, no Unity
Catalog storage, no Terraform. This doc walks through getting from that
starting point to a working dev environment you can build pipelines against,
which is later ported into Publicis's production AWS Databricks + Terraform
stack.

Two things in this walkthrough need a human with real credentials and
console access — Claude can write and apply the Terraform, but can't create
an AWS account or click through the Databricks account console on your
behalf.

## 1. Confirm what you're starting from

Before touching Terraform, nail down these facts (ask a Databricks account
admin or check the account console if unsure):

- **Workspace URL** — `https://dbc-xxxxxxxx-xxxx.cloud.databricks.com`
- **Databricks account ID** — account console → Settings
- **Is a Unity Catalog metastore already assigned to this workspace?**
  Workspace admin console → Catalog. If not, this needs to happen before
  anything below — metastore assignment is account-level and isn't
  something this repo's Terraform manages (it's shared infrastructure,
  usually owned by whoever administers Publicis's Databricks account).
- **Which AWS account will host the dev environment's S3/IAM resources?**
  This can be a sandbox/dev AWS account distinct from whatever account the
  Databricks workspace's own control plane runs in — Unity Catalog storage
  credentials just need an IAM role in *some* account that Databricks is
  allowed to assume into.

## 2. AWS account & credentials (manual — needs a human)

If there truly is no AWS account yet for this dev work:

1. Get a sandbox/dev AWS account provisioned (via Publicis's AWS Organization
   if one exists — check with cloud/platform engineering before spinning up
   an unaffiliated account, since production Databricks likely already lives
   under an AWS Org that has logging, SCPs, and billing wired up).
2. Get an IAM identity for yourself (or a CI role) with permissions to
   create S3 buckets, IAM roles/policies, and read caller identity — that's
   all this Terraform needs.
3. Make those credentials available locally: `aws configure sso` (preferred)
   or `aws configure` with an access key, or export
   `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_SESSION_TOKEN`.

Verify with:

```bash
aws sts get-caller-identity
```

## 3. Databricks auth for Terraform

Generate a personal access token (workspace → user settings → Developer →
Access tokens) or, better for anything long-lived, a service-principal OAuth
token, and export:

```bash
export DATABRICKS_HOST="https://dbc-xxxxxxxx-xxxx.cloud.databricks.com"
export DATABRICKS_TOKEN="dapiXXXXXXXXXXXXXXXXXXXXXXXX"
```

## 4. Run the Terraform

The actual resource definitions live in
[`infra/terraform/dev/`](../infra/terraform/dev/) — S3 bucket, IAM role,
Unity Catalog storage credential/external location/catalog/schema/volume,
and a small SQL warehouse + cluster policy. Full usage instructions
(including why it needs two `terraform apply` runs) are in that directory's
[README](../infra/terraform/dev/README.md). In short:

```bash
cd infra/terraform/dev
cp terraform.tfvars.example terraform.tfvars   # fill in your values
terraform init
terraform apply                                 # first pass
terraform output storage_credential_external_id  # copy into tfvars
terraform apply                                 # second pass, tightens IAM trust
```

## 5. Verify

- Databricks workspace UI → Catalog → you should see the new catalog
  (`liveramp_agentic_audiences` by default) with a `dev` schema and a
  `raw_files` volume.
- SQL editor: `SELECT current_catalog(), current_schema();` after `USE
  liveramp_agentic_audiences.dev;` should resolve without permission errors.
- `aws s3 ls s3://<landing_bucket_name>/` should work with your AWS
  credentials (bucket is private, so this is really just confirming it
  exists and you can reach it).

## 6. Build pipelines against it

Pipeline code goes in [`pipelines/`](../pipelines/), following the
bronze → silver → gold pattern (see
[`pipelines/audience/audience_index_etl.py`](../pipelines/audience/audience_index_etl.py)
for a starting skeleton). Point pipeline config at the catalog/schema/volume
from the Terraform outputs, not hardcoded names, so moving to production
later is a config change.

## 7. Migrating to production

This dev environment is explicitly temporary. When pipelines built here are
ready for Publicis's production AWS Databricks + Terraform:

- Don't copy this dev Terraform's *state* into production — port the
  resource definitions (or better, reuse whatever shared modules the
  production stack already has for storage-credential/external-location,
  since MRCL's platform-wide conventions likely already codify this — see
  the `mrcl-databricks-pipelines` skill for the naming/DDL conventions
  production tables follow) and apply them in production's own Terraform
  workspace, with production's own AWS account and remote state backend.
- Rename the catalog/schema to whatever production's namespace convention
  expects for this project instead of `liveramp_agentic_audiences.dev`.
- Replace the wide-open `account users` grant with the real principal.
- Tear down this dev stack (`terraform destroy` from
  `infra/terraform/dev/`) once production is confirmed working, so it
  doesn't linger as an unmanaged, unmonitored copy of the data.
