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
* Background analysis starts at the first pause, waits 30 s for the canary's cold
  first requests to pass, then queries Prometheus every 15 s for the canary's own
  pods (by `rollouts-pod-template-hash`) over a 30 s window:
  * 5xx rate at or under 5%, absolute;
  * p95 at or under 500 ms, **or** no more than twice the stable pods' p95 over the
    same window. The first version had the absolute threshold only, and it
    aborted a good release during a stall that slowed every pod: the canary's p95
    was 2.26 s, stable's 2.52 s. A canary should be judged against what it
    replaces, not against a number that the whole cluster can cross at once.
* One failed measurement aborts the rollout (`failureLimit: 0`), which scales the
  canary away and leaves the stable ReplicaSet serving.
* Every check above passes when there is no data, so the last step before
  promotion asks one more question: did the canary serve at least 30 requests in
  the past three minutes? If not, the rollout aborts. Without this step a bad
  release was promoted during a host stall, because the load had stopped before the
  canary became Ready and every measurement saw nothing.
* mcp and web stay Deployments. They are not on the request path the analysis
  measures, and a canary without a metric is just a slower rolling update.

## Consequences

* A bad release is stopped by evidence, not by someone watching a dashboard. The
  cost is the time to collect that evidence, during which the canary takes real
  traffic: MEASUREMENTS.md reports both how long and how many requests.
* Without a traffic router, canary weight moves in steps of one pod (20% with five
  replicas). A mesh or a Gateway API plugin would allow 1% canaries; that is on the
  roadmap.
* `failureLimit: 0` with a 30 s window is strict. A brief error burst on a good
  release will abort it; MEASUREMENTS.md reports every good-release run, aborted
  ones included.
* No traffic, no release. A change shipped when nothing is calling the api aborts
  at the evidence step and the stable version keeps serving. To ship in a quiet
  period, send synthetic traffic (that is how this repository's own platform changes
  were rolled out) or promote by hand, which is a decision someone signs.
* The comparison needs stable pods serving traffic. Background analysis ends at
  promotion, so they exist for every measurement; if they did not, the stable p95
  would be undefined and the query returns 0 (pass), leaving the error-rate check.
