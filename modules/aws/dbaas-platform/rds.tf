# RDS PostgreSQL Database for DBaaS Platform
# This database stores DBaaS platform metadata and state

# Random password generation for RDS master user
resource "random_password" "rds_master_password" {
  length  = 32
  special = true
  # Exclude characters that might cause issues in JDBC URLs or shell commands
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# DB Subnet Group for RDS (uses private subnets)
resource "aws_db_subnet_group" "dbaas_rds" {
  name       = "${var.env_prefix}-dbaas-rds-subnet-group"
  subnet_ids = aws_subnet.eks_private[*].id

  tags = merge(local.module_tags, {
    Name    = "${var.env_prefix}-dbaas-rds-subnet-group"
    Purpose = "RDS database subnet group for DBaaS platform"
  })
}

# Security Group for RDS
resource "aws_security_group" "dbaas_rds" {
  name        = "${var.env_prefix}-dbaas-rds-sg"
  description = "Security group for DBaaS RDS PostgreSQL instance"
  vpc_id      = var.vpc_id

  # Allow PostgreSQL traffic from EKS cluster security group
  ingress {
    description     = "PostgreSQL from EKS cluster"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.dbaas_cluster.vpc_config[0].cluster_security_group_id]
  }

  # Allow PostgreSQL traffic from EKS private subnets (alternative to security group)
  ingress {
    description = "PostgreSQL from EKS private subnets"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = aws_subnet.eks_private[*].cidr_block
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.module_tags, {
    Name    = "${var.env_prefix}-dbaas-rds-sg"
    Purpose = "RDS security group for DBaaS platform"
  })
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "dbaas_postgres" {
  # Instance identification
  identifier = "${var.env_prefix}-dbaas-postgres"

  # Database configuration
  engine               = "postgres"
  engine_version       = var.rds_engine_version
  instance_class       = var.rds_instance_class
  allocated_storage    = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_type         = var.rds_storage_type
  storage_encrypted    = var.rds_storage_encrypted

  # Database credentials
  db_name  = var.rds_database_name
  username = var.rds_master_username
  password = random_password.rds_master_password.result

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.dbaas_rds.name
  vpc_security_group_ids = [aws_security_group.dbaas_rds.id]
  publicly_accessible    = false
  port                   = 5432

  # Multi-AZ and availability
  multi_az = var.rds_multi_az

  # Backup configuration
  backup_retention_period = var.rds_backup_retention_days
  backup_window           = var.rds_backup_window
  maintenance_window      = var.rds_maintenance_window

  # Performance Insights
  performance_insights_enabled    = var.rds_performance_insights_enabled
  performance_insights_retention_period = var.rds_performance_insights_enabled ? 7 : null

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  monitoring_interval             = 60
  monitoring_role_arn            = aws_iam_role.rds_monitoring.arn

  # Protection and deletion
  deletion_protection = var.rds_deletion_protection
  skip_final_snapshot = var.rds_skip_final_snapshot
  final_snapshot_identifier = var.rds_skip_final_snapshot ? null : "${var.env_prefix}-dbaas-postgres-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Parameter group
  parameter_group_name = aws_db_parameter_group.dbaas_postgres.name

  # Auto minor version upgrade
  auto_minor_version_upgrade = var.rds_auto_minor_version_upgrade

  # Apply changes immediately or during maintenance window
  apply_immediately = var.rds_apply_immediately

  tags = merge(local.module_tags, {
    Name    = "${var.env_prefix}-dbaas-postgres"
    Purpose = "PostgreSQL database for DBaaS platform metadata"
  })

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier
    ]
  }
}

# DB Parameter Group for PostgreSQL tuning
resource "aws_db_parameter_group" "dbaas_postgres" {
  name   = "${var.env_prefix}-dbaas-postgres-params"
  family = "postgres${split(".", var.rds_engine_version)[0]}" # e.g., postgres16

  description = "Custom parameter group for DBaaS PostgreSQL instance"

  # Connection and authentication
  # Note: max_connections is a static parameter requiring reboot
  parameter {
    name         = "max_connections"
    value        = var.rds_max_connections
    apply_method = "pending-reboot"
  }

  # Logging configuration for better debugging (dynamic parameters)
  parameter {
    name         = "log_connections"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_disconnections"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_duration"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_statement"
    value        = "all"
    apply_method = "immediate"
  }

  tags = merge(local.module_tags, {
    Name    = "${var.env_prefix}-dbaas-postgres-params"
    Purpose = "Parameter group for DBaaS PostgreSQL"
  })
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.env_prefix}-dbaas-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.module_tags, {
    Name    = "${var.env_prefix}-dbaas-rds-monitoring-role"
    Purpose = "IAM role for RDS enhanced monitoring"
  })
}

# Attach AWS managed policy for RDS monitoring
resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Store RDS credentials in AWS Secrets Manager
resource "aws_secretsmanager_secret" "dbaas_rds_credentials" {
  name        = "${var.env_prefix}-dbaas-rds-credentials"
  description = "Database credentials for DBaaS RDS PostgreSQL instance"

  tags = merge(local.module_tags, {
    Name    = "${var.env_prefix}-dbaas-rds-credentials"
    Purpose = "RDS credentials for DBaaS platform"
  })
}

resource "aws_secretsmanager_secret_version" "dbaas_rds_credentials" {
  secret_id = aws_secretsmanager_secret.dbaas_rds_credentials.id
  secret_string = jsonencode({
    username = aws_db_instance.dbaas_postgres.username
    password = random_password.rds_master_password.result
    engine   = "postgres"
    host     = aws_db_instance.dbaas_postgres.address
    port     = aws_db_instance.dbaas_postgres.port
    dbname   = aws_db_instance.dbaas_postgres.db_name
    jdbc_url = "jdbc:postgresql://${aws_db_instance.dbaas_postgres.endpoint}/${aws_db_instance.dbaas_postgres.db_name}"
  })
}
