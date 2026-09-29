provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

provider "aws" {
  region = var.aws_region_primary

  default_tags {
    tags = var.tags
  }
}

provider "aws" {
  alias  = "secondary"
  region = var.aws_region_secondary

  default_tags {
    tags = var.tags
  }
}

module "confluent" {
  source = "./modules/confluent"

  environment_name          = var.environment_name
  aws_region_primary        = var.aws_region_primary
  aws_region_secondary      = var.aws_region_secondary
  cluster_availability      = var.cluster_availability
  cluster_type              = var.cluster_type
  orders_topic_partitions   = var.orders_topic_partitions
  orders_topic_retention_ms = var.orders_topic_retention_ms
}

module "aws" {
  source = "./modules/aws"

  environment_name                   = var.environment_name
  aws_region_primary                 = var.aws_region_primary
  aws_region_secondary               = var.aws_region_secondary
  primary_cluster_bootstrap_endpoint = module.confluent.primary_cluster_bootstrap_endpoint
  producer_replicas                  = var.producer_replicas
  consumer_replicas                  = var.consumer_replicas
  producer_cpu                       = var.producer_cpu
  producer_memory                    = var.producer_memory
  consumer_cpu                       = var.consumer_cpu
  consumer_memory                    = var.consumer_memory
  enable_cloudwatch_alarms           = var.enable_cloudwatch_alarms
  mirror_lag_alarm_threshold         = var.mirror_lag_alarm_threshold

  # Confluent credentials for applications
  producer_api_key_id        = module.confluent.producer_api_key_id
  producer_api_key_secret    = module.confluent.producer_api_key_secret
  consumer_api_key_id        = module.confluent.consumer_api_key_id
  consumer_api_key_secret    = module.confluent.consumer_api_key_secret
  schema_registry_url        = module.confluent.schema_registry_endpoint
  schema_registry_api_key    = module.confluent.schema_registry_api_key_id
  schema_registry_api_secret = module.confluent.schema_registry_api_key_secret
}
