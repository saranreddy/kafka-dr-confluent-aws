# VPC and Networking
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.environment_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment_name}-igw"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment_name}-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.environment_name}-private-subnet-${count.index + 1}"
  }
}

resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = {
    Name = "${var.environment_name}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "main" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.environment_name}-nat-${count.index + 1}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.environment_name}-public-rt"
  }
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.environment_name}-private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Security Groups
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.environment_name}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment_name}-ecs-tasks-sg"
  }
}

# ECR Repositories
resource "aws_ecr_repository" "producer" {
  name                 = "${var.environment_name}-producer"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.environment_name}-producer"
  }
}

resource "aws_ecr_repository" "consumer" {
  name                 = "${var.environment_name}-consumer"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.environment_name}-consumer"
  }
}

resource "aws_ecr_lifecycle_policy" "producer" {
  repository = aws_ecr_repository.producer.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "consumer" {
  repository = aws_ecr_repository.consumer.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# DynamoDB Table for Consumer Sink
resource "aws_dynamodb_table" "orders" {
  name         = "${var.environment_name}-orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "order_id"
  range_key    = "timestamp"

  attribute {
    name = "order_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.environment_name}-orders"
  }
}

# SSM Parameter for Active Bootstrap Endpoint
resource "aws_ssm_parameter" "active_bootstrap" {
  name        = "/${var.environment_name}/active-bootstrap-endpoint"
  description = "Active Kafka bootstrap endpoint (primary or secondary)"
  type        = "String"
  value       = var.primary_cluster_bootstrap_endpoint

  tags = {
    Name = "${var.environment_name}-active-bootstrap"
  }
}

# Secrets Manager for Confluent Credentials
resource "aws_secretsmanager_secret" "producer_credentials" {
  name                    = "${var.environment_name}-producer-credentials"
  description             = "Confluent Cloud producer credentials"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "producer_credentials" {
  secret_id = aws_secretsmanager_secret.producer_credentials.id
  secret_string = jsonencode({
    api_key    = var.producer_api_key_id
    api_secret = var.producer_api_key_secret
  })
}

resource "aws_secretsmanager_secret" "consumer_credentials" {
  name                    = "${var.environment_name}-consumer-credentials"
  description             = "Confluent Cloud consumer credentials"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "consumer_credentials" {
  secret_id = aws_secretsmanager_secret.consumer_credentials.id
  secret_string = jsonencode({
    api_key    = var.consumer_api_key_id
    api_secret = var.consumer_api_key_secret
  })
}

resource "aws_secretsmanager_secret" "schema_registry_credentials" {
  name                    = "${var.environment_name}-schema-registry-credentials"
  description             = "Schema Registry credentials"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "schema_registry_credentials" {
  secret_id = aws_secretsmanager_secret.schema_registry_credentials.id
  secret_string = jsonencode({
    url        = var.schema_registry_url
    api_key    = var.schema_registry_api_key
    api_secret = var.schema_registry_api_secret
  })
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.environment_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.environment_name}-cluster"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# IAM Roles
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.environment_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.environment_name}-ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "${var.environment_name}-ecs-secrets-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.producer_credentials.arn,
          aws_secretsmanager_secret.consumer_credentials.arn,
          aws_secretsmanager_secret.schema_registry_credentials.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          aws_ssm_parameter.active_bootstrap.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task" {
  name = "${var.environment_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.environment_name}-ecs-task-role"
  }
}

resource "aws_iam_role_policy" "ecs_task_dynamodb" {
  name = "${var.environment_name}-dynamodb-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchWriteItem"
      ]
      Resource = [
        aws_dynamodb_table.orders.arn
      ]
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_ssm" {
  name = "${var.environment_name}-ssm-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]
      Resource = [
        aws_ssm_parameter.active_bootstrap.arn
      ]
    }]
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "producer" {
  name              = "/ecs/${var.environment_name}-producer"
  retention_in_days = 7

  tags = {
    Name = "${var.environment_name}-producer"
  }
}

