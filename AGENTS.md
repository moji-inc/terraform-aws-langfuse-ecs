# Agent Notes For terraform-aws-langfuse-ecs

This repository defines the AWS infrastructure for the `moji-inc/ai-eval`
Langfuse deployment.

## Current Deployment Reality

- Deployment model: self-hosted Langfuse on AWS ECS Fargate.
- Production URL: `https://ai-eval.jp`
- AWS region: `ap-northeast-1` (Tokyo)
- Service prefix: `langfuse`
- Default ECS cluster: `langfuse`
- Default ECS services: `langfuse-web`, `langfuse-worker`
- Current local production tfvars: `tfvars/prod.tfvars`
- Staging URL: `https://stg.ai-eval.jp`
- Staging configuration: `staging/` with state key
  `langfuse-staging/terraform.tfstate`
- Staging ECS services: `langfuse-stg-web`, `langfuse-stg-worker`
- Staging reuses the production VPC, ALB, RDS instance, and ClickHouse service,
  while using dedicated application security groups, a dedicated single-node
  Valkey cache, a database-scoped ClickHouse user, and separate PostgreSQL /
  ClickHouse databases, S3, secrets, ECR, and ECS services. Read
  `staging/README.md` before changing or operating it.

Do not infer this deployment is Langfuse Cloud US/EU/HIPAA or AWS US East from
upstream Langfuse examples. README examples should use Tokyo-region values unless
they explicitly describe a provider-specific global requirement.

When credentials are available, verify live state before answering operational
questions:

```bash
rg -n "aws_region|nextauth_url|custom_domain|certificate_arn" tfvars/prod.tfvars
aws ecs describe-services \
  --region ap-northeast-1 \
  --cluster langfuse \
  --services langfuse-web langfuse-worker
```
