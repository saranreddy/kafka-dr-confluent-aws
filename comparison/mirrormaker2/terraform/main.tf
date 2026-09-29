# MirrorMaker 2 on MSK Connect - Alternative DR Solution
# This configuration sets up Kafka on Amazon MSK instead of Confluent Cloud

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region_primary
}

provider "aws" {
  alias  = "secondary"
  region = var.aws_region_secondary
}

# VPC for MSK
resource "aws_vpc" "msk_primary" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.environment_name}-msk-primary-vpc"
  }
}

resource "aws_subnet" "msk_primary" {
  count             = 3
  vpc_id            = aws_vpc.msk_primary.id
  cidr_block        = "10.10.${count.index}.0/24"
  availability_zone = data.aws_availability_zones.primary.names[count.index]

  tags = {
    Name = "${var.environment_name}-msk-primary-subnet-${count.index + 1}"
  }
}

data "aws_availability_zones" "primary" {
  state = "available"
}

# Security Group for MSK
resource "aws_security_group" "msk_primary" {
  name        = "${var.environment_name}-msk-primary-sg"
  description = "Security group for MSK cluster"
  vpc_id      = aws_vpc.msk_primary.id

  ingress {
    from_port   = 9092
    to_port     = 9098
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.msk_primary.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment_name}-msk-primary-sg"
  }
}

# MSK Configuration
resource "aws_msk_configuration" "primary" {
  name              = "${var.environment_name}-msk-config"
  kafka_versions    = ["3.5.1"]
  server_properties = <<PROPERTIES
auto.create.topics.enable=true
delete.topic.enable=true
log.retention.hours=168
num.partitions=6
default.replication.factor=3
min.insync.replicas=2
PROPERTIES
}

# Primary MSK Cluster
resource "aws_msk_cluster" "primary" {
  cluster_name           = "${var.environment_name}-primary"
  kafka_version          = "3.5.1"
  number_of_broker_nodes = 3

  broker_node_group_info {
    instance_type   = var.msk_instance_type
    client_subnets  = aws_subnet.msk_primary[*].id
    security_groups = [aws_security_group.msk_primary.id]

    storage_info {
      ebs_storage_info {
        volume_size = var.msk_volume_size
      }
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.primary.arn
    revision = aws_msk_configuration.primary.latest_revision
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  client_authentication {
    sasl {
      iam = true
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk_primary.name
      }
    }
  }

  tags = {
    Name = "${var.environment_name}-msk-primary"
  }
}

resource "aws_cloudwatch_log_group" "msk_primary" {
  name              = "/aws/msk/${var.environment_name}-primary"
  retention_in_days = 7
}

# MSK Connect Custom Plugin for MirrorMaker 2
resource "aws_s3_bucket" "msk_connect_plugins" {
  bucket = "${var.environment_name}-msk-connect-plugins"
}

# Note: In production, upload the MirrorMaker 2 connector JAR to this bucket
resource "aws_mskconnect_custom_plugin" "mirrormaker2" {
  name         = "${var.environment_name}-mirrormaker2"
  content_type = "ZIP"

  location {
    s3 {
      bucket_arn = aws_s3_bucket.msk_connect_plugins.arn
      file_key   = "kafka-connect-mirror-maker-2.zip"
    }
  }

  depends_on = [aws_s3_bucket.msk_connect_plugins]
}

# IAM Role for MSK Connect
resource "aws_iam_role" "msk_connect" {
  name = "${var.environment_name}-msk-connect-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "kafkaconnect.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "msk_connect_msk" {
  name = "${var.environment_name}-msk-connect-policy"
  role = aws_iam_role.msk_connect.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster",
          "kafka-cluster:ReadData",
          "kafka-cluster:WriteData",
          "kafka-cluster:CreateTopic",
          "kafka-cluster:DescribeTopic"
        ]
        Resource = [
          aws_msk_cluster.primary.arn,
          "${aws_msk_cluster.primary.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.msk_connect_plugins.arn,
          "${aws_s3_bucket.msk_connect_plugins.arn}/*"
        ]
      }
    ]
  })
}

# MirrorMaker 2 Connector Configuration
# Note: This would need to be created after MSK clusters are set up
# The configuration is provided in mirrormaker2-config.properties
