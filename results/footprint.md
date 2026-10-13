# Footprint at rest, 2026-10-13T16:55:34Z

## kubectl top nodes
```
NAME                     CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)   
platform-control-plane   466m         5%       2937Mi          24%         
platform-worker          481m         6%       3130Mi          26%         
platform-worker2         216m         2%       1189Mi          9%          
```

## kubectl top pods, summed per namespace

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

## docker stats (node containers)
```
NAME                            CPU %     MEM USAGE / LIMIT
platform-control-plane          19.70%    2.864GiB / 11.67GiB
platform-worker                 30.05%    2.953GiB / 11.67GiB
platform-worker2                13.16%    1.162GiB / 11.67GiB
```
