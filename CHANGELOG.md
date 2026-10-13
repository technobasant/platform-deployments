# Changelog

## 0.1.0 — 2026-10

First release.

- A three-node kind cluster (`make cluster`) and an Argo CD app-of-apps
  (`make bootstrap`) that installs, in sync-wave order: metrics-server,
  CloudNativePG, Argo Rollouts, Kyverno, a trimmed kube-prometheus-stack, Jaeger,
  the OpenTelemetry Collector, four Kyverno policies, a two-instance PostgreSQL
  cluster and governed-agent v0.1.0.
- `charts/governed-agent`: api as an Argo Rollouts canary (20% → 50% → 100%) gated
  by Prometheus analysis of the canary's 5xx rate and p95; mcp and web Deployments;
  a pre-sync migration Job; PodDisruptionBudgets; an HPA for the api;
  default-deny NetworkPolicies; non-root, read-only root filesystem, no
  capabilities; requests, limits and probes on every container.
- An Envoy sidecar per api pod for request metrics, per-revision fault injection and
  an `x-release` response header.
- An in-cluster Git server as Argo CD's source; `scripts/release.sh` ships a release
  as a commit to it.
- In-cluster k6 load and measurement scripts for bootstrap, a good canary, a bad
  canary, Kyverno admission, a node drain and resource footprint;
  results in MEASUREMENTS.md.
- `terraform/aws`: VPC, EKS (access entries, Pod Identity, IRSA), RDS PostgreSQL,
  ECR and KMS. Validated and scanned; never applied.
- CI: helm lint and kubeconform, kyverno test, Terraform checks, and an end-to-end
  job on kind.
