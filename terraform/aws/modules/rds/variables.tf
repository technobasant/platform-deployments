variable "name" {
  description = "DB instance identifier and resource prefix."
  type        = string
}

variable "vpc_id" {
  description = "VPC for the database security group."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the DB subnet group."
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to connect on 5432."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "KMS key for storage, the master-user secret and Performance Insights."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "17.6"
}

variable "instance_class" {
  description = "Instance class."
  type        = string
  default     = "db.t4g.medium"
}

variable "multi_az" {
  description = "Standby in a second AZ. Off halves the cost and loses automatic failover."
  type        = bool
  default     = true
}
