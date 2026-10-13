#!/usr/bin/env bash
# A good release (same images, new release note) through the canary steps while k6
# sends a constant 40 req/s. Records the k6 summary and how long promotion took.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
runs=${1:-3} rate=${RATE:-40}
for i in $(seq "$runs"); do
  wait_healthy 600
  old=$(stable_hash)
  note="good-r$i-$(date +%H%M%S)"
  scripts/load.sh start "rollout-$i" "$rate" 5m >/dev/null
  sleep 20
  t0=$(now)
  scripts/release.sh "$note" >/dev/null
  until [ "$(current_hash)" != "$old" ]; do sleep 0.5; done
  t1=$(now)
  wait_promoted "$old" 900
  t2=$(now)
  k6=$(scripts/load.sh wait "rollout-$i")
  printf '{"run":%d,"note":"%s","sync_s":%s,"promotion_s":%s,"k6":%s}\n' \
    "$i" "$note" "$(since "$t0" "$t1")" "$(since "$t1" "$t2")" "$k6" | tee -a results/rollout.jsonl
done
