#!/usr/bin/env bash
# Run k6 inside the cluster, from the `load` namespace, so the load goes through the
# Service and the NetworkPolicy exactly as a client's would.
#
#   scripts/load.sh start NAME [RATE] [DURATION] [BAD_PREFIX]   (NO_REUSE=1: no keep-alive)
#   scripts/load.sh wait NAME        # blocks, prints the K6_SUMMARY JSON line
set -euo pipefail
cd "$(dirname "$0")/.."
. ./versions.env
cmd=$1 name=$2
case "$cmd" in
start)
  rate=${3:-40} duration=${4:-4m} bad=${5:-bad-}
  kubectl apply -f load/namespace.yaml >/dev/null
  kubectl -n load create configmap k6-script --from-file=k6.js=load/k6.js \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl -n load delete job "k6-$name" --ignore-not-found >/dev/null
  kubectl apply -f - >/dev/null <<YAML
apiVersion: batch/v1
kind: Job
metadata: {name: k6-$name, namespace: load}
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 3600
  template:
    metadata: {labels: {app: k6}}
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      # The load generator runs on the control-plane node: never drained by the tests,
      # and never sharing a worker with the pods it measures.
      nodeSelector: {node-role.kubernetes.io/control-plane: ""}
      tolerations:
        - {key: node-role.kubernetes.io/control-plane, operator: Exists, effect: NoSchedule}
      securityContext: {runAsNonRoot: true, runAsUser: 12345, seccompProfile: {type: RuntimeDefault}}
      containers:
        - name: k6
          image: $K6_IMAGE
          args: [run, --quiet, --no-color, /scripts/k6.js]
          env:
            - {name: RATE, value: "$rate"}
            - {name: DURATION, value: "$duration"}
            - {name: BAD_PREFIX, value: "$bad"}
            - {name: NO_REUSE, value: "${NO_REUSE:-0}"}
          resources:
            requests: {cpu: 250m, memory: 128Mi}
            limits: {cpu: "1", memory: 512Mi}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities: {drop: [ALL]}
          volumeMounts:
            - {name: script, mountPath: /scripts}
            - {name: tmp, mountPath: /tmp}
      volumes:
        - name: script
          configMap: {name: k6-script}
        - name: tmp
          emptyDir: {}
YAML
  kubectl -n load wait --for=jsonpath='{.status.ready}'=1 "job/k6-$name" --timeout=180s >/dev/null
  echo "k6-$name running: $rate req/s for $duration"
  ;;
wait)
  kubectl -n load wait --for=condition=complete "job/k6-$name" --timeout=1800s >/dev/null || true
  kubectl -n load logs "job/k6-$name" | grep '^K6_SUMMARY ' | sed 's/^K6_SUMMARY //'
  ;;
esac
