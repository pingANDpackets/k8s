# Observability Playbook

## Installation

```bash
make observability
```

Components installed into the `observability` namespace:

- `kube-prometheus-stack-grafana` (NodePort `32000`, admin/admin).
- `kube-prometheus-stack-prometheus` scraping cluster + ServiceMonitor targets.
- `metrics-server` enabling `kubectl top` and HPA metrics.

## Access Grafana

```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n observability 3000:80
# Browse http://localhost:3000 (admin/admin)
```

Recommended dashboards:

- `Kubernetes / Compute Resources / Namespace (Pods)` → per-tenant namespaces.
- `Kubernetes / Compute Resources / Workload` → watch HPA-driven replica changes.
- `Node Exporter / Nodes` → cluster-wide CPU/memory.

## Monitor Autoscaling

```bash
kubectl get hpa -A
kubectl top pods -n user1
kubectl describe hpa user1-tenant-site -n user1
```

Use `make load-test` (or `CONCURRENCY=50 make load-test`) to trigger CPU spikes and observe HPA decisions in Grafana and via `kubectl describe`.

## Troubleshooting

- Ensure `metrics-server` pods are Ready; restart if certificates expired.
- If ServiceMonitors are not discovered, verify Prometheus values: `serviceMonitorSelectorNilUsesHelmValues=false`.
- Grafana login fails? Reset by port-forwarding and updating secret: `kubectl get secret kube-prometheus-stack-grafana -n observability -o jsonpath='{.data.admin-password}' | base64 -d`.
