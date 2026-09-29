variable "environment_name" {
  description = "Environment name prefix"
  type        = string
  default     = "kafka-dr-mm2"
}

variable "aws_region_primary" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_region_secondary" {
  description = "Secondary AWS region"
  type        = string
  default     = "us-west-2"
}

variable "msk_instance_type" {
  description = "MSK broker instance type"
  type        = string
  default     = "kafka.m5.large"
}

variable "msk_volume_size" {
  description = "EBS volume size per broker in GB"
  type        = number
  default     = 100
}
