#!/usr/bin/env bash
# Install Argo CD, start the in-cluster Git server, push this repo to it and hand
# over to the root Application. Everything after that is Argo CD's job.
set -euo pipefail
cd "$(dirname "$0")/.."
. ./versions.env
helm upgrade --install argocd argo-cd --repo https://argoproj.github.io/argo-helm \
  --version "$ARGOCD_CHART" -n argocd --create-namespace \
  -f bootstrap/argocd-values.yaml --wait --timeout 10m >/dev/null
echo "argo cd installed"
kubectl apply -f bootstrap/local-git.yaml >/dev/null
kubectl -n local-git rollout status deploy/git-server --timeout=180s >/dev/null
scripts/gitops-push.sh
kubectl apply -f bootstrap/root-app.yaml >/dev/null
echo "waiting for every Application to be Synced and Healthy"
secs=$(scripts/wait-apps.sh)
echo "all Applications healthy after ${secs}s"
