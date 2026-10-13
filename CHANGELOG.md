# Changelog

## 0.1.0 — 2026-10

First release.

- A three-node kind cluster (`make cluster`) and an Argo CD app-of-apps
  (`make bootstrap`) that installs, in sync-wave order: metrics-server,
  CloudNativePG, Argo Rollouts, Kyverno, a trimmed kube-prometheus-stack, Jaeger,
  the OpenTelemetry Collector, four Kyverno policies, a two-instance PostgreSQL
  cluster and governed-agent v0.1.0.
- `charts/governed-agent`: the api as an Argo Rollouts canary (20% → 50% → 100%)
  gated by Prometheus analysis (canary 5xx rate; canary p95 against stable's) and a
  final check that the canary served enough requests to judge; mcp and web
  Deployments; a pre-sync migration Job; PodDisruptionBudgets; an HPA for the api;
  default-deny NetworkPolicies; non-root, read-only root filesystem, no
  capabilities; requests, limits, startup, readiness and liveness probes.
- An Envoy sidecar per api pod: request metrics, per-revision fault injection, an
  `x-release` response header, a 5xx access log, an upstream idle timeout below the
  app's keep-alive timeout, a retry for requests the app never received, and a
  connection drain on shutdown.
- An in-cluster Git server as Argo CD's source; `scripts/release.sh` ships a release
  as a commit to it.
- In-cluster k6 load and measurement scripts for bootstrap, good and bad canaries
  (with and without keep-alive), Kyverno admission, NetworkPolicy, a node drain and
  resource footprint; results and the fixes they led to in MEASUREMENTS.md.
- `terraform/aws`: VPC, EKS (access entries, Pod Identity, IRSA), RDS PostgreSQL,
  ECR and KMS. Validated and scanned (tflint, trivy, checkov); never applied.
- CI: helm lint and kubeconform, kyverno test, Terraform checks, and an end-to-end
  job on kind (`make e2e` runs the same script locally).
