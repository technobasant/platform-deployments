#!/usr/bin/env bash
# The CI end-to-end test, runnable locally against an existing kind cluster with the
# images loaded: CloudNativePG and Argo Rollouts, the PostgreSQL cluster, the chart,
# then /healthz and one demo question through the Service. No Argo CD, Kyverno or
# monitoring stack, to stay well under 15 minutes on a CI runner.
set -euo pipefail
cd "$(dirname "$0")/.."
. ./versions.env
start=$(date +%s)
step() { echo "== $1 ($(( $(date +%s) - start ))s)"; }

step "operators"
helm upgrade --install cnpg cloudnative-pg --repo https://cloudnative-pg.github.io/charts \
  --version "$CNPG_CHART" -n cnpg-system --create-namespace --wait --timeout 5m >/dev/null
helm upgrade --install argo-rollouts argo-rollouts --repo https://argoproj.github.io/argo-helm \
  --version "$ROLLOUTS_CHART" -n argo-rollouts --create-namespace --wait --timeout 5m \
  --set controller.replicas=1 >/dev/null

step "postgres"
kubectl apply -f gitops/platform/postgres/ >/dev/null
until kubectl -n governed-agent get cluster.postgresql.cnpg.io/ga-pg >/dev/null 2>&1; do sleep 2; done
kubectl -n governed-agent wait cluster.postgresql.cnpg.io/ga-pg --for=condition=Ready --timeout=8m >/dev/null

step "governed-agent chart"
helm upgrade --install ga charts/governed-agent -n governed-agent \
  -f gitops/releases/governed-agent.yaml \
  --set monitoring.podMonitor=false --set otel.enabled=false \
  --wait --timeout 10m >/dev/null
kubectl -n governed-agent wait rollout/ga-api --for=jsonpath='{.status.phase}'=Healthy --timeout=5m >/dev/null

step "smoke test"
out=$(scripts/demo.sh)
echo "$out"
grep -q 'orders have the status delivered' <<<"$out"
step "passed"
