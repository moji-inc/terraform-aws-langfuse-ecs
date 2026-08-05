# ai-eval staging

Low-cost staging resources for `https://stg.ai-eval.jp`.

The staging application has separate ECS services, application security groups,
PostgreSQL/ClickHouse databases and users, a single-node Valkey cache, S3 bucket,
secrets, logs, ECR repositories, and TLS certificate. It reuses the production
VPC, ALB, RDS instance, and ClickHouse service to avoid duplicating their fixed
monthly cost without giving staging access to production data credentials.

The shared ClickHouse task must enable SQL access management. That setting is
managed by `infra/modules/clickhouse`, and allows the bootstrap task to create a
user restricted to `langfuse_stg.*`.

## Deploy

First apply the production ClickHouse task change from `../infra` and wait for
`langfuse-clickhouse` to become stable. This enables SQL user management before
the staging bootstrap runs:

```bash
aws sso login --profile rd:engineering
cd ../infra
terraform plan -out=clickhouse-access.tfplan
terraform apply clickhouse-access.tfplan
aws ecs wait services-stable --profile rd:engineering --region ap-northeast-1 --cluster langfuse --services langfuse-clickhouse
cd ../staging
```

For a new staging stack:

```bash
terraform init
terraform plan
terraform apply
./scripts/bootstrap.sh
```

`terraform apply` creates the ECS services at desired count zero. The bootstrap
script initializes the logically separated PostgreSQL database and restricted
ClickHouse user. It migrates a task definition only when its Terraform-managed
configuration differs (the application image is ignored); otherwise it scales
the current web and worker task definitions without rolling back GitHub Actions
revisions.

When upgrading a legacy staging stack that still reads the production
ClickHouse secret, use a two-phase apply so the old task remains startable while
the bootstrap migrates it. Pause staging GitHub Actions during these commands.
The final apply removes that temporary permission, and the last bootstrap run
rechecks the service configuration without rolling back its image revision:

```bash
terraform plan -var allow_legacy_production_clickhouse_secret=true -out=staging-migration.tfplan
terraform apply staging-migration.tfplan
./scripts/bootstrap.sh
terraform plan -out=staging-final.tfplan
terraform apply staging-final.tfplan
./scripts/bootstrap.sh
```

Set these GitHub Environment variables on `staging` using the Terraform output:

```bash
gh variable set AWS_REGION --env staging --body ap-northeast-1 --repo moji-inc/ai-eval
gh variable set SERVICE_NAME --env staging --body langfuse-stg --repo moji-inc/ai-eval
gh variable set ECS_CLUSTER_NAME --env staging --body langfuse-stg --repo moji-inc/ai-eval
gh variable set ECS_WEB_SERVICE_NAME --env staging --body langfuse-stg-web --repo moji-inc/ai-eval
gh variable set ECS_WORKER_SERVICE_NAME --env staging --body langfuse-stg-worker --repo moji-inc/ai-eval
gh variable set AWS_ROLE_ARN --env staging --body "$(terraform output -raw github_actions_role_arn)" --repo moji-inc/ai-eval
```

Then deploy the current `main` image:

```bash
gh workflow run deploy.yml \
  --repo moji-inc/ai-eval \
  --ref main \
  -f service=all \
  -f environment=staging
```

## Cost controls

- No additional ALB, NAT Gateway, RDS instance, or ClickHouse task.
- One staging-only `cache.t4g.micro` Valkey node. Serverless Valkey is not used
  because its cluster-mode key routing is incompatible with the BullMQ queues.
- Web and worker use 0.5 vCPU / 1 GiB each.
- Staging S3 data expires after 30 days; logs expire after 7–14 days.
- To stop compute when staging is unused:

```bash
aws ecs update-service --profile rd:engineering --region ap-northeast-1 --cluster langfuse-stg --service langfuse-stg-web --desired-count 0
aws ecs update-service --profile rd:engineering --region ap-northeast-1 --cluster langfuse-stg --service langfuse-stg-worker --desired-count 0
```

PostgreSQL and ClickHouse remain physically shared, but staging uses separate
credentials and restricted security groups. A staging load spike can still
affect the shared production RDS or ClickHouse capacity.
