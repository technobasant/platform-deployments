variable "repositories" {
  description = "Repository names."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "KMS key for image encryption."
  type        = string
}

variable "keep_tagged" {
  description = "How many v* tagged images to keep per repository."
  type        = number
  default     = 30
}
