#!/usr/bin/env bash
# Submit one violating Pod per Kyverno policy, plus a compliant Pod and a Deployment
# using :latest, to a namespace labelled for enforcement. The namespace has no Pod
# Security Admission label, so every rejection here is Kyverno's.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
out=results/policies.txt
kubectl create namespace policy-check --dry-run=client -o yaml \
  | kubectl label --local -f - platform.policy/enforce=true -o yaml | kubectl apply -f - >/dev/null
work=$(mktemp -d)
python3 - "$work" <<'PY'
import re, sys
docs = open("policies/tests/resources.yaml").read().split("\n---\n")
for d in docs:
    m = re.search(r"name: ([\w-]+), namespace: governed-agent", d)
    if m:
        open(f"{sys.argv[1]}/{m.group(1)}.yaml", "w").write(d.replace("namespace: governed-agent", "namespace: policy-check"))
PY
cat > "$work/deploy-latest.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: deploy-latest, namespace: policy-check}
spec:
  selector: {matchLabels: {app: x}}
  template:
    metadata: {labels: {app: x}}
    spec:
      securityContext: {runAsNonRoot: true}
      containers:
        - name: app
          image: governed-agent-python:latest
          resources: {requests: {cpu: 10m, memory: 16Mi}, limits: {memory: 32Mi}}
YAML
{
  echo "# kubectl create, namespace policy-check (platform.policy/enforce=true), $(date -u +%FT%TZ)"
  for f in good bad-latest bad-untagged bad-no-resources bad-root bad-privileged deploy-latest; do
    printf '\n## %s\n' "$f"
    if res=$(kubectl create --dry-run=server -f "$work/$f.yaml" 2>&1); then
      echo "ADMITTED: $res"
    else
      echo "REJECTED:"; sed 's/^/  /' <<<"$res"
    fi
  done
} | tee "$out"
kubectl delete namespace policy-check --wait=false >/dev/null
