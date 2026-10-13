variable "name" {
  description = "Prefix for every resource name."
  type        = string
}

variable "cidr" {
  description = "VPC CIDR; split into three public and three private /20s."
  type        = string
  default     = "10.40.0.0/16"
}

variable "kms_key_arn" {
  description = "KMS key for the flow-log group."
  type        = string
}
