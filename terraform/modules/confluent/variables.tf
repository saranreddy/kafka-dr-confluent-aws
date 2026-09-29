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

variable "cluster_availability" {
  description = "Cluster availability zone configuration"
  type        = string
}

variable "cluster_type" {
  description = "Cluster type (BASIC, STANDARD, DEDICATED)"
  type        = string
}

variable "orders_topic_partitions" {
  description = "Number of partitions for orders topic"
  type        = number
}

variable "orders_topic_retention_ms" {
  description = "Retention period for orders topic in milliseconds"
  type        = number
}
