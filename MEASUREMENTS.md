# Measurements

Every figure here comes from a script in `scripts/measure/`, run against the platform
as committed, with raw output in `results/`. Where a run went wrong, it is reported,
along with what changed because of it. Timings are medians of three runs unless a
table says otherwise.

## Environment

| | |
|---|---|
| Cluster | kind v0.33.0: one control plane and two workers, each a container (`kindest/node:v1.36.4`, Kubernetes v1.36.4, containerd 2.3.4) |
| Host | Apple M5, 10 cores, 24 GiB; Docker Desktop 29.8.2 VM with 8 vCPU, 11.7 GiB memory and 4 GiB swap (Linux 7.0.14, arm64) |
| Shared host | All three nodes run on that one VM, so node-to-node latency is local and a stall on the host stalls every node. The VM also ran unrelated containers, using up to about one CPU and 1.4 GiB of memory. |
| Platform | Argo CD v3.5.5 (chart 10.10.3), Argo Rollouts v1.10.1, CloudNativePG 1.30.1 with PostgreSQL 17.6, Kyverno v1.19.1, Prometheus v3.15.0 (kube-prometheus-stack 92.3.0), OpenTelemetry Collector contrib 0.161.0, Jaeger 2.22.0, Envoy v1.36.2 |
| Application | governed-agent v0.1.0 built from its tag; `GA_MODEL=demo`. api ×5 (Rollout, HPA 5–8), mcp ×2, web ×2, PostgreSQL ×2 |
| Load | k6 2.3.0 in the cluster (namespace `load`, on the control-plane node), constant arrival rate, `GET /healthz` and `GET /review-queue` at random, 10 s timeout. `/healthz` runs `SELECT 1` against PostgreSQL. |

The load runs at **20 requests per second**. At that rate, with no rollout, there were
no failures and p95 was 25 ms; at 40 req/s p99 was already 580 ms (table below). The
point of these tests is what a rollout or a drain adds, so the load stays where the
platform is comfortable.

| when | req/s | requests | failed | p50 ms | p95 ms | p99 ms | max ms |
|---|---:|---:|---:|---:|---:|---:|---:|
| fresh cluster, before the rollout runs (k6 on a worker) | 20 | 1201 | 0 | 3.5 | 24.8 | 102.4 | 557 |
| fresh cluster, before the rollout runs (k6 on a worker) | 40 | 2400 | 0 | 3.2 | 105.3 | 580.4 | 967 |
| after all runs, 90 s after the third drain | 20 | 1201 | 0 | 4.9 | 210.0 | 1,729.3 | 2,683 |
| after all runs, 90 s after the third drain | 40 | 2401 | 0 | 4.1 | 255.1 | 625.3 | 910 |
| after all runs, settled 10 min | 20 | 1201 | 0 | 5.3 | 541.9 | 1,458.9 | 2,226 |
| after all runs, settled 10 min | 40 | 2401 | 0 | 4.3 | 59.7 | 295.7 | 604 |

The spread is the host, not the platform: the same 20 req/s gave a p95 of 25 ms on a
fresh cluster and 542 ms in a later minute on an idle cluster. Every number below
should be read with that in mind, and the runs that a host stall visibly hit say so.

## 1. Bootstrap: zero to every Application healthy

**Method.** `scripts/measure/bootstrap.sh` deletes the cluster, creates it, loads the
three locally built images into the nodes (`kind load`), runs `make bootstrap`
(Argo CD by Helm, the in-cluster Git server, the root Application) and stops the clock
when all eleven Argo CD Applications are Synced and Healthy. The governed-agent images
are already built; every upstream image is pulled again, because the nodes are new.

| seconds | run 1 | run 2 | run 3 | median |
|---|---:|---:|---:|---:|
| kind create cluster | 60 | 34 | 30 | 34 |
| kind load (3 images) | 125 | 53 | 76 | 76 |
| make bootstrap | 1,473 | 656 | 540 | 656 |
|   of which: root app → all healthy | 1,299 | 513 | 400 | 513 |
| zero → all Applications healthy | 1,657 | 744 | 646 | 744 |

**Result.** A median of **12 min 24 s** from nothing to eleven healthy Applications,
with the first run at 27 min 37 s. Most of the time is pulling and unpacking images on
three new nodes (every upstream image, about twenty of them), and that depends on the
network and on how busy the host is: in the first run the PostgreSQL image alone took
6 min 20 s to pull, and the node containers were above 700% CPU in `docker stats`
while layers were unpacked. Run 1 was on the platform at `461c2c5`, runs 2 and 3 at
`5dc2ddc`; the commits between change the application chart, not what bootstrap
installs.

