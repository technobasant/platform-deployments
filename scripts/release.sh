#!/usr/bin/env bash
# Ship a release the GitOps way: commit gitops/releases/governed-agent.yaml on the
# in-cluster Git server and ask Argo CD to refresh. This checkout is left untouched,
# so measurement releases never land in the published history.
#
#   scripts/release.sh NOTE [ABORT_PERCENT] [DELAY_PERCENT] [DELAY_MS]
#
# NOTE becomes the pods' release-note annotation and the x-release response header;
# a new NOTE is a new pod template, so it starts a canary even with the same images.
set -euo pipefail
cd "$(dirname "$0")/.."
. ./versions.env
note=$1 abort=${2:-0} delay_pct=${3:-0} delay_ms=${4:-0}
port=${GIT_PF_PORT:-18080}
work=$(mktemp -d)

kubectl -n local-git port-forward svc/git-server "$port:8080" >/dev/null 2>&1 &
pf=$!
trap 'kill $pf 2>/dev/null || true' EXIT
for _ in $(seq 600); do nc -z 127.0.0.1 "$port" 2>/dev/null && break; sleep 0.1; done

git clone --quiet "http://127.0.0.1:$port/" "$work"
cat > "$work/gitops/releases/governed-agent.yaml" <<YAML
# The release being deployed. A rollout is a commit to this file.
image:
  python: {tag: $GA_REF}
  web: {tag: $GA_REF}
api:
  fault: {abortPercent: $abort, delayPercent: $delay_pct, delayMs: $delay_ms}
  revisionNote: "$note"
YAML
git -C "$work" -c user.name="$(git config user.name)" -c user.email="$(git config user.email)" \
  commit --quiet -am "release $note (abort ${abort}%, delay ${delay_pct}% x ${delay_ms}ms)"
git -C "$work" push --quiet origin HEAD:main
kubectl -n argocd annotate applications.argoproj.io governed-agent \
  argocd.argoproj.io/refresh=hard --overwrite >/dev/null
echo "released $note at $(date -u +%H:%M:%S)"
