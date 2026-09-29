output "primary_cluster_bootstrap_endpoint" {
  description = "Bootstrap endpoint for primary cluster"
  value       = module.confluent.primary_cluster_bootstrap_endpoint
}

output "secondary_cluster_bootstrap_endpoint" {
  description = "Bootstrap endpoint for secondary cluster"
  value       = module.confluent.secondary_cluster_bootstrap_endpoint
}

output "primary_cluster_id" {
  description = "Primary cluster ID"
  value       = module.confluent.primary_cluster_id
}

output "secondary_cluster_id" {
  description = "Secondary cluster ID"
  value       = module.confluent.secondary_cluster_id
}

output "cluster_link_id" {
  description = "Cluster link ID"
  value       = module.confluent.cluster_link_id
}

output "schema_registry_endpoint" {
  description = "Schema Registry endpoint"
  value       = module.confluent.schema_registry_endpoint
}

output "producer_service_name" {
  description = "Producer ECS service name"
  value       = module.aws.producer_service_name
}

output "consumer_service_name" {
  description = "Consumer ECS service name"
  value       = module.aws.consumer_service_name
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for consumer sink"
  value       = module.aws.dynamodb_table_name
}

output "active_bootstrap_parameter_name" {
  description = "SSM parameter name for active bootstrap endpoint"
  value       = module.aws.active_bootstrap_parameter_name
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.aws.cloudwatch_dashboard_url
}

output "producer_ecr_repository_url" {
  description = "Producer ECR repository URL"
  value       = module.aws.producer_ecr_repository_url
}

output "consumer_ecr_repository_url" {
  description = "Consumer ECR repository URL"
  value       = module.aws.consumer_ecr_repository_url
}

output "producer_api_key_id" {
  description = "Producer API key ID"
  value       = module.confluent.producer_api_key_id
  sensitive   = true
}

output "consumer_api_key_id" {
  description = "Consumer API key ID"
  value       = module.confluent.consumer_api_key_id
  sensitive   = true
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.aws.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.aws.private_subnet_ids
}
