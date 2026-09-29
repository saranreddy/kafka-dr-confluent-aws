variable "environment_name" {
  description = "Environment name prefix"
  type        = string
}

variable "aws_region_primary" {
  description = "Primary AWS region"
  type        = string
}

variable "aws_region_secondary" {
  description = "Secondary AWS region"
  type        = string
}

variable "primary_cluster_bootstrap_endpoint" {
  description = "Primary cluster bootstrap endpoint"
  type        = string
}

variable "producer_replicas" {
  description = "Number of producer replicas"
  type        = number
}

variable "consumer_replicas" {
  description = "Number of consumer replicas"
  type        = number
}

variable "producer_cpu" {
  description = "CPU units for producer task"
  type        = number
}

variable "producer_memory" {
  description = "Memory for producer task in MB"
  type        = number
}

variable "consumer_cpu" {
  description = "CPU units for consumer task"
  type        = number
}

variable "consumer_memory" {
  description = "Memory for consumer task in MB"
  type        = number
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
}

variable "mirror_lag_alarm_threshold" {
  description = "Mirror lag threshold for alarms"
  type        = number
}

variable "producer_api_key_id" {
  description = "Producer API key ID"
  type        = string
  sensitive   = true
}

variable "producer_api_key_secret" {
  description = "Producer API key secret"
  type        = string
  sensitive   = true
}

variable "consumer_api_key_id" {
  description = "Consumer API key ID"
  type        = string
  sensitive   = true
}

variable "consumer_api_key_secret" {
  description = "Consumer API key secret"
  type        = string
  sensitive   = true
}

variable "schema_registry_url" {
  description = "Schema Registry URL"
  type        = string
}

variable "schema_registry_api_key" {
  description = "Schema Registry API key"
  type        = string
  sensitive   = true
}

variable "schema_registry_api_secret" {
  description = "Schema Registry API secret"
  type        = string
  sensitive   = true
}
