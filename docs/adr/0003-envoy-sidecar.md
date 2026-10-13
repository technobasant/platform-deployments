# 3. An Envoy sidecar for request metrics and fault injection

Status: accepted · 2026-10

## Context

The canary analysis needs per-pod request metrics, and the canary test needs a
release that fails. governed-agent v0.1.0 has neither a `/metrics` endpoint nor a
fault switch, and the brief is to deploy it unchanged.

## Decision

* Each api pod runs Envoy on 8080 in front of the application on 8000. Prometheus
  scrapes Envoy's stats; the AnalysisTemplate queries them per pod template hash.
* Envoy's HTTP fault filter is always configured, at 0%. A release turns it on for
  its own pods only, through a runtime layer passed on Envoy's command line
  ([fault-injection.md](../fault-injection.md)).
* Envoy adds an `x-release` header to every reply, so the load generator can count
  requests per release.
* Probes go to the application directly, around Envoy.
* Envoy logs every 5xx with its response flags, closes idle connections to the app
  after 4 s (before uvicorn's 5 s keep-alive timeout can close them under it),
  retries once a request the app never received, and on shutdown drains: each open
  client connection gets `Connection: close` on its next response, and the app
  outlives the drain by 5 s.

## Consequences

* Metrics and faults come from the same component, so the analysis measures exactly
  what clients saw, including injected failures.
* Every api request pays one extra local hop. Envoy's requests are 50m CPU and
  48 MiB per pod (see the footprint in MEASUREMENTS.md).
* Application-level faults (a slow query, a wrong answer) are out of scope; this
  injects transport-level failures only.
