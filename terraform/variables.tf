variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
}

variable "aws_region_primary" {
  description = "Primary AWS region for Confluent Cloud cluster"
  type        = string
  default     = "us-east-1"
}

variable "aws_region_secondary" {
  description = "Secondary AWS region for Confluent Cloud cluster"
  type        = string
  default     = "us-west-2"
}

variable "environment_name" {
  description = "Environment name prefix"
  type        = string
  default     = "kafka-dr-demo"
}

variable "cluster_availability" {
  description = "Cluster availability zone configuration"
  type        = string
  default     = "SINGLE_ZONE"
}

variable "cluster_type" {
  description = "Cluster type (BASIC, STANDARD, DEDICATED)"
  type        = string
  default     = "BASIC"
}

variable "orders_topic_partitions" {
  description = "Number of partitions for orders topic"
  type        = number
  default     = 6
}

variable "orders_topic_retention_ms" {
  description = "Retention period for orders topic in milliseconds"
  type        = number
  default     = 604800000 # 7 days
}

variable "producer_replicas" {
  description = "Number of producer replicas"
  type        = number
  default     = 2
}

variable "consumer_replicas" {
  description = "Number of consumer replicas"
  type        = number
  default     = 2
}

variable "producer_cpu" {
  description = "CPU units for producer task (1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "producer_memory" {
  description = "Memory for producer task in MB"
  type        = number
  default     = 1024
}

variable "consumer_cpu" {
  description = "CPU units for consumer task (1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "consumer_memory" {
  description = "Memory for consumer task in MB"
  type        = number
  default     = 1024
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "mirror_lag_alarm_threshold" {
  description = "Mirror lag threshold in messages for CloudWatch alarm"
  type        = number
  default     = 10000
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "kafka-dr-demo"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