In run 3, of the 6 min 40 s after the root Application was applied, the operators
(wave −3) took 2 min 28 s, tracing and policies (wave −2) 1 min 5 s, the database
(wave −1) 2 min 54 s and the application (wave 0) 1 min 9 s. The wave that matters
held: the application's Application was created one second after the database's
reported Healthy, which by the Lua check means a primary and every instance ready.
One did not: the database's wave began 6 s into wave −2, before Jaeger and the
Collector were Healthy. Nothing depends on that order, but the waves are not as
strict as they look, and why is unexplained.

## 2. A good release under load

**Method.** `scripts/measure/rollout.sh`. k6 starts at 20 req/s for 5 minutes; 20 s
later a release commit changes only the release note (same images, new pod template).
Argo Rollouts runs the canary: 20%, 60 s, 50%, 60 s, an evidence check, 100%, with
background analysis from the first pause. Clock: from the push to the new ReplicaSet
appearing (Argo CD sync), and from there to full promotion. The PDB keeps at least 3 of
the 5 api pods available, readiness gates traffic, and each pod drains on shutdown.

| run | outcome | push → new ReplicaSet (s) | new ReplicaSet → promoted (s) | requests | failed | p50 ms | p95 ms | max ms | dropped |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | promoted | 13.8 | 135.5 | 6001 | 0 | 3.6 | 24.0 | 517 | 0 |
| 2 | promoted | 14.6 | 133.0 | 6001 | 0 | 3.3 | 21.3 | 554 | 0 |
| 3 | promoted | 16.0 | 137.1 | 6001 | 0 | 3.3 | 23.6 | 1,084 | 0 |
| median | 3/3 promoted | 14.6 | 135.5 | 6,001 | 0 | 3.3 | 23.6 | 554 | 0 |

**Result.** Three good releases promoted, with no failed request among 18,003 and a
p95 of 21–24 ms. Promotion takes about 135 s, of which 120 s are the two pauses; Argo
CD takes about 15 s to turn the release commit into a new ReplicaSet.

It took four rounds to get there. Each row below is three runs of this same test on
the platform as it stood (the first two rows had k6 on a worker node rather than the
control plane):

| platform at that point | failed requests per run | outcome per run | median p95 ms |
|---|---:|---:|---:|
| absolute p95 threshold only | 0, 8, 2 | promoted, promoted, aborted | 59.8 |
| p95 judged against stable | 2, 3, 1 | promoted, promoted, promoted | 62.8 |
| + Envoy drains client connections on shutdown | 5, 5, 2 | promoted, promoted, promoted | 186.4 |
| + upstream idle timeout 4 s, retry if the app never saw the request | 0, 0, 0 | promoted, promoted, promoted | 23.6 |

* **Absolute p95 only.** The third run was aborted although nothing was wrong with
  the release: a stall slowed every pod at once, and at the abort the canary's p95
  was 2.26 s against stable's 2.52 s (Prometheus, same 30 s window). The p95 check
  now fails only when the canary is also more than twice stable's p95.
* **Envoy draining client connections on shutdown** was the first guess for the
  remaining 1–3 failures (keep-alive connections outliving a pod's removal from the
  Service). It made no difference: 5, 5 and 2.
* **Idle timeout and retry.** Every failure was a 5xx, and the application had
  logged no errors in the pods still there to check. Envoy now closes idle
  connections to the app after 4 s, before uvicorn's 5 s keep-alive timeout can
  close them under it, and retries once a request the app never received
  (`reset-before-request`, safe for any method). Three runs, no failures. After the
  change the sampled pods showed Envoy closing idle connections (0–5 times per pod)
  and no retries, which fits the keep-alive race but does not prove it; the 5xx
  access log is there to settle it if failures come back.

## 3. A bad release under load

**Method.** `scripts/measure/bad-canary.sh`. The same as above, but the release turns on
the Envoy fault filter in the new pods only: 30% of requests get a 500
([docs/fault-injection.md](docs/fault-injection.md)). A poller records, from the API
server, when the first bad pod was created and became Ready, when the Rollout aborted,
and when the last bad pod was gone. k6 counts every reply by its `x-release` header.
Afterwards the previous release is restored by another commit, which Argo Rollouts
treats as a rollback to the stable ReplicaSet.

Two kinds of client: k6's default, which keeps connections alive like most HTTP
clients, and `NO_REUSE=1`, a new connection per request.

