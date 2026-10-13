#!/usr/bin/env bash
# Push a commit (default: HEAD of this checkout) to main on the in-cluster Git server.
# Only committed work is pushed; Argo CD never sees the working tree.
set -euo pipefail
cd "$(dirname "$0")/.."
repo=${GITOPS_REPO:-.}
ref=${1:-HEAD}
port=${GIT_PF_PORT:-18080}
if [ "$repo" = . ] && [ -n "$(git status --porcelain)" ]; then
  echo "note: uncommitted changes are not pushed" >&2
fi
kubectl -n local-git port-forward svc/git-server "$port:8080" >/dev/null 2>&1 &
pf=$!
trap 'kill $pf 2>/dev/null || true' EXIT
for _ in $(seq 100); do nc -z 127.0.0.1 "$port" 2>/dev/null && break; sleep 0.1; done
git -C "$repo" push --quiet --force "http://127.0.0.1:$port/" "$ref:refs/heads/main"
echo "pushed $(git -C "$repo" rev-parse --short "$ref") to the in-cluster Git server"
