# PostgreSQL on RDS: private, encrypted, TLS required, the master password owned
# by RDS in Secrets Manager (never in state or tfvars), IAM auth available.
data "aws_partition" "this" {}

resource "aws_db_subnet_group" "this" {
  name_prefix = "${var.name}-"
  subnet_ids  = var.subnet_ids
}

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-db-"
  description = "PostgreSQL from the EKS cluster only"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "postgres" {
  for_each                     = toset(var.allowed_security_group_ids)
  security_group_id            = aws_security_group.this.id
  description                  = "PostgreSQL from ${each.value}"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = each.value
}

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.name}-pg17-"
  family      = "postgres17"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
  parameter {
    name  = "log_min_duration_statement"
    value = "500"
  }
}

data "aws_iam_policy_document" "monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  name_prefix        = "${var.name}-rds-mon-"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:${data.aws_partition.this.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_name                             = "app"
  username                            = "app_admin"
  manage_master_user_password         = true
  master_user_secret_kms_key_id       = var.kms_key_arn
  iam_database_authentication_enabled = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period    = 7
  copy_tags_to_snapshot      = true
  deletion_protection        = true
  skip_final_snapshot        = false
  final_snapshot_identifier  = "${var.name}-final"
  auto_minor_version_upgrade = true

  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.kms_key_arn
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.monitoring.arn
}
