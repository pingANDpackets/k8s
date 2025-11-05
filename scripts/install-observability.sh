#!/usr/bin/env bash
set -euo pipefail

command -v helm >/dev/null 2>&1 || {
  echo "WARNING: helm is required. Install from https://helm.sh/docs/intro/install/." >&2
  exit 1
}

echo "Installing metrics-server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo "Installing kube-prometheus-stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --create-namespace \
  -f infra/addons/prometheus-values.yaml

echo "Waiting for Prometheus & Grafana to be ready..."
kubectl wait --for=condition=Available deployment/kube-prometheus-stack-grafana -n observability --timeout=180s
kubectl rollout status statefulset/prometheus-kube-prometheus-stack-prometheus -n observability --timeout=300s

echo "Observability stack ready. Access Grafana via NodePort 32000 or use 'kubectl port-forward svc/kube-prometheus-stack-grafana -n observability 3000:80'."
