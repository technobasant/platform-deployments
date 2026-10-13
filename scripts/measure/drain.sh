#!/usr/bin/env bash
# Drain the worker that does not host the PostgreSQL primary while k6 sends a constant
# 20 req/s, then uncordon it and restart the workloads so they spread out again.
# (Draining the primary's node is a database switchover first; see MEASUREMENTS.md.)
set -euo pipefail
. "$(dirname "$0")/lib.sh"
runs=${1:-3} rate=${RATE:-20}
for i in $(seq "$runs"); do
  wait_healthy 600
  primary=$(kubectl -n $NS get cluster.postgresql.cnpg.io ga-pg -o jsonpath='{.status.currentPrimary}')
  pnode=$(kubectl -n $NS get pod "$primary" -o jsonpath='{.spec.nodeName}')
  target=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o name | sed 's|node/||' | grep -vx "$pnode" | head -1)
  api_on_target=$(kubectl -n $NS get pods -l app.kubernetes.io/name=api --field-selector "spec.nodeName=$target" --no-headers | wc -l | tr -d ' ')
  pods_on_target=$(kubectl get pods -A --field-selector "spec.nodeName=$target" --no-headers | wc -l | tr -d ' ')
  scripts/load.sh start "drain-$i" "$rate" 4m >/dev/null
  sleep 20
  t0=$(now)
  status=ok
  kubectl drain "$target" --ignore-daemonsets --delete-emptydir-data --timeout=300s \
    > "results/drain-run$i.log" 2>&1 || status=failed
  t1=$(now)
  k6=$(scripts/load.sh wait "drain-$i")
  kubectl uncordon "$target" >/dev/null
  printf '{"run":%d,"rate":'"$rate"',"node":"%s","pods_on_node":%s,"api_pods_on_node":%s,"drain_s":%s,"drain":"%s","k6":%s}\n' \
    "$i" "$target" "$pods_on_target" "$api_on_target" "$(since "$t0" "$t1")" "$status" "$k6" \
    | tee -a results/drain.jsonl
  # Spread the workloads back over both workers before the next run.
  kubectl -n $NS patch rollout ga-api --type merge -p "{\"spec\":{\"restartAt\":\"$(date -u +%FT%TZ)\"}}" >/dev/null
  kubectl -n $NS rollout restart deploy/ga-mcp deploy/ga-web >/dev/null
  sleep 5; wait_healthy 600
  kubectl -n $NS rollout status deploy/ga-mcp deploy/ga-web --timeout=300s >/dev/null
done
