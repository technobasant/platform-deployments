terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Never applied, so no backend is configured. A real environment would keep state
  # in S3 with native locking:
  #   backend "s3" { bucket = "<state-bucket>" key = "platform/demo.tfstate" region = "<region>" use_lockfile = true encrypt = true }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      project    = "platform-deployments"
      env        = var.env
      managed-by = "terraform"
    }
  }
}
