output "url" {
  value = "https://${var.domain_name}"
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.staging.name
}

output "ecs_web_service_name" {
  value = aws_ecs_service.web.name
}

output "ecs_web_task_definition" {
  value = aws_ecs_task_definition.web.arn
}

output "ecs_worker_service_name" {
  value = aws_ecs_service.worker.name
}

output "ecs_worker_task_definition" {
  value = aws_ecs_task_definition.worker.arn
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "postgres_init_task_definition" {
  value = aws_ecs_task_definition.postgres_init.arn
}

output "clickhouse_init_task_definition" {
  value = aws_ecs_task_definition.clickhouse_init.arn
}

output "private_subnet_ids" {
  value = local.private_subnet_ids
}

output "init_security_group_id" {
  value = data.aws_security_group.web.id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.staging.id
}