### Bad release (sidecar aborts 30% with 500), 20 req/s, keep-alive clients

| run | push → first bad pod (s) | first bad pod → abort (s) | bad pod Ready → abort (s) | abort → bad pods gone (s) | requests | served by bad release | failed | bad share, whole run | bad share while it was Ready | bad release promoted? |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 17.9 | 33.0 | 31.0 | 16.8 | 4801 | 104 | 25 | 2.2% | 10.9% | no |
| 2 | 13.3 | 33.0 | 30.0 | 17.1 | 4800 | 39 | 11 | 0.8% | 4.1% | no |
| 3 | 13.0 | 79.0 | 75.0 | 19.2 | 4801 | 32 | 13 | 0.7% | 1.7% | no |
| median | 13.3 | 33.0 | 31.0 | 17.1 | 4,801 | 39 | 13 | 0.8% | 4.1% |  |

### Bad release (sidecar aborts 30% with 500), 20 req/s, a new connection per request

| run | push → first bad pod (s) | first bad pod → abort (s) | bad pod Ready → abort (s) | abort → bad pods gone (s) | requests | served by bad release | failed | bad share, whole run | bad share while it was Ready | bad release promoted? |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 12.6 | 33.0 | 30.0 | 17.6 | 4801 | 128 | 39 | 2.7% | 13.4% | no |
| 2 | 14.3 | 33.0 | 30.0 | 16.7 | 4801 | 124 | 32 | 2.6% | 13.3% | no |
| 3 | 14.0 | 34.0 | 31.0 | 16.6 | 4801 | 114 | 36 | 2.4% | 12.0% | no |
| median | 14.0 | 33.0 | 30.0 | 16.7 | 4,801 | 124 | 36 | 2.6% | 13.3% |  |

**Result.** The analysis aborted every bad release, 30–31 s after the bad pod became
Ready (median), and no bad release was promoted in these six runs. Detection time is
almost exactly the analysis's initial delay: in five of six runs the first
measurement, 30 s after the canary starts, already saw a 5xx rate of 0.24–0.31
against a 5% limit. The delay is there because without it a good canary's cold
first requests failed the p95 check; it costs 30 s of exposure on every bad release.

**How much traffic the bad release got depends on the client.** With replica
weighting, 20% means one pod in five. Clients opening a new connection per request
sent it 13% of their requests while it was Ready (the window includes its last
seconds of draining, when it no longer receives new connections). Keep-alive clients
sent it 1.7–10.9%: a kept-alive connection stays on the pod it first reached, so a
new pod only gets connections opened after it became Ready. That made the third
keep-alive run the slowest: the canary served 32 requests in total, the first three
measurements saw no failure, and it took 75 s to abort. With a traffic router the
canary's share would be set per request rather than per pod (roadmap).

Over a whole run, 11–39 requests in 4,800 (0.2–0.8%) failed because of the bad
release. After the abort its pods take about 17 s to disappear, because each one
drains before it exits; they are out of the Service's endpoints from the start of
that.

**A bad release was promoted once, before this version.** During an earlier set of
runs a host stall delayed Argo CD's sync by 226 s, k6 had finished before the canary
was Ready, every analysis measurement saw no traffic and passed, and the release was
promoted (`results/bad-canary-promoted-without-traffic.jsonl`). Every check passes on
no data, by design: an empty window is not evidence of failure. The fix is a last
canary step that requires at least 30 requests on the canary in the past three
minutes, and aborts otherwise. The cost showed up immediately: the platform change
that added it could not promote either, because nothing was calling the api; it went
out under 20 req/s of synthetic traffic.

## 4. Admission: each Kyverno policy against a violating manifest

**Method.** `scripts/measure/policies.sh` submits, with `kubectl create --dry-run=server`,
one compliant Pod, one Pod per violation and a Deployment using `:latest`, to a
namespace labelled `platform.policy/enforce=true` with no Pod Security Admission label,
so every rejection is Kyverno's. Full output: `results/policies.txt`.

