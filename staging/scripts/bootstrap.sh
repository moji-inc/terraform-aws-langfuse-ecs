#!/usr/bin/env bash

set -euo pipefail

PROFILE_NAME="${PROFILE_NAME:-rd:engineering}"
STAGING_REGION="${STAGING_REGION:-ap-northeast-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGING_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

command -v aws >/dev/null || { echo "aws CLI is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
command -v terraform >/dev/null || { echo "terraform is required" >&2; exit 1; }

tf_output() {
  AWS_PROFILE="${PROFILE_NAME}" terraform -chdir="${STAGING_DIR}" output -raw "$1"
}

STAGING_CLUSTER="$(tf_output ecs_cluster_name)"
STAGING_WEB_SERVICE="$(tf_output ecs_web_service_name)"
STAGING_WEB_TASK="$(tf_output ecs_web_task_definition)"
STAGING_WORKER_SERVICE="$(tf_output ecs_worker_service_name)"
STAGING_WORKER_TASK="$(tf_output ecs_worker_task_definition)"
POSTGRES_INIT_TASK="$(tf_output postgres_init_task_definition)"
CLICKHOUSE_INIT_TASK="$(tf_output clickhouse_init_task_definition)"
INIT_SECURITY_GROUP="$(tf_output init_security_group_id)"
PRIVATE_SUBNETS="$(AWS_PROFILE="${PROFILE_NAME}" terraform -chdir="${STAGING_DIR}" output -json private_subnet_ids | jq -r 'join(",")')"

NETWORK_CONFIGURATION="awsvpcConfiguration={subnets=[${PRIVATE_SUBNETS}],securityGroups=[${INIT_SECURITY_GROUP}],assignPublicIp=DISABLED}"

run_init_task() {
  local task_definition="$1"
  local label="$2"
  local task_arn
  local exit_code
  local stop_reason

  echo "Starting ${label} initialization..."
  task_arn="$(aws ecs run-task \
    --profile "${PROFILE_NAME}" \
    --region "${STAGING_REGION}" \
    --cluster "${STAGING_CLUSTER}" \
    --launch-type FARGATE \
    --task-definition "${task_definition}" \
    --network-configuration "${NETWORK_CONFIGURATION}" \
    --query 'tasks[0].taskArn' \
    --output text)"

  if [[ -z "${task_arn}" || "${task_arn}" == "None" ]]; then
    echo "Failed to start ${label} initialization task." >&2
    exit 1
  fi

  aws ecs wait tasks-stopped \
    --profile "${PROFILE_NAME}" \
    --region "${STAGING_REGION}" \
    --cluster "${STAGING_CLUSTER}" \
    --tasks "${task_arn}"

  exit_code="$(aws ecs describe-tasks \
    --profile "${PROFILE_NAME}" \
    --region "${STAGING_REGION}" \
    --cluster "${STAGING_CLUSTER}" \
    --tasks "${task_arn}" \
    --query 'tasks[0].containers[0].exitCode' \
    --output text)"
  stop_reason="$(aws ecs describe-tasks \
    --profile "${PROFILE_NAME}" \
    --region "${STAGING_REGION}" \
    --cluster "${STAGING_CLUSTER}" \
    --tasks "${task_arn}" \
    --query 'tasks[0].stoppedReason' \
    --output text)"

  if [[ "${exit_code}" != "0" ]]; then
    echo "${label} initialization failed: ${stop_reason}" >&2
    exit 1
  fi

  echo "${label} initialization completed."
}

run_init_task "${POSTGRES_INIT_TASK}" "PostgreSQL"
run_init_task "${CLICKHOUSE_INIT_TASK}" "ClickHouse"

normalized_task_definition() {
  local task_definition="$1"
  local container_name="$2"

  aws ecs describe-task-definition \
    --profile "${PROFILE_NAME}" \
    --region "${STAGING_REGION}" \
    --task-definition "${task_definition}" \
    --query taskDefinition \
    --output json | jq -cS --arg container_name "${container_name}" '
      del(
        .taskDefinitionArn,
        .revision,
        .status,
        .requiresAttributes,
        .compatibilities,
        .registeredAt,
        .registeredBy,
        .deregisteredAt
      )
      | .containerDefinitions |= map(
          if .name == $container_name then del(.image) else . end
        )
    '
}

start_service() {
  local service_name="$1"
  local desired_task_definition="$2"
  local container_name="$3"
  local label="$4"
  local current_task_definition
  local current_settings
  local desired_settings
  local migrate_task_definition=false

  current_task_definition="$(aws ecs describe-services \
    --profile "${PROFILE_NAME}" \
    --region "${STAGING_REGION}" \
    --cluster "${STAGING_CLUSTER}" \
    --services "${service_name}" \
    --query 'services[0].taskDefinition' \
    --output text)"
  current_settings="$(normalized_task_definition "${current_task_definition}" "${container_name}")"
  desired_settings="$(normalized_task_definition "${desired_task_definition}" "${container_name}")"

  if [[ "${current_settings}" != "${desired_settings}" ]]; then
    echo "Migrating ${label} to the isolated staging data configuration..."
    migrate_task_definition=true
  else
    echo "Preserving the current ${label} task-definition revision."
  fi

  if [[ "${migrate_task_definition}" == "true" ]]; then
    aws ecs update-service \
      --profile "${PROFILE_NAME}" \
      --region "${STAGING_REGION}" \
      --cluster "${STAGING_CLUSTER}" \
      --service "${service_name}" \
      --task-definition "${desired_task_definition}" \
      --desired-count 1 \
      --output json >/dev/null
  else
    aws ecs update-service \
      --profile "${PROFILE_NAME}" \
      --region "${STAGING_REGION}" \
      --cluster "${STAGING_CLUSTER}" \
      --service "${service_name}" \
      --desired-count 1 \
      --output json >/dev/null
  fi

  echo "Waiting for the staging ${label} service to become stable..."
  aws ecs wait services-stable \
    --profile "${PROFILE_NAME}" \
    --region "${STAGING_REGION}" \
    --cluster "${STAGING_CLUSTER}" \
    --services "${service_name}"
}

echo "Starting staging ECS services..."
start_service "${STAGING_WEB_SERVICE}" "${STAGING_WEB_TASK}" "langfuse-web" "web"
start_service "${STAGING_WORKER_SERVICE}" "${STAGING_WORKER_TASK}" "langfuse-worker" "worker"

echo "Staging initialization is complete."
