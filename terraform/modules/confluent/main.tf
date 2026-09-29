# Primary Environment and Cluster
resource "confluent_environment" "primary" {
  display_name = "${var.environment_name}-primary"

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_kafka_cluster" "primary" {
  display_name = "${var.environment_name}-primary-cluster"
  availability = var.cluster_availability
  cloud        = "AWS"
  region       = var.aws_region_primary
  
  dynamic "basic" {
    for_each = var.cluster_type == "BASIC" ? [1] : []
    content {}
  }
  
  dynamic "standard" {
    for_each = var.cluster_type == "STANDARD" ? [1] : []
    content {}
  }

  environment {
    id = confluent_environment.primary.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Secondary Environment and Cluster
resource "confluent_environment" "secondary" {
  display_name = "${var.environment_name}-secondary"

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_kafka_cluster" "secondary" {
  display_name = "${var.environment_name}-secondary-cluster"
  availability = var.cluster_availability
  cloud        = "AWS"
  region       = var.aws_region_secondary
  
  dynamic "basic" {
    for_each = var.cluster_type == "BASIC" ? [1] : []
    content {}
  }
  
  dynamic "standard" {
    for_each = var.cluster_type == "STANDARD" ? [1] : []
    content {}
  }

  environment {
    id = confluent_environment.secondary.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Service Accounts
resource "confluent_service_account" "producer" {
  display_name = "${var.environment_name}-producer"
  description  = "Service account for producer application"
}

resource "confluent_service_account" "consumer" {
  display_name = "${var.environment_name}-consumer"
  description  = "Service account for consumer application"
}

resource "confluent_service_account" "cluster_link" {
  display_name = "${var.environment_name}-cluster-link"
  description  = "Service account for cluster linking"
}

# API Keys for Primary Cluster
resource "confluent_api_key" "producer_primary" {
  display_name = "${var.environment_name}-producer-primary-key"
  description  = "Producer API key for primary cluster"

  owner {
    id          = confluent_service_account.producer.id
    api_version = confluent_service_account.producer.api_version
    kind        = confluent_service_account.producer.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.primary.id
    api_version = confluent_kafka_cluster.primary.api_version
    kind        = confluent_kafka_cluster.primary.kind

    environment {
      id = confluent_environment.primary.id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_api_key" "consumer_primary" {
  display_name = "${var.environment_name}-consumer-primary-key"
  description  = "Consumer API key for primary cluster"

  owner {
    id          = confluent_service_account.consumer.id
    api_version = confluent_service_account.consumer.api_version
    kind        = confluent_service_account.consumer.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.primary.id
    api_version = confluent_kafka_cluster.primary.api_version
    kind        = confluent_kafka_cluster.primary.kind

    environment {
      id = confluent_environment.primary.id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# API Keys for Secondary Cluster
resource "confluent_api_key" "producer_secondary" {
  display_name = "${var.environment_name}-producer-secondary-key"
  description  = "Producer API key for secondary cluster"

  owner {
    id          = confluent_service_account.producer.id
    api_version = confluent_service_account.producer.api_version
    kind        = confluent_service_account.producer.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.secondary.id
    api_version = confluent_kafka_cluster.secondary.api_version
    kind        = confluent_kafka_cluster.secondary.kind

    environment {
      id = confluent_environment.secondary.id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_api_key" "consumer_secondary" {
  display_name = "${var.environment_name}-consumer-secondary-key"
  description  = "Consumer API key for secondary cluster"

  owner {
    id          = confluent_service_account.consumer.id
    api_version = confluent_service_account.consumer.api_version
    kind        = confluent_service_account.consumer.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.secondary.id
    api_version = confluent_kafka_cluster.secondary.api_version
    kind        = confluent_kafka_cluster.secondary.kind

    environment {
      id = confluent_environment.secondary.id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Cluster Link API Key
resource "confluent_api_key" "cluster_link" {
  display_name = "${var.environment_name}-cluster-link-key"
  description  = "API key for cluster linking"

  owner {
    id          = confluent_service_account.cluster_link.id
    api_version = confluent_service_account.cluster_link.api_version
    kind        = confluent_service_account.cluster_link.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.primary.id
    api_version = confluent_kafka_cluster.primary.api_version
    kind        = confluent_kafka_cluster.primary.kind

    environment {
      id = confluent_environment.primary.id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Orders Topic on Primary Cluster
resource "confluent_kafka_topic" "orders_primary" {
  kafka_cluster {
    id = confluent_kafka_cluster.primary.id
  }

  topic_name       = "orders"
  partitions_count = var.orders_topic_partitions
  rest_endpoint    = confluent_kafka_cluster.primary.rest_endpoint

  config = {
    "retention.ms"    = tostring(var.orders_topic_retention_ms)
    "cleanup.policy"  = "delete"
    "compression.type" = "snappy"
  }

  credentials {
    key    = confluent_api_key.producer_primary.id
    secret = confluent_api_key.producer_primary.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

# ACLs for Producer on Primary Cluster
resource "confluent_kafka_acl" "producer_write_primary" {
  kafka_cluster {
    id = confluent_kafka_cluster.primary.id
  }

  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.orders_primary.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.producer.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.primary.rest_endpoint

  credentials {
    key    = confluent_api_key.producer_primary.id
    secret = confluent_api_key.producer_primary.secret
  }
}

resource "confluent_kafka_acl" "producer_describe_primary" {
  kafka_cluster {
    id = confluent_kafka_cluster.primary.id
  }

  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.orders_primary.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.producer.id}"
  host          = "*"
  operation     = "DESCRIBE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.primary.rest_endpoint

  credentials {
    key    = confluent_api_key.producer_primary.id
    secret = confluent_api_key.producer_primary.secret
  }
}

# ACLs for Consumer on Primary Cluster
resource "confluent_kafka_acl" "consumer_read_primary" {
  kafka_cluster {
    id = confluent_kafka_cluster.primary.id
  }

  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.orders_primary.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.primary.rest_endpoint

  credentials {
    key    = confluent_api_key.consumer_primary.id
    secret = confluent_api_key.consumer_primary.secret
  }
}

resource "confluent_kafka_acl" "consumer_group_primary" {
  kafka_cluster {
    id = confluent_kafka_cluster.primary.id
  }

  resource_type = "GROUP"
  resource_name = "orders-consumer-group"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.primary.rest_endpoint

  credentials {
    key    = confluent_api_key.consumer_primary.id
    secret = confluent_api_key.consumer_primary.secret
  }
}

# Schema Registry
resource "confluent_schema_registry_cluster" "main" {
  package = "ESSENTIALS"

  environment {
    id = confluent_environment.primary.id
  }

  region {
    id = data.confluent_schema_registry_region.primary.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

data "confluent_schema_registry_region" "primary" {
  cloud   = "AWS"
  region  = var.aws_region_primary
  package = "ESSENTIALS"
}

resource "confluent_api_key" "schema_registry" {
  display_name = "${var.environment_name}-schema-registry-key"
  description  = "API key for Schema Registry"

  owner {
    id          = confluent_service_account.producer.id
    api_version = confluent_service_account.producer.api_version
    kind        = confluent_service_account.producer.kind
  }

  managed_resource {
    id          = confluent_schema_registry_cluster.main.id
    api_version = confluent_schema_registry_cluster.main.api_version
    kind        = confluent_schema_registry_cluster.main.kind

    environment {
      id = confluent_environment.primary.id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Cluster Link from Primary to Secondary
resource "confluent_cluster_link" "primary_to_secondary" {
  link_name = "${var.environment_name}-primary-to-secondary"
  link_mode = "DESTINATION"

  source_kafka_cluster {
    id                 = confluent_kafka_cluster.primary.id
    bootstrap_endpoint = confluent_kafka_cluster.primary.bootstrap_endpoint
    credentials {
      key    = confluent_api_key.cluster_link.id
      secret = confluent_api_key.cluster_link.secret
    }
  }

  destination_kafka_cluster {
    id            = confluent_kafka_cluster.secondary.id
    rest_endpoint = confluent_kafka_cluster.secondary.rest_endpoint
    credentials {
      key    = confluent_api_key.producer_secondary.id
      secret = confluent_api_key.producer_secondary.secret
    }
  }

  config = {
    "consumer.offset.sync.enable" = "true"
    "consumer.offset.sync.ms"     = "30000"
    "acl.sync.enable"             = "true"
    "acl.sync.ms"                 = "30000"
  }

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [
    confluent_kafka_topic.orders_primary
  ]
}

# Mirror Topic on Secondary Cluster
resource "confluent_kafka_mirror_topic" "orders_mirror" {
  source_kafka_topic {
    topic_name = confluent_kafka_topic.orders_primary.topic_name
  }

  cluster_link {
    link_name = confluent_cluster_link.primary_to_secondary.link_name
  }

  kafka_cluster {
    id            = confluent_kafka_cluster.secondary.id
    rest_endpoint = confluent_kafka_cluster.secondary.rest_endpoint
    credentials {
      key    = confluent_api_key.producer_secondary.id
      secret = confluent_api_key.producer_secondary.secret
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# ACLs for Producer on Secondary Cluster (for failover)
resource "confluent_kafka_acl" "producer_write_secondary" {
  kafka_cluster {
    id = confluent_kafka_cluster.secondary.id
  }

  resource_type = "TOPIC"
  resource_name = "orders"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.producer.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.secondary.rest_endpoint

  credentials {
    key    = confluent_api_key.producer_secondary.id
    secret = confluent_api_key.producer_secondary.secret
  }
}

# ACLs for Consumer on Secondary Cluster (for failover)
resource "confluent_kafka_acl" "consumer_read_secondary" {
  kafka_cluster {
    id = confluent_kafka_cluster.secondary.id
  }

  resource_type = "TOPIC"
  resource_name = "orders"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.secondary.rest_endpoint

  credentials {
    key    = confluent_api_key.consumer_secondary.id
    secret = confluent_api_key.consumer_secondary.secret
  }
}

resource "confluent_kafka_acl" "consumer_group_secondary" {
  kafka_cluster {
    id = confluent_kafka_cluster.secondary.id
  }

  resource_type = "GROUP"
  resource_name = "orders-consumer-group"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.secondary.rest_endpoint

  credentials {
    key    = confluent_api_key.consumer_secondary.id
    secret = confluent_api_key.consumer_secondary.secret
  }
}
