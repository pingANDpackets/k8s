# Scaling Strategy & Resource Allocation

This project treats each tenant namespace as an isolated “mini environment” with predictable resource envelopes and the ability to scale on demand. The key components:

## Horizontal Pod Autoscaling (HPA)

- **Policy**: Each tenant deployment has an HPA targeting 60% CPU and 70% memory utilization.
- **Ranges**: Minimum replicas = 1 (baseline availability), maximum = 4 (burst capacity without overwhelming the namespace quota).
- **Signals**: Metrics come from the cluster’s `metrics-server`; Grafana dashboards (`Kubernetes / Compute Resources / Workload`) visualize utilization trends.
- **Workflow**: During load spikes (`run-load-test.sh`), the HPA increases replicas to keep CPU < 60%. After traffic normalizes, replicas return to 1 to save resources.

## Resource Quotas & LimitRanges

- **Quota (per namespace)**  
  ```yaml
  hard:
    pods: "10"
    requests.cpu: "500m"
    requests.memory: 1Gi
    limits.cpu: "1200m"
    limits.memory: 2Gi
  ```
  Ensures no tenant can consume more than its fair share. Raising `limits.cpu` to 1200m allows temporary scaling (four pods × 300m each) while capping total usage.

- **LimitRange**  
  Sets default requests (100m CPU / 128Mi memory) and limits (300m CPU / 256Mi memory) at the container level. New pods inherit sensible defaults without manual tuning.

## PodDisruptionBudget (PDB)

- Each tenant deployment has a PDB requiring at least one pod to stay available. This prevents voluntary disruptions (e.g., node drains, upgrades) from taking the site offline.

## NetworkPolicy & Isolation

- Although primarily for security, namespace-scoped NetworkPolicies ensure traffic enters only via ingress-nginx. This keeps autoscaled replicas from exposing services directly and avoids noisy-neighbor effects between tenants.

## Observability & Feedback Loop

- Grafana dashboards (`Kubernetes / Compute Resources / Namespace (Pods)` and `Workload`) show CPU/memory trends per tenant.
- `kubectl top` complements the dashboards for CLI demos.
- Kafka deployment events include the image tag and namespace, allowing downstream systems to correlate scale events with releases if needed.

## Operational Playbook

1. **Baseline**: 1 replica, 100m CPU / 128Mi request, low idle cost.
2. **Burst**: Run `CONCURRENCY=150 DURATION=120 ./scripts/run-load-test.sh user1.127.0.0.1.sslip.io` to simulate traffic; HPA scales to 3–4 replicas while staying within quota.
3. **Monitor**: Use `watch -n 5 'kubectl get hpa -n user1; echo; kubectl top pods -n user1'` and Grafana dashboards.
4. **Recover**: When load stops, replicas drop back to 1 automatically—no manual intervention required.

This combination balances isolation (quotas, limits, network policies) with elasticity (HPA, PDB). Tenants get predictable performance, yet the platform remains efficient by shedding extra pods when traffic is low.
