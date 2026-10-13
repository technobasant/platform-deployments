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
for _ in $(seq 600); do nc -z 127.0.0.1 "$port" 2>/dev/null && break; sleep 0.1; done
url="http://127.0.0.1:$port/"
if [ "${KEEP_RELEASE:-0}" = 1 ]; then
  # Ship platform changes without touching what is deployed: take this checkout's
  # tree, but keep the release file as it is on the in-cluster main.
  work=$(mktemp -d)
  git clone --quiet "$url" "$work"
  git -C "$work" fetch --quiet "$(git -C "$repo" rev-parse --show-toplevel)" "$ref"
  git -C "$work" read-tree -u --reset FETCH_HEAD
  git -C "$work" checkout --quiet origin/main -- gitops/releases/governed-agent.yaml
  git -C "$work" -c user.name="$(git config user.name)" -c user.email="$(git config user.email)" \
    commit --quiet --allow-empty -m "platform at $(git -C "$repo" rev-parse --short "$ref"), release unchanged"
  git -C "$work" push --quiet origin HEAD:main
  echo "pushed $(git -C "$repo" rev-parse --short "$ref") (release file kept) to the in-cluster Git server"
else
  git -C "$repo" push --quiet --force "$url" "$ref:refs/heads/main"
  echo "pushed $(git -C "$repo" rev-parse --short "$ref") to the in-cluster Git server"
fi
for app in $(kubectl -n argocd get applications.argoproj.io -o name 2>/dev/null); do
  kubectl -n argocd annotate "$app" argocd.argoproj.io/refresh=hard --overwrite >/dev/null
done
