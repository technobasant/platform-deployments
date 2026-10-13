# 1. Argo CD, one root Application, sync waves

Status: accepted · 2026-10

## Context

The platform is ten components with an order: CRDs and operators before the objects
that use them, the database before the application, admission policies before the
workloads they judge. Something has to own that order and keep the cluster equal to
Git afterwards. The candidates were Argo CD and Flux.

## Decision

* Argo CD, installed once by Helm (`make bootstrap`), then one hand-applied
  Application, `platform-root`, that renders every other Application from
  `gitops/root`.
* Order is sync waves on the child Applications: operators and the monitoring stack
  at -3, tracing and policies at -2, the database at -1, the application at 0.
* Waves only wait for something that reports health. Argo CD stopped assessing
  Application health in 1.8, and a CloudNativePG Cluster counts as healthy before it
  has a primary, so both get Lua health checks in `bootstrap/argocd-values.yaml`.
  Without them the first run started the application against a database that did
  not exist yet.
* Every child syncs automatically with prune and self-heal.

## Why not Flux

Flux would do the job: `dependsOn` between Kustomizations is a cleaner ordering
model than waves. Argo CD won on two things this repository needs to show: health
that rolls up through the app-of-apps, so one Application says whether the platform
is up, and built-in health for a Rollout, so a paused or aborted canary is visible
in the same place as everything else.

## Consequences

* "Is the platform up?" is one query: every Application Synced and Healthy. The
  bootstrap measurement uses exactly that.
* Two pieces of Lua are part of the platform and need testing on Argo CD upgrades.
* Argo CD runs with no Dex, no notifications and one replica of everything. That is
  a lab setting, listed under Limits in the README.
