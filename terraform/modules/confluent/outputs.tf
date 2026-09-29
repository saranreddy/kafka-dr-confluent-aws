output "primary_cluster_id" {
  description = "Primary cluster ID"
  value       = confluent_kafka_cluster.primary.id
}

output "secondary_cluster_id" {
  description = "Secondary cluster ID"
  value       = confluent_kafka_cluster.secondary.id
}

output "primary_cluster_bootstrap_endpoint" {
  description = "Primary cluster bootstrap endpoint"
  value       = confluent_kafka_cluster.primary.bootstrap_endpoint
}

output "secondary_cluster_bootstrap_endpoint" {
  description = "Secondary cluster bootstrap endpoint"
  value       = confluent_kafka_cluster.secondary.bootstrap_endpoint
}

output "primary_environment_id" {
  description = "Primary environment ID"
  value       = confluent_environment.primary.id
}

output "secondary_environment_id" {
  description = "Secondary environment ID"
  value       = confluent_environment.secondary.id
}

output "cluster_link_id" {
  description = "Cluster link ID"
  value       = confluent_cluster_link.primary_to_secondary.id
}

output "producer_api_key_id" {
  description = "Producer API key ID"
  value       = confluent_api_key.producer_primary.id
  sensitive   = true
}

output "producer_api_key_secret" {
  description = "Producer API key secret"
  value       = confluent_api_key.producer_primary.secret
  sensitive   = true
}

output "consumer_api_key_id" {
  description = "Consumer API key ID"
  value       = confluent_api_key.consumer_primary.id
  sensitive   = true
}

output "consumer_api_key_secret" {
  description = "Consumer API key secret"
  value       = confluent_api_key.consumer_primary.secret
  sensitive   = true
}

output "producer_secondary_api_key_id" {
  description = "Producer secondary API key ID"
  value       = confluent_api_key.producer_secondary.id
  sensitive   = true
}

output "producer_secondary_api_key_secret" {
  description = "Producer secondary API key secret"
  value       = confluent_api_key.producer_secondary.secret
  sensitive   = true
}

output "consumer_secondary_api_key_id" {
  description = "Consumer secondary API key ID"
  value       = confluent_api_key.consumer_secondary.id
  sensitive   = true
}

output "consumer_secondary_api_key_secret" {
  description = "Consumer secondary API key secret"
  value       = confluent_api_key.consumer_secondary.secret
  sensitive   = true
}

output "schema_registry_endpoint" {
  description = "Schema Registry endpoint (placeholder - configure manually)"
  value       = local.schema_registry_endpoint
}

output "schema_registry_api_key_id" {
  description = "Schema Registry API key ID (placeholder - configure manually)"
  value       = "SR_API_KEY_PLACEHOLDER"
  sensitive   = true
}

output "schema_registry_api_key_secret" {
  description = "Schema Registry API key secret (placeholder - configure manually)"
  value       = "SR_API_SECRET_PLACEHOLDER"
  sensitive   = true
}

output "orders_topic_name" {
  description = "Orders topic name"
  value       = confluent_kafka_topic.orders_primary.topic_name
}
