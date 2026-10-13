# The AWS shape of what the kind cluster runs: EKS instead of kind, RDS instead of
# CloudNativePG, ECR instead of `kind load`. Static: validated and scanned in CI,
# never applied (see ../README.md).
locals {
  name = "ga-${var.env}"
}

data "aws_caller_identity" "this" {}

data "aws_iam_policy_document" "kms" {
  # In a key policy "*" means this key, and root access is the AWS default policy.
  #checkov:skip=CKV_AWS_109:key policy; resource "*" is the key itself
  #checkov:skip=CKV_AWS_111:key policy; resource "*" is the key itself
  #checkov:skip=CKV_AWS_356:key policy; resource "*" is the key itself
  # The account root keeps control of the key (without it the key can become unmanageable).
  statement {
    sid       = "AccountAdmin"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.this.account_id}:root"]
    }
  }
  # CloudWatch Logs encrypts the flow-log and control-plane log groups with it.
  statement {
    sid       = "CloudWatchLogs"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.this.account_id}:log-group:*"]
    }
  }
}

resource "aws_kms_key" "this" {
  description             = "${local.name}: EKS secrets, RDS, ECR, logs"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms.json
}

resource "aws_kms_alias" "this" {
  name          = "alias/${local.name}"
  target_key_id = aws_kms_key.this.key_id
}

module "network" {
  source      = "../../modules/network"
  name        = local.name
  cidr        = var.vpc_cidr
  kms_key_arn = aws_kms_key.this.arn
}

module "ecr" {
  source       = "../../modules/ecr"
  repositories = ["governed-agent-python", "governed-agent-web"]
  kms_key_arn  = aws_kms_key.this.arn
}

module "eks" {
  source               = "../../modules/eks"
  name                 = local.name
  region               = var.region
  kubernetes_version   = var.kubernetes_version
  subnet_ids           = module.network.private_subnet_ids
  public_access_cidrs  = var.api_public_access_cidrs
  admin_principal_arns = var.admin_principal_arns
  kms_key_arn          = aws_kms_key.this.arn
  app_secret_arns      = [module.rds.master_user_secret_arn]
}

module "rds" {
  source                     = "../../modules/rds"
  name                       = local.name
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.private_subnet_ids
  allowed_security_group_ids = [module.eks.cluster_security_group_id]
  kms_key_arn                = aws_kms_key.this.arn
  multi_az                   = var.db_multi_az
}
