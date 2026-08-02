# ai-eval staging

Low-cost staging resources for `https://stg.ai-eval.jp`.

The staging application has separate ECS services, PostgreSQL/ClickHouse
databases, Redis key prefix, S3 bucket, secrets, logs, ECR repositories, and
TLS certificate. It reuses the production VPC, ALB, RDS instance, Redis
cluster, ClickHouse service, and ClickHouse login to avoid duplicating their
fixed monthly cost.

## Deploy

```bash
aws sso login --profile rd:engineering
terraform init
terraform plan
terraform apply
./scripts/bootstrap.sh
```

`terraform apply` creates the ECS services at desired count zero. The bootstrap
script initializes the logically separated PostgreSQL and ClickHouse databases,
then starts the web and worker services.

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

- No additional ALB, NAT Gateway, RDS instance, Redis cluster, or ClickHouse task.
- Web and worker use 0.5 vCPU / 1 GiB each.
- Staging S3 data expires after 30 days; logs expire after 7–14 days.
- To stop compute when staging is unused:

```bash
aws ecs update-service --profile rd:engineering --region ap-northeast-1 --cluster langfuse-stg --service langfuse-stg-web --desired-count 0
aws ecs update-service --profile rd:engineering --region ap-northeast-1 --cluster langfuse-stg --service langfuse-stg-worker --desired-count 0
```

This setup isolates data logically, not physically. A staging load spike can
still affect the shared production RDS, Redis, or ClickHouse capacity.
