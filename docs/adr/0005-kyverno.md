# 5. Kyverno in Enforce mode, scoped by namespace label

Status: accepted · 2026-10

## Context

Four rules should hold for every workload of the application: no `:latest` or
untagged images, CPU and memory requests plus a memory limit, `runAsNonRoot`, and no
privileged containers or privilege escalation. The candidates were Kyverno and OPA
Gatekeeper.

## Decision

* Kyverno `ClusterPolicy` objects, `validationFailureAction: Enforce`, in
  `gitops/platform/policies`.
* They match Pods in namespaces labelled `platform.policy/enforce: "true"`. Kyverno's
  auto-generated rules extend them to Deployments, Jobs, ReplicaSets and the like,
  so a bad Deployment is refused at `kubectl apply`, not when its pods fail later.
* Each rule has a passing and a failing fixture under `policies/tests`, run by
  `kyverno test` in CI.
* The application namespace also has Pod Security Admission at `restricted`. The
  two overlap on purpose; PSA is built in and cannot be switched off by deleting a
  webhook.

## Why not Gatekeeper

Gatekeeper's Rego is more expressive, and these four rules do not need it. Kyverno
policies are YAML, which the people who write the manifests already read, and
`kyverno test` gives each rule a unit test without a cluster.

## Consequences

* Third-party charts in other namespaces are not judged by these rules. That is a
  choice of scope, not an oversight: the platform components are pinned and
  reviewed as charts, and a cluster-wide rule would need exceptions for half of them.
* Kyverno is in the admission path for the labelled namespace. If its admission
  controller is down, pod creation there fails closed.
