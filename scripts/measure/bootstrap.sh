#!/usr/bin/env bash
# Zero to every Argo CD Application Synced and Healthy, RUNS times. Each run deletes
# the cluster first, so every upstream image is pulled again; the three locally
# built images are copied in by `kind load` and timed separately.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
runs=${1:-3} first=${2:-1}
for i in $(seq "$first" $((first + runs - 1))); do
  kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
  t0=$(now)
  kind create cluster --config kind/cluster.yaml --image "$KIND_NODE_IMAGE" >/dev/null 2>&1
  t1=$(now)
  scripts/load-images.sh >/dev/null
  t2=$(now)
  log=$(scripts/bootstrap.sh 2>&1) || { echo "$log" >&2; exit 1; }
  t3=$(now)
  apps=$(sed -n 's/^all Applications healthy after \([0-9]*\)s$/\1/p' <<<"$log")
  printf '{"run":%d,"cluster_s":%s,"load_images_s":%s,"bootstrap_s":%s,"apps_healthy_after_root_s":%s,"total_s":%s}\n' \
    "$i" "$(since "$t0" "$t1")" "$(since "$t1" "$t2")" "$(since "$t2" "$t3")" "$apps" "$(since "$t0" "$t3")" \
    | tee -a results/bootstrap.jsonl
done
