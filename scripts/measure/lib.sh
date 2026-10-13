# Shared helpers for the measurement scripts.
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
. ./versions.env
mkdir -p results
NS=governed-agent
now() { python3 -c 'import time; print(f"{time.time():.1f}")'; }
since() { python3 -c "import sys; print(f'{float(sys.argv[2]) - float(sys.argv[1]):.1f}')" "$1" "$2"; }
stable_hash() { kubectl -n $NS get rollout ga-api -o jsonpath='{.status.stableRS}'; }
current_hash() { kubectl -n $NS get rollout ga-api -o jsonpath='{.status.currentPodHash}'; }
stable_note() {
  kubectl -n $NS get rs "ga-api-$(stable_hash)" -o jsonpath="{.spec.template.metadata.annotations['release-note']}"
}
# Wait until the Rollout is fully promoted to a hash other than $1.
wait_promoted() {
  local old=$1 deadline=$(( $(date +%s) + ${2:-900} ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    local phase stable
    phase=$(kubectl -n $NS get rollout ga-api -o jsonpath='{.status.phase}')
    stable=$(stable_hash)
    if [ "$phase" = Healthy ] && [ "$stable" != "$old" ] && [ "$stable" = "$(current_hash)" ]; then return 0; fi
    sleep 1
  done
  return 1
}
wait_healthy() {
  local deadline=$(( $(date +%s) + ${1:-600} ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    [ "$(kubectl -n $NS get rollout ga-api -o jsonpath='{.status.phase}')" = Healthy ] && return 0
    sleep 1
  done
  return 1
}
