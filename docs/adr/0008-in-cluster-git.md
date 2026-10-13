# 8. An in-cluster Git server as Argo CD's source

Status: accepted · 2026-10

## Context

Argo CD reads Git. Pointing it at GitHub would make the platform depend on the
repository being public and reachable, and every measurement release (a commit that
changes the release note or switches the fault on) would land in the published
history.

## Decision

* `local-git/` is a minimal Git smart-HTTP server (dulwich) in the `local-git`
  namespace, on a small PersistentVolume.
* `make bootstrap` pushes the committed HEAD of this checkout to it; Argo CD reads
  `http://git-server.local-git.svc.cluster.local:8080/`.
* `scripts/release.sh` clones from it, commits the release file and pushes back, so
  releases are real Git commits that Argo CD syncs, but they never leave the cluster.

## Consequences

* Only committed work reaches the cluster; `make bootstrap` says so when the working
  tree is dirty.
* Pointing at a hosted repository is a one-line change to `repoURL` in
  `gitops/root/values.yaml` and `bootstrap/root-app.yaml`.
* The server has no authentication. It is reachable only inside the cluster, which
  is acceptable for a lab and nothing else.
