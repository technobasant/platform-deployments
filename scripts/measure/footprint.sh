#!/usr/bin/env bash
# Resource use at rest: kubectl top per node and summed per namespace, and what the
# three node containers use on the host.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
out=results/footprint.md
{
  echo "# Footprint at rest, $(date -u +%FT%TZ)"
  echo; echo '## kubectl top nodes'; echo '```'; kubectl top nodes; echo '```'
  echo; echo '## kubectl top pods, summed per namespace'; echo
  kubectl top pods -A --no-headers | python3 -c '
import sys, collections
cpu, mem, n = collections.Counter(), collections.Counter(), collections.Counter()
for line in sys.stdin:
    ns, _, c, m = line.split()[:4]
    cpu[ns] += int(c.rstrip("m")); mem[ns] += int(m.rstrip("Mi")); n[ns] += 1
print("| namespace | pods | CPU (millicores) | memory (MiB) |")
print("|---|---:|---:|---:|")
for ns in sorted(mem, key=mem.get, reverse=True):
    print(f"| {ns} | {n[ns]} | {cpu[ns]} | {mem[ns]} |")
print(f"| **total** | {sum(n.values())} | {sum(cpu.values())} | {sum(mem.values())} |")
'
  echo; echo '## docker stats (node containers)'; echo '```'
  docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' | grep -E "NAME|$CLUSTER"
  echo '```'
} | tee "$out"
