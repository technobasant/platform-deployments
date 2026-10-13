#!/usr/bin/env bash
# helm lint, then every rendered manifest through kubeconform -strict, CRDs included
# (schemas for Rollout, PodMonitor, CNPG Cluster, ClusterPolicy and Application come
# from the datreeio CRDs catalog).
set -euo pipefail
cd "$(dirname "$0")/.."
. ./versions.env
release=gitops/releases/governed-agent.yaml
helm lint --strict charts/governed-agent -f "$release"
helm lint --strict gitops/root
work=$(mktemp -d)
helm template ga charts/governed-agent -n governed-agent -f "$release" > "$work/chart.yaml"
helm template ga charts/governed-agent -n governed-agent -f "$release" \
  --set api.fault.abortPercent=30 --set api.revisionNote=bad > "$work/chart-faulty.yaml"
helm template platform-root gitops/root -n argocd > "$work/root.yaml"
for f in gitops/platform/*/*.yaml bootstrap/local-git.yaml bootstrap/root-app.yaml load/namespace.yaml; do
  printf -- '---\n'; cat "$f"
done > "$work/plain.yaml"
docker run --rm -v "$work":/m "$KUBECONFORM_IMAGE" -strict -summary \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  /m/chart.yaml /m/chart-faulty.yaml /m/root.yaml /m/plain.yaml
