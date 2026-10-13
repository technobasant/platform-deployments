"""Print the MEASUREMENTS.md tables from results/*.jsonl (medians over runs)."""

import json
import statistics
from pathlib import Path

R = Path(__file__).resolve().parents[2] / "results"


def load(name: str) -> list[dict]:
    p = R / f"{name}.jsonl"
    return [json.loads(line) for line in p.read_text().splitlines() if line.strip()] if p.exists() else []


def med(xs: list[float]) -> float:
    return statistics.median(xs) if xs else float("nan")


def fmt(x: float, nd: int = 1) -> str:
    return f"{x:,.{nd}f}"


def table(rows: list[list[str]], head: list[str]) -> None:
    print("| " + " | ".join(head) + " |")
    print("|" + "|".join("---" if i == 0 else "---:" for i in range(len(head))) + "|")
    for r in rows:
        print("| " + " | ".join(r) + " |")
    print()


b = load("bootstrap")
if b:
    print("### Bootstrap\n")
    keys = [("cluster_s", "kind create cluster"), ("load_images_s", "kind load (3 images)"),
            ("bootstrap_s", "make bootstrap"), ("apps_healthy_after_root_s", "  of which: root app → all healthy"),
            ("total_s", "zero → all Applications healthy")]
    table([[label] + [fmt(r[k], 0) for r in b] + [fmt(med([r[k] for r in b]), 0)] for k, label in keys],
          ["seconds"] + [f"run {r['run']}" for r in b] + ["median"])

ro = load("rollout")
if ro:
    print("### Good release through the canary, 40 req/s\n")
    rows = []
    for r in ro:
        k = r["k6"]
        rows.append([str(r["run"]), fmt(r["sync_s"]), fmt(r["promotion_s"]), str(k["requests"]), str(k["failed"]),
                     fmt(k["p50_ms"]), fmt(k["p95_ms"]), fmt(k["max_ms"], 0), str(k["dropped_iterations"])])
    rows.append(["median", fmt(med([r["sync_s"] for r in ro])), fmt(med([r["promotion_s"] for r in ro])),
                 fmt(med([r["k6"]["requests"] for r in ro]), 0), fmt(med([r["k6"]["failed"] for r in ro]), 0),
                 fmt(med([r["k6"]["p50_ms"] for r in ro])), fmt(med([r["k6"]["p95_ms"] for r in ro])),
                 fmt(med([r["k6"]["max_ms"] for r in ro]), 0), fmt(med([r["k6"]["dropped_iterations"] for r in ro]), 0)])
    table(rows, ["run", "push → new ReplicaSet (s)", "new ReplicaSet → fully promoted (s)", "requests",
                 "failed", "p50 ms", "p95 ms", "max ms", "dropped"])

bc = load("bad-canary")
if bc:
    print("### Bad release (sidecar aborts 30% with 500), 40 req/s\n")
    rows = []
    vals: dict[str, list[float]] = {}
    for r in bc:
        t, k = r["timeline"], r["k6"]
        created, ready = t.get("first_pod_created"), t.get("first_pod_ready")
        abort = t.get("aborted_at") if t.get("aborted_at") is not None else t.get("seen_aborted")
        gone = t.get("seen_canary_gone")
        exposure = (gone - ready) if (gone is not None and ready is not None) else float("nan")
        share_window = k["hits_bad_release"] / (r["rate"] * exposure) if exposure == exposure and exposure > 0 else float("nan")
        row = {
            "created": created, "ready_to_abort": abort - ready if abort is not None and ready is not None else float("nan"),
            "created_to_abort": abort - created if abort is not None and created is not None else float("nan"),
            "abort_to_gone": gone - abort if gone is not None and abort is not None else float("nan"),
            "bad_hits": k["hits_bad_release"], "failed": k["failed"], "requests": k["requests"],
            "share_run": k["hits_bad_release"] / k["requests"], "share_window": share_window,
        }
        for key, v in row.items():
            vals.setdefault(key, []).append(v)
        rows.append([str(r["run"]), fmt(created), fmt(row["created_to_abort"]), fmt(row["ready_to_abort"]),
                     fmt(row["abort_to_gone"]), str(k["requests"]), str(row["bad_hits"]), str(k["failed"]),
                     f"{100 * row['share_run']:.1f}%", f"{100 * share_window:.1f}%",
                     "yes" if t.get("promoted_bad_release") else "no"])
    rows.append(["median", fmt(med(vals["created"])), fmt(med(vals["created_to_abort"])), fmt(med(vals["ready_to_abort"])),
                 fmt(med(vals["abort_to_gone"])), fmt(med(vals["requests"]), 0), fmt(med(vals["bad_hits"]), 0),
                 fmt(med(vals["failed"]), 0), f"{100 * med(vals['share_run']):.1f}%",
                 f"{100 * med(vals['share_window']):.1f}%", ""])
    table(rows, ["run", "push → first bad pod (s)", "first bad pod → abort (s)", "bad pod Ready → abort (s)",
                 "abort → bad pods gone (s)", "requests", "served by bad release", "failed",
                 "bad share, whole run", "bad share while it was Ready", "bad release promoted?"])

d = load("drain")
if d:
    print("### Drain a worker, 40 req/s\n")
    rows = []
    for r in d:
        k = r["k6"]
        rows.append([str(r["run"]), r["node"], str(r["pods_on_node"]), str(r["api_pods_on_node"]), fmt(r["drain_s"]),
                     r["drain"], str(k["requests"]), str(k["failed"]), fmt(k["p95_ms"]), fmt(k["max_ms"], 0)])
    rows.append(["median", "", "", "", fmt(med([r["drain_s"] for r in d])), "",
                 fmt(med([r["k6"]["requests"] for r in d]), 0), fmt(med([r["k6"]["failed"] for r in d]), 0),
                 fmt(med([r["k6"]["p95_ms"] for r in d])), fmt(med([r["k6"]["max_ms"] for r in d]), 0)])
    table(rows, ["run", "node", "pods on node", "api pods on node", "drain (s)", "result", "requests", "failed",
                 "p95 ms", "max ms"])
