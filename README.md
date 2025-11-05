# Multi-Tenant DevOps Platform (Local Environment)

This repository delivers a local-first implementation of the scenario requirements:

- Multi-tenant Kubernetes workloads (user1/user2/user3) with dynamic domain mapping and TLS.
- CI/CD pipeline that builds Docker images, deploys per-user releases, performs automated rollbacks, and emits Kafka deployment events.
- Autoscaling, pod disruption budgets, resource quotas, and full observability via Prometheus and Grafana.
- Kafka stack for publishing and consuming deployment events.

## Local Tooling Overview

| Component | Purpose | Tooling |
| --- | --- | --- |
| Kubernetes cluster | Runs workloads locally | [`kind`](https://kind.sigs.k8s.io) (Kubernetes in Docker) |
| Container registry | Local image push/pull for CI/CD | Docker registry container (`registry:2`) wired to kind |
| TLS + ingress | HTTPS & wildcard hostnames | `ingress-nginx` + `cert-manager` self-signed wildcard |
| Domains | Dynamic hostnames | `*.127.0.0.1.sslip.io` via [sslip.io](https://sslip.io) |
| CI/CD runner | Local execution of the pipeline | GitHub Actions workflow runnable with [`act`](https://github.com/nektos/act) |
| Kafka | Event broker | Docker Compose with single-node Kafka/ZooKeeper |
| Observability | Metrics and dashboards | `kube-prometheus-stack` Helm chart |

> **Goal:** Everything (cluster, registry, Kafka, observability, pipelines) runs on your workstation with minimal external dependencies.

## High-Level Flow

1. **Cluster Bootstrap**: Scripts provision kind, connect it to a local Docker registry, and install ingress-nginx and cert-manager.
2. **Tenant Releases**: A Helm chart (`charts/tenant-site`) encapsulates app deployment primitives (ingress, probes, HPA, quotas, NetworkPolicies, PDB).
3. **Domain Mapping**: A wildcard ingress (`*.dev.localhost`) lets you add namespaces/hosts dynamically without reconfiguring ingress.
4. **CI/CD**: GitHub Actions workflow builds language-specific Docker images, pushes them to the local registry, deploys per namespace, runs smoke checks, and performs an automated rollback on failure.
5. **Kafka Events**: Pipeline steps publish `WebsiteCreated` events to Kafka. A lightweight consumer verifies delivery.
6. **Scaling & Observability**: HPA reacts to CPU/memory thresholds. Prometheus/Grafana expose dashboards to observe the cluster and per-tenant workloads. Load can be simulated with `k6` or `hey`.

## Repository Layout (planned)

```
apps/
  node-site/              # Express app + Dockerfile
  flask-site/             # Flask app + Dockerfile
charts/
  tenant-site/            # Helm chart used for each tenant release
infra/
  kind/                   # Kind cluster + registry manifests
  addons/                 # Ingress, cert-manager, prometheus, grafana
  kafka/                  # Docker Compose for Kafka/ZooKeeper + tooling
.github/workflows/        # CI/CD pipeline definition
scripts/                  # Helper scripts (bootstrap, deploy, load-test, rollback)
docs/                     # Additional guides, screenshots, observability notes
```

The forthcoming sections and assets will align with the deliverables listed in `Scenario.docx`. As the repository evolves, this `README` will expand with detailed setup steps, validation commands, and troubleshooting tips.

## Get Started

1. **Bootstrap Kubernetes & dependencies**
   ```bash
   make setup-kind
   ```
   This creates the kind cluster, patches the local registry, installs ingress-nginx and cert-manager, and provisions a local certificate authority for TLS issuance.

2. **Build tenant container images**
   ```bash
   make build-images
   ```
   The script builds the Node.js and Flask sample sites and pushes them into the local registry (`localhost:5001`).

3. **Deploy tenants into isolated namespaces**
   ```bash
   make deploy-tenants
   ```
   Tenants (`user1`, `user2`, `user3`) are installed via the `tenant-site` Helm chart. The script waits for deployments, prints `kubectl get all` per namespace, and confirms readiness.

4. **Validate dynamic routing + TLS**
   ```bash
   curl -k https://user1.127.0.0.1.sslip.io
   curl -k https://user2.127.0.0.1.sslip.io
   curl -k https://user3.127.0.0.1.sslip.io
   ```
   Each hostname resolves via `sslip.io` back to `127.0.0.1`, letting you add new tenants by simply charting a new release (`helm upgrade --install user4 ... --set ingress.host=user4.127.0.0.1.sslip.io`).

5. **(Optional) Install observability stack**
   ```bash
   make observability
   ```
   Prometheus and Grafana are deployed to the `observability` namespace. Grafana exposes NodePort `32000` (user/pass `admin/admin`).

6. **(Optional) Start Kafka broker**
   ```bash
   make kafka-up
   ```
   A single-node Kafka instance comes online at `localhost:9092` ready to accept deployment events.

## Dynamic Domain Mapping Strategy

- The ingress uses a dedicated hostname per tenant (e.g., `user1.127.0.0.1.sslip.io`) which resolves to localhost without any `/etc/hosts` edits.
- Certificates are minted automatically by cert-manager through the `dev-localhost-issuer` (a local CA) and mounted as TLS secrets per namespace.
- Adding a new user requires only a new Helm release with an updated values file—no cluster-wide changes or ingress restarts.

## Kafka & Deployment Events

- Bring Kafka online with `make kafka-up` (and tear it down with `make kafka-down`).
- Publish events manually if desired:
  ```bash
  python3 -m pip install -r requirements-dev.txt
  python3 scripts/publish_website_event.py user1 localhost:5001/tenant-node-site:latest user1
  ```
- Stream events:
  ```bash
  python3 scripts/consume_website_events.py
  ```
- The CI/CD workflow automatically emits a `WebsiteCreated` payload at the end of each successful tenant deployment.

## CI/CD Workflow (GitHub Actions)

- Workflow file: `.github/workflows/ci-cd.yaml`
- Jobs:
  - `build`: builds & pushes Node.js/Flask images to `localhost:5001`.
  - `deploy`: matrix-driven deployment per tenant with Helm, rollout verification, automated rollback, smoke tests, Kafka event trigger, and namespace snapshot (`kubectl get all`).
- Trigger: pushes to `main` or `staging`, plus manual `workflow_dispatch`.
- Local run with [`act`](https://github.com/nektos/act):
  ```bash
  act workflow_dispatch -W .github/workflows/ci-cd.yaml \
    -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest \
    --container-options "--network host -v $HOME/.kube:/home/runner/.kube:ro" \
    --container-architecture linux/amd64 \
    --env REGISTRY=localhost:5001 \
    --env PUSH_REGISTRY=host.docker.internal:5001 \
    --env IMAGE_TAG=$(git rev-parse HEAD)
  ```
  Ensure the kind cluster, local registry, and Kafka are already running and that your kubeconfig is mounted read-only into the runner container.

## Scaling & Observability

- `tenant-site` chart enables HorizontalPodAutoscaler, ResourceQuota, LimitRange, PodDisruptionBudget, and optional ServiceMonitor resources by default.
- Generate synthetic load to demonstrate autoscaling (`CONCURRENCY=30 make load-test`) and monitor with:
  ```bash
  kubectl get hpa -A
  kubectl top pods -n user1
  ```
- Install Prometheus/Grafana via `make observability`; use Grafana dashboards (`Node Exporter`, `Kubernetes / Compute Resources / Namespace (Pods)`) to visualize scaling behaviour.
- Notes explaining the scaling strategy and resource allocation live in `docs/scaling-notes.md`.
