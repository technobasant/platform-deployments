variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-1"
}

variable "env" {
  description = "Environment name, used in resource names and tags."
  type        = string
  default     = "demo"
}

variable "vpc_cidr" {
  description = "VPC CIDR."
  type        = string
  default     = "10.40.0.0/16"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version."
  type        = string
  default     = "1.35"
}

variable "api_public_access_cidrs" {
  description = "CIDRs allowed on the public EKS API endpoint; empty keeps it private."
  type        = list(string)
  default     = []
}

variable "admin_principal_arns" {
  description = "IAM principals granted cluster-admin."
  type        = list(string)
  default     = []
}

variable "db_multi_az" {
  description = "Run the RDS standby in a second AZ."
  type        = bool
  default     = true
}
