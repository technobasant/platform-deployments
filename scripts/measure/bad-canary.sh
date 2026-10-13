#!/usr/bin/env bash
# A bad release: the same images, but the Envoy sidecar of the new revision aborts
# ABORT% of requests with a 500 (see docs/fault-injection.md). k6 sends a constant
# 20 req/s and counts replies per release from the x-release header. Afterwards the
# previous stable release is restored by another commit, which Argo Rollouts treats
# as a rollback to the stable ReplicaSet (no new pods).
set -euo pipefail
. "$(dirname "$0")/lib.sh"
runs=${1:-3} rate=${RATE:-20} abort=${ABORT:-30}
for i in $(seq "$runs"); do
  wait_healthy 600
  good=$(stable_note)
  note="bad-r$i-$(date +%H%M%S)"
  scripts/load.sh start "canary-$i" "$rate" 3m bad- >/dev/null
  sleep 20
  t0=$(now)
  scripts/release.sh "$note" "$abort" >/dev/null
  timeline=$(python3 scripts/measure/canary_timeline.py "$note" "$t0")
  k6=$(scripts/load.sh wait "canary-$i")
  scripts/release.sh "$good" >/dev/null
  wait_healthy 600
  printf '{"run":%d,"note":"%s","abort_percent":%s,"rate":%s,"timeline":%s,"k6":%s}\n' \
    "$i" "$note" "$abort" "$rate" "$timeline" "$k6" | tee -a results/bad-canary.jsonl
done
