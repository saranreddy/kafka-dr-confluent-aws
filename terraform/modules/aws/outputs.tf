output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "producer_ecr_repository_url" {
  description = "Producer ECR repository URL"
  value       = aws_ecr_repository.producer.repository_url
}

output "consumer_ecr_repository_url" {
  description = "Consumer ECR repository URL"
  value       = aws_ecr_repository.consumer.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "producer_service_name" {
  description = "Producer ECS service name"
  value       = aws_ecs_service.producer.name
}

output "consumer_service_name" {
  description = "Consumer ECS service name"
  value       = aws_ecs_service.consumer.name
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.orders.name
}

output "active_bootstrap_parameter_name" {
  description = "SSM parameter name for active bootstrap"
  value       = aws_ssm_parameter.active_bootstrap.name
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region_primary}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "producer_log_group" {
  description = "Producer CloudWatch log group name"
  value       = aws_cloudwatch_log_group.producer.name
}

output "consumer_log_group" {
  description = "Consumer CloudWatch log group name"
  value       = aws_cloudwatch_log_group.consumer.name
}
