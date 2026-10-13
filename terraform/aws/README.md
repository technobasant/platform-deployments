# terraform/aws

**This configuration has never been applied to an AWS account.** It is validated and
scanned in CI; no figure anywhere in this repository comes from AWS, and whether it
deploys cleanly on the first `apply` is unknown.

It describes what the kind platform would be on AWS:

| kind cluster | AWS (`envs/demo`) |
|---|---|
| three kind nodes | EKS 1.35, a managed Graviton node group (3–6 × m7g.large) in private subnets |
| CloudNativePG `ga-pg` | RDS PostgreSQL 17, Multi-AZ, TLS required, RDS-managed master secret |
| `kind load docker-image` | ECR, immutable tags, scan on push |
| Kubernetes Secrets | KMS envelope encryption for EKS secrets; one customer-managed key for RDS, ECR and logs |
| no cloud identity | EKS Pod Identity for the api (read the database secret) and the VPC CNI; IRSA for the EBS CSI driver |

## Modules

- `modules/network` — VPC over three AZs, public and private subnets, one NAT gateway,
  VPC flow logs for rejected traffic, default security group left with no rules.
- `modules/eks` — cluster with a private API endpoint unless CIDRs are listed,
  `API` authentication mode and explicit admin access entries (the creator is not
  made admin), all control-plane log types, IMDSv2 with a hop limit of 1 so pods
  cannot reach the node role, and the add-ons above.
- `modules/rds` — PostgreSQL in private subnets, reachable only from the cluster
  security group, encrypted, IAM auth on, deletion protection on, Performance
  Insights and enhanced monitoring.
- `modules/ecr` — one repository per image, lifecycle rules for untagged and old
  images.

## Choices a real environment would revisit

- One NAT gateway, not one per AZ: an AZ outage takes private egress with it.
- No remote state backend is configured (see the comment in `envs/demo/versions.tf`).
- The node group is a single on-demand group; Karpenter or a spot group would be the
  next step for cost.
- Getting the database password into the pod (External Secrets Operator or the
  Secrets Store CSI driver reading the RDS-managed secret with the Pod Identity
  role) is not part of the chart yet.

## Checks

```sh
make tf-check   # terraform fmt -check, validate, tflint (AWS ruleset), trivy, checkov
```

All tools run in pinned containers (`versions.env`). `terraform init` runs with
`-backend=false` and `validate` needs no credentials. Four checkov rules are skipped
in code, each with its reason.
