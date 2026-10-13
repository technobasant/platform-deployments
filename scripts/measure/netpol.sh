#!/usr/bin/env bash
# The api's NetworkPolicy admits the web pods and the `load` namespace only. Try the
# api Service from `load` (expected to answer) and from `default` (expected to time out).
set -euo pipefail
. "$(dirname "$0")/lib.sh"
probe() {
  local ns=$1
  kubectl -n "$ns" delete pod np-probe --ignore-not-found >/dev/null
  kubectl -n "$ns" run np-probe --image="$CURL_IMAGE" --restart=Never --quiet \
    --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"runAsUser":100,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"np-probe","image":"'"$CURL_IMAGE"'","command":["sh","-c","curl -sS -m 5 -o /dev/null -w \"%{http_code}\" http://ga-api.governed-agent.svc/healthz; echo \" exit=$?\""],"resources":{"requests":{"cpu":"10m","memory":"16Mi"},"limits":{"memory":"64Mi"}},"securityContext":{"allowPrivilegeEscalation":false,"readOnlyRootFilesystem":true,"capabilities":{"drop":["ALL"]}}}]}}' >/dev/null
  kubectl -n "$ns" wait --for=jsonpath='{.status.phase}'=Succeeded pod/np-probe --timeout=90s >/dev/null 2>&1 || true
  echo "from namespace $ns: $(kubectl -n "$ns" logs np-probe 2>/dev/null | tail -1)"
  kubectl -n "$ns" delete pod np-probe --ignore-not-found --wait=false >/dev/null
}
kubectl apply -f load/namespace.yaml >/dev/null
{ echo "# GET http://ga-api.governed-agent.svc/healthz, 5 s timeout, $(date -u +%FT%TZ)"; probe load; probe default; } \
  | tee results/netpol.txt
