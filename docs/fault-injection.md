# How the bad release is made

The canary test needs a release that fails. governed-agent is deployed from its
v0.1.0 images unchanged, so the fault lives in the platform, not in the application.

## The sidecar

Every api pod runs Envoy in front of the application. The Service sends traffic to
Envoy on 8080; Envoy forwards it to the application on 127.0.0.1:8000. Envoy does
three jobs:

1. **Metrics.** The application has no `/metrics` endpoint. Envoy's
   `/stats/prometheus` on 9901 exposes request counts by status class and a latency
   histogram per pod, and the PodMonitor attaches the pod's
   `rollouts-pod-template-hash` label. That is what lets the AnalysisTemplate query
   the canary's error rate and p95 by itself.
2. **Fault injection.** The config in `charts/governed-agent/templates/envoy-configmap.yaml`
   always contains Envoy's HTTP fault filter, with abort and delay at 0%.
3. **Attribution.** Every reply, including Envoy's own fault replies, carries an
   `x-release` header with the pod's `release-note` annotation, so k6 can count how
   many requests each release served.

## Switching the fault on for one revision

The ConfigMap is shared by every revision, so changing it would break the stable
pods too. Instead, when `api.fault.abortPercent` or `api.fault.delayPercent` is
non-zero, the chart adds a runtime layer to that revision's Envoy command line:

```
--config-yaml "{layered_runtime: {layers: [{name: fault, static_layer: {
  fault.http.abort.abort_percent: 30, fault.http.abort.http_status: 500,
  fault.http.delay.fixed_delay_percent: 0, fault.http.delay.fixed_duration_ms: 0}}]}}"
```

Envoy's fault filter reads those runtime keys and overrides its 0% defaults. The
argument is part of the pod template, so it is part of the revision: stable pods
never see it, and a stable pod that restarts mid-canary comes back clean.

## Making a release bad

A release is a commit to `gitops/releases/governed-agent.yaml`:

```yaml
api:
  fault: {abortPercent: 30, delayPercent: 0, delayMs: 0}
  revisionNote: "bad-r1-120000"
```

`scripts/release.sh NOTE 30` makes that commit on the in-cluster Git server and asks
Argo CD to refresh. `make release-bad` does the same with a generated note.

## Why the probes go around Envoy

Readiness and liveness probes hit the application on port 8000 directly. If they
went through Envoy, a 30% abort rate would fail probes too, the canary would never
become Ready, and the test would measure Kubernetes refusing to start a pod rather
than the analysis catching a bad release. Real faults that a probe can see are
caught earlier by readiness; this test covers the ones it cannot.
