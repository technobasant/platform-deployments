#!/usr/bin/env bash
# Ask the deployed agent one question through the api Service and print the answer.
set -euo pipefail
cd "$(dirname "$0")/.."
. ./versions.env
question=${1:-How many orders were delivered?}
kubectl apply -f load/namespace.yaml >/dev/null
kubectl -n load delete pod demo --ignore-not-found >/dev/null
kubectl -n load run demo --image="$CURL_IMAGE" --restart=Never --quiet \
  --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"runAsUser":100,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"demo","image":"'"$CURL_IMAGE"'","command":["sh","-c","curl -fsS http://ga-api.governed-agent.svc/healthz && echo && curl -fsS -X POST \"http://ga-api.governed-agent.svc/runs?wait=true\" -H content-type:application/json -d \"$Q\""],"env":[{"name":"Q","value":"{\"question\": \"'"$question"'\"}"}],"resources":{"requests":{"cpu":"10m","memory":"16Mi"},"limits":{"memory":"64Mi"}},"securityContext":{"allowPrivilegeEscalation":false,"readOnlyRootFilesystem":true,"capabilities":{"drop":["ALL"]}}}]}}' >/dev/null
kubectl -n load wait --for=jsonpath='{.status.phase}'=Succeeded pod/demo --timeout=120s >/dev/null \
  || { kubectl -n load logs demo; exit 1; }
kubectl -n load logs demo | python3 -c '
import json, sys
health, run = sys.stdin.read().split("\n", 1)
print("healthz:", health)
r = json.loads(run)
f = r.get("finding") or {}
print("question:", r.get("question"))
print("run:     ", r.get("status"), "/", r.get("disposition"))
print("finding: ", f.get("status"), "/", f.get("state"))
print("answer:  ", f.get("answer"))
'
kubectl -n load delete pod demo --ignore-not-found >/dev/null
