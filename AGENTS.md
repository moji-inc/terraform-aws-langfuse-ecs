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
