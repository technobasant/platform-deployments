variable "name" {
  description = "Cluster name, also the prefix for IAM roles."
  type        = string
}

variable "region" {
  description = "AWS region, used to scope kms:ViaService."
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version."
  type        = string
  default     = "1.35"
}

variable "subnet_ids" {
  description = "Private subnets for the control-plane ENIs and the nodes."
  type        = list(string)
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Empty keeps the endpoint private."
  type        = list(string)
  default     = []
}

variable "admin_principal_arns" {
  description = "IAM roles or users granted cluster-admin through access entries."
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "KMS key for secrets envelope encryption, node volumes and the log group."
  type        = string
}

variable "node_instance_types" {
  description = "Graviton instance types for the default node group."
  type        = list(string)
  default     = ["m7g.large"]
}

variable "node_min" {
  description = "Minimum (and initial) node count."
  type        = number
  default     = 3
}

variable "node_max" {
  description = "Maximum node count."
  type        = number
  default     = 6
}

variable "app_namespace" {
  description = "Namespace of the application's service account."
  type        = string
  default     = "governed-agent"
}

variable "app_service_account" {
  description = "Service account the application role is bound to."
  type        = string
  default     = "ga-api"
}

variable "app_secret_arns" {
  description = "Secrets Manager ARNs the application may read."
  type        = list(string)
}
