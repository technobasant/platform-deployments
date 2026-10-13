#!/usr/bin/env bash
# Wait until every Argo CD Application is Synced and Healthy; print the seconds waited.
set -euo pipefail
timeout=${1:-1500}
expected=${EXPECTED_APPS:-11}
start=$(date +%s)
while :; do
  now=$(date +%s)
  out=$(kubectl -n argocd get applications.argoproj.io --no-headers \
    -o custom-columns=N:.metadata.name,S:.status.sync.status,H:.status.health.status 2>/dev/null || true)
  total=$(grep -c . <<<"$out" || true)
  ok=$(grep -cE ' Synced +Healthy$' <<<"$out" || true)
  if [ "$total" -ge "$expected" ] && [ "$ok" -eq "$total" ]; then
    echo $((now - start)); exit 0
  fi
  if [ $((now - start)) -ge "$timeout" ]; then
    echo "timed out after ${timeout}s; not ready:" >&2
    grep -vE ' Synced +Healthy$' <<<"$out" >&2 || true
    exit 1
  fi
  sleep 2
done
