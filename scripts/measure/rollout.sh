#!/usr/bin/env bash
# A good release (same images, new release note) through the canary steps while k6
# sends a constant RATE req/s (default 20). Records the k6 summary, how long promotion
# took, and whether the analysis let it through. An aborted good release is a result
# too: it is recorded, then the stable release is restored before the next run.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
runs=${1:-3} rate=${RATE:-20}
for i in $(seq "$runs"); do
  wait_healthy 600
  old=$(stable_hash) good=$(stable_note)
  note="good-r$i-$(date +%H%M%S)"
  scripts/load.sh start "rollout-$i" "$rate" 5m >/dev/null
  sleep 20
  t0=$(now)
  scripts/release.sh "$note" >/dev/null
  until [ "$(current_hash)" != "$old" ]; do sleep 0.5; done
  t1=$(now)
  outcome=timeout message=""
  deadline=$(( $(date +%s) + 900 ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    if [ "$(kubectl -n $NS get rollout ga-api -o jsonpath='{.status.abort}')" = true ]; then
      outcome=aborted message=$(kubectl -n $NS get rollout ga-api -o jsonpath='{.status.message}'); break
    fi
    phase=$(kubectl -n $NS get rollout ga-api -o jsonpath='{.status.phase}')
    if [ "$phase" = Healthy ] && [ "$(stable_hash)" != "$old" ] && [ "$(stable_hash)" = "$(current_hash)" ]; then
      outcome=promoted; break
    fi
    sleep 1
  done
  t2=$(now)
  k6=$(scripts/load.sh wait "rollout-$i")
  printf '{"run":%d,"rate":%s,"note":"%s","outcome":"%s","message":%s,"sync_s":%s,"promotion_s":%s,"k6":%s}\n' \
    "$i" "$rate" "$note" "$outcome" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$message")" \
    "$(since "$t0" "$t1")" "$(since "$t1" "$t2")" "$k6" | tee -a results/rollout.jsonl
  if [ "$outcome" != promoted ]; then scripts/release.sh "$good" >/dev/null; sleep 5; fi
done
