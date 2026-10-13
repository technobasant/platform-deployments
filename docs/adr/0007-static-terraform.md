# 7. Terraform for AWS, checked but not applied

Status: accepted · 2026-10

## Context

The platform runs on kind. The question an operator asks next is what it would be
on a cloud account. Applying it would mean a bill and an account to clean up, for a
result nobody else could rerun.

## Decision

* `terraform/aws` describes the AWS shape: a VPC with private subnets, EKS with
  access entries, envelope-encrypted secrets, Pod Identity for the application and
  the VPC CNI, IRSA for the EBS CSI driver, RDS PostgreSQL with RDS-managed
  credentials, ECR with immutable tags, and one KMS key.
* CI runs `terraform fmt -check`, `terraform validate`, tflint with the AWS ruleset,
  trivy and checkov on it.
* It has never been applied. The README says so in its first lines about it.

## Consequences

* The configuration is valid and lint-clean; whether it deploys cleanly, and how
  long it takes, is unknown. No figure in MEASUREMENTS.md comes from AWS.
* Four checkov findings are skipped in code with a reason (three about `"*"` in a
  KMS key policy, where it means the key itself, and one about availability zone
  ordering).