| manifest | violation | result | policy / rule: message |
|---|---|---|---|
| `good` | compliant Pod | admitted | |
| `bad-latest` | Pod, image `:latest` | **rejected** | `disallow-latest-tag` / `require-explicit-tag`: Image tag ':latest' (or no tag) is not allowed; pin an immutable tag. |
| `bad-untagged` | Pod, image without a tag | **rejected** | `disallow-latest-tag` / `require-explicit-tag`: Image tag ':latest' (or no tag) is not allowed; pin an immutable tag. |
| `bad-no-resources` | Pod, no requests or limits | **rejected** | `require-requests-limits` / `containers-have-resources`: Every container needs cpu and memory requests and a memory limit. |
| `bad-root` | Pod, no `runAsNonRoot` | **rejected** | `require-run-as-non-root` / `run-as-non-root`: Set runAsNonRoot: true on the pod or on every container. |
| `bad-privileged` | Pod, `privileged: true` | **rejected** | `disallow-privileged` / `no-privileged`: Privileged containers and allowPrivilegeEscalation: true are not allowed. |
| `deploy-latest` | Deployment, image `:latest` | **rejected** | `disallow-latest-tag` / `autogen-require-explicit-tag`: Image tag ':latest' (or no tag) is not allowed; pin an immutable tag. |

The Deployment is rejected by the rule Kyverno generates for Pod controllers
(`autogen-require-explicit-tag`): at admission of the Deployment itself, not later
when its pods fail to start.

The same fixtures run without a cluster in CI: `kyverno test` passes 22 of 22 cases.

**NetworkPolicy.** `scripts/measure/netpol.sh` calls the api Service from the `load`
namespace and from `default`:

| from namespace | result |
|---|---|
| `load` | HTTP 200 |
| `default` | no answer within 5 s (curl exit 28, connection timed out) |

## 5. Draining a worker under load

**Method.** `scripts/measure/drain.sh`. k6 at 20 req/s for 4 minutes; after 20 s,
`kubectl drain` on the worker that does not host the PostgreSQL primary
(`--ignore-daemonsets --delete-emptydir-data --timeout=300s`). Everything evictable
moves to the other worker. "Pods on node" includes the two DaemonSet pods that stay. Then the worker is uncordoned and the workloads restarted so
the next run starts spread out.

| run | node | pods on node | api pods on node | drain (s) | result | requests | failed | p95 ms | max ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | platform-worker2 | 7 | 2 | 31.2 | ok | 4801 | 0 | 24.6 | 346 |
| 2 | platform-worker2 | 9 | 3 | 32.2 | ok | 4791 | 0 | 634.3 | 4,802 |
| 3 | platform-worker2 | 9 | 3 | 39.3 | ok | 4663 | 28 | 1,021.5 | 10,058 |
| median |  |  |  | 32.2 |  | 4,791 | 0 | 634.3 | 4,802 |