resource "aws_cloudwatch_log_group" "consumer" {
  name              = "/ecs/${var.environment_name}-consumer"
  retention_in_days = 7

  tags = {
    Name = "${var.environment_name}-consumer"
  }
}

# ECS Task Definitions
resource "aws_ecs_task_definition" "producer" {
  family                   = "${var.environment_name}-producer"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.producer_cpu
  memory                   = var.producer_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "producer"
    image = "${aws_ecr_repository.producer.repository_url}:latest"

    environment = [
      {
        name  = "TOPIC_NAME"
        value = "orders"
      },
      {
        name  = "MESSAGES_PER_SECOND"
        value = "1000"
      }
    ]

    secrets = [
      {
        name      = "KAFKA_BOOTSTRAP_SERVERS"
        valueFrom = aws_ssm_parameter.active_bootstrap.arn
      },
      {
        name      = "KAFKA_API_KEY"
        valueFrom = "${aws_secretsmanager_secret.producer_credentials.arn}:api_key::"
      },
      {
        name      = "KAFKA_API_SECRET"
        valueFrom = "${aws_secretsmanager_secret.producer_credentials.arn}:api_secret::"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.producer.name
        "awslogs-region"        = var.aws_region_primary
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = {
    Name = "${var.environment_name}-producer"
  }
}

resource "aws_ecs_task_definition" "consumer" {
  family                   = "${var.environment_name}-consumer"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.consumer_cpu
  memory                   = var.consumer_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "consumer"
    image = "${aws_ecr_repository.consumer.repository_url}:latest"

    environment = [
      {
        name  = "TOPIC_NAME"
        value = "orders"
      },
      {
        name  = "CONSUMER_GROUP"
        value = "orders-consumer-group"
      },
      {
        name  = "DYNAMODB_TABLE"
        value = aws_dynamodb_table.orders.name
      },
      {
        name  = "AWS_REGION"
        value = var.aws_region_primary
      }
    ]

    secrets = [
      {
        name      = "KAFKA_BOOTSTRAP_SERVERS"
        valueFrom = aws_ssm_parameter.active_bootstrap.arn
      },
      {
        name      = "KAFKA_API_KEY"
        valueFrom = "${aws_secretsmanager_secret.consumer_credentials.arn}:api_key::"
      },
      {
        name      = "KAFKA_API_SECRET"
        valueFrom = "${aws_secretsmanager_secret.consumer_credentials.arn}:api_secret::"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.consumer.name
        "awslogs-region"        = var.aws_region_primary
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = {
    Name = "${var.environment_name}-consumer"
  }
}

# ECS Services
resource "aws_ecs_service" "producer" {
  name            = "${var.environment_name}-producer"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.producer.arn
  desired_count   = var.producer_replicas
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  tags = {
    Name = "${var.environment_name}-producer"
  }
}

resource "aws_ecs_service" "consumer" {
  name            = "${var.environment_name}-consumer"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.consumer.arn
  desired_count   = var.consumer_replicas
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  tags = {
    Name = "${var.environment_name}-consumer"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", { stat = "Average" }],
            [".", "MemoryUtilization", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region_primary
          title  = "ECS Cluster Metrics"
        }
      },
      {
        type = "log"
        properties = {
          query  = "SOURCE '${aws_cloudwatch_log_group.producer.name}' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          region = var.aws_region_primary
          title  = "Producer Logs"
        }
      },
      {
        type = "log"
        properties = {
          query  = "SOURCE '${aws_cloudwatch_log_group.consumer.name}' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          region = var.aws_region_primary
          title  = "Consumer Logs"
        }
      }
    ]
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "producer_cpu_high" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.environment_name}-producer-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Producer CPU utilization is too high"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.producer.name
  }
}

resource "aws_cloudwatch_metric_alarm" "consumer_cpu_high" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.environment_name}-consumer-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Consumer CPU utilization is too high"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.consumer.name
  }
}
