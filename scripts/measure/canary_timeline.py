"""Poll the cluster while a bad canary runs and print one JSON timeline.

Times are seconds since the release commit was pushed (argv[2], epoch seconds).
Pod and Rollout timestamps come from the API server; `seen_*` fields are when this
poller first observed a state, at a 0.5 s polling interval.
"""

import json
import subprocess
import sys
import time
from datetime import datetime

NOTE, T0 = sys.argv[1], float(sys.argv[2])
TIMEOUT = 420


def kube(*args: str) -> dict:
    out = subprocess.run(["kubectl", "-n", "governed-agent", *args, "-o", "json"],
                         capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def ts(s: str | None) -> float | None:
    return datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp() - T0 if s else None


def rel(t: float) -> float:
    return round(t - T0, 1)


tl: dict = {"note": NOTE}
start = time.time()
while time.time() - start < TIMEOUT:
    pods = [p for p in kube("get", "pods", "-l", "app.kubernetes.io/name=api")["items"]
            if p["metadata"].get("annotations", {}).get("release-note") == NOTE]
    ro = kube("get", "rollout", "ga-api")
    now = time.time()
    for p in pods:
        tl.setdefault("first_pod_created", ts(p["metadata"]["creationTimestamp"]))
        tl.setdefault("canary_hash", p["metadata"]["labels"].get("rollouts-pod-template-hash"))
        for c in p["status"].get("conditions", []):
            if c["type"] == "Ready" and c["status"] == "True":
                tl.setdefault("first_pod_ready", ts(c["lastTransitionTime"]))
        if p["metadata"].get("deletionTimestamp"):
            tl.setdefault("seen_pod_terminating", rel(now))
    st = ro.get("status", {})
    if st.get("abort"):
        tl.setdefault("seen_aborted", rel(now))
        tl.setdefault("aborted_at", ts(st.get("abortedAt")))
        tl.setdefault("abort_message", st.get("message"))
    if "seen_aborted" in tl and "first_pod_created" in tl and not pods:
        tl["seen_canary_gone"] = rel(now)
        break
    if st.get("phase") == "Healthy" and st.get("stableRS") == tl.get("canary_hash"):
        tl["promoted_bad_release"] = True  # the analysis failed to catch it
        break
    time.sleep(0.5)
else:
    tl["timed_out"] = True

runs = [a for a in kube("get", "analysisruns")["items"]
        if a["metadata"].get("labels", {}).get("rollouts-pod-template-hash") == tl.get("canary_hash")]
if runs:
    a = max(runs, key=lambda r: r["metadata"]["creationTimestamp"])
    tl["analysis"] = {
        "name": a["metadata"]["name"],
        "phase": a.get("status", {}).get("phase"),
        "started": ts(a["metadata"]["creationTimestamp"]),
        "measurements": [
            {"metric": m["name"], "phase": x.get("phase"), "value": x.get("value"),
             "at": ts(x.get("finishedAt") or x.get("startedAt"))}
            for m in a.get("status", {}).get("metricResults", [])
            for x in m.get("measurements", [])
        ],
    }
print(json.dumps(tl))