**Result.** Each drain completed in 31–39 s. The api's PodDisruptionBudget
(`minAvailable: 3`) did its job: the drain log shows evictions refused ("would
violate the pod's disruption budget") and retried until replacements were Ready
(`results/drain-run*.log`). Two of three runs failed no requests.

The third run failed 28 of 4,663 requests (0.6%): 25 timed out at 10 s and 3 got a
5xx, with a p95 of 1.0 s and 138 arrivals k6 could not start in time. Run 2 was
slower than run 1 as well (p95 634 ms). With one worker gone, every pod is on the
other one, several Python processes are starting at once, and all of it shares one
host's CPU. Losing half the cluster's capacity under load shows up as latency first;
on this host, in one run of three, as timeouts.

Two things these runs do not cover. The drained worker is always the one without the
PostgreSQL primary: its data is on node-local storage and its PodDisruptionBudget
blocks eviction, so draining that node is a switchover first. And the PostgreSQL
replica on the drained node stays Pending until the node is uncordoned, for the same
reason.

## 6. Resource footprint at rest

**Method.** `scripts/measure/footprint.sh`: `kubectl top` per node and summed per
namespace, plus `docker stats` for the node containers, with the platform idle.

Taken five minutes after the last drain run's restarts had settled.

#### kubectl top nodes
```
NAME                     CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)   
platform-control-plane   466m         5%       2937Mi          24%         
platform-worker          481m         6%       3130Mi          26%         
platform-worker2         216m         2%       1189Mi          9%          
```

#### kubectl top pods, summed per namespace

| namespace | pods | CPU (millicores) | memory (MiB) |
|---|---:|---:|---:|
| kube-system | 13 | 358 | 2761 |
| governed-agent | 11 | 249 | 1132 |
| argocd | 5 | 101 | 856 |
| observability | 2 | 26 | 484 |
| monitoring | 2 | 25 | 169 |
| kyverno | 1 | 17 | 73 |
| cnpg-system | 1 | 8 | 42 |
| argo-rollouts | 1 | 6 | 35 |
| local-git | 1 | 2 | 25 |
| local-path-storage | 1 | 1 | 24 |
| **total** | 38 | 793 | 5601 |

#### docker stats (node containers)
```
NAME                            CPU %     MEM USAGE / LIMIT
platform-control-plane          19.70%    2.864GiB / 11.67GiB
platform-worker                 30.05%    2.953GiB / 11.67GiB
platform-worker2                13.16%    1.162GiB / 11.67GiB
```

Requests and limits are what the scheduler sees; actual use at rest is about 0.8 CPU
and 5.5 GiB across the three nodes. The largest single process is the API server,
at 1.3–1.8 GiB resident during these runs.

## What broke on the way, and what changed

The platform did not hold up the first time. These are the failures the runs found,
in order, and the fix for each; every fix is a commit.

| # | What happened | What changed | Commit |
|---:|---|---|---|
| 1 | Every api and mcp pod crash-looped: Kubernetes service links set `GA_API_PORT=tcp://10.96.x.x:80`, which the app reads as its port | `enableServiceLinks: false` on every pod | `c48b399` |
| 2 | The web pods restarted whenever the api was down: their liveness probe fetched a page that calls the api | TCP probes for web | `c48b399` |
| 3 | The application's sync wave started before its database had a primary: a CloudNativePG `Cluster` counted as healthy as soon as it existed | A Lua health check for `Cluster`, next to the one for `Application` that sync waves needed from the start | `c48b399` |
| 4 | Kyverno's Application never went Synced: its chart renders empty labels and annotations on its CRDs | `ignoreDifferences` for those two fields | `c48b399` |
| 5 | Bootstrap stalled with Deployments not progressing: etcd request timeouts on the Docker VM's disk cost the controller manager its leader lease, and it crash-looped | etcd on the control-plane node's tmpfs | `a43397f` |
| 6 | An mcp pod was killed by its liveness probe before Python had finished importing | Startup probes; api liveness no longer runs `SELECT 1`, so a database outage removes pods from the Service instead of restarting them | `77defb1` |
| 7 | A healthy PostgreSQL primary was restarted: CloudNativePG's liveness probe also checks that the primary can reach the API server, with a 1 s timeout | 5 s isolation-check timeouts; a startup probe for the Collector; the outbox worker polls every 5 s, not every second on each replica | `8edd6ee` |
| 8 | The API server was the busiest process on the host | Kyverno runs only its admission controller; Prometheus scrapes only the PodMonitors, with no default rules | `64c8109` |
| 9 | The controller manager and scheduler kept losing their 15 s leases on a busy API server | 60 s leases | `582cd11` |
| 10 | The first good release under load cascaded: 1 s probe timeouts restarted Kyverno, metrics-server, the Prometheus operator and Argo CD's repo server, each restart made the API server busier, and Kyverno's webhooks, cluster-wide and failing closed, blocked pod creation in every namespace while it was down | Kyverno's webhooks scoped to enforced namespaces; 5 s probe timeouts for third-party controllers; Envoy with 2 workers instead of one per host CPU; Prometheus scrapes only the counters it uses; api CPU request 250m so the HPA stops scaling on import spikes; analysis waits 30 s and uses a 30 s window; Argo CD reconciles every 3 minutes | `461c2c5` |
| 11 | A good release was aborted on p95 during a stall that slowed every pod; its p95 was lower than stable's | The p95 check compares the canary with stable | `bad05e2` |
| 12 | Good releases failed 1–3 requests in 6,000 | Envoy drains client connections on shutdown: no effect (`859812f`). Upstream idle timeout below uvicorn's, retry if the app never saw the request: no failures | `859812f`, `c1a9967` |
| 13 | The second drain run evicted the load generator with everything else | k6 runs on the control-plane node | `e5e1220` |
| 14 | A bad release was promoted: a host stall delayed the sync past the end of the load, and every check passed on no data | The canary must serve 30 requests before promotion | `c1a9967` |
| 15 | Rehearsing the CI job: the PostgreSQL `Cluster` was applied before its namespace, and Helm 4's readiness watcher never reports a Rollout as ready | Namespace first; Helm waits for the migration hook only, kubectl for the rest | `5dc2ddc` |

Most of these are what a shared, CPU-bound host does to a control plane: slow API
calls, then probe and lease timeouts, then restarts that make the API server slower
still. A production cluster has more headroom, but the fixes are not lab-specific.
Probe timeouts sized for a busy node, webhooks scoped to what they judge, analysis
that compares with a baseline and refuses to pass on no data: each would have
mattered on a bad day anywhere.
