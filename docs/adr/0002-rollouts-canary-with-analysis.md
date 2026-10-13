# 2. Argo Rollouts canary with Prometheus analysis for the api

Status: accepted · 2026-10

## Context

A Deployment's rolling update checks one thing per pod: readiness. A release that
starts, passes `/healthz` and then fails a third of real requests rolls out to
every pod. The only signal that catches that is the traffic itself.

## Decision

* The api is an Argo Rollouts `Rollout` with canary steps 20% → pause 60 s → 50% →
  pause 60 s → 100%.
* There is no traffic router. Weights are replica ratios: with five replicas, 20%
  is one canary pod out of five behind the same Service.
* Background analysis starts at the first pause and queries Prometheus every 15 s
  for the canary's own pods (by `rollouts-pod-template-hash`): 5xx rate must stay at
  or under 5% and p95 at or under 500 ms. One failed measurement aborts the
  rollout (`failureLimit: 0`), which scales the canary away and leaves the stable
  ReplicaSet serving.
* mcp and web stay Deployments. They are not on the request path the analysis
  measures, and a canary without a metric is just a slower rolling update.

## Consequences

* A bad release is stopped by evidence, not by someone watching a dashboard. The
  cost is the time to collect that evidence, during which the canary takes real
  traffic: MEASUREMENTS.md reports both how long and how many requests.
* Without a traffic router, canary weight moves in steps of one pod (20% with five
  replicas). A mesh or a Gateway API plugin would allow 1% canaries; that is on the
  roadmap.
* `failureLimit: 0` with a one-minute rate window is strict. A brief error burst on
  a good release will abort it; the good-release runs in MEASUREMENTS.md show
  whether that happened.
