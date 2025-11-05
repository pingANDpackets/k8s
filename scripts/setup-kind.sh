#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="multi-tenant"
REGISTRY_NAME="kind-registry"
REGISTRY_PORT="5001"
KIND_CONFIG="infra/kind/kind-config.yaml"

command -v kind >/dev/null 2>&1 || {
  echo "WARNING: kind is required. Install from https://kind.sigs.k8s.io/docs/user/quick-start/." >&2
  exit 1
}
command -v kubectl >/dev/null 2>&1 || {
  echo "WARNING: kubectl is required. Install from https://kubernetes.io/docs/tasks/tools/." >&2
  exit 1
}
command -v helm >/dev/null 2>&1 || {
  echo "WARNING: helm is required. Install from https://helm.sh/docs/intro/install/." >&2
  exit 1
}

echo "Ensuring local Docker registry ${REGISTRY_NAME}:${REGISTRY_PORT}..."
if [ "$(docker ps -aq -f name=${REGISTRY_NAME})" ]; then
  docker start "${REGISTRY_NAME}" >/dev/null
else
  docker run -d --restart=always -p "${REGISTRY_PORT}:5000" --name "${REGISTRY_NAME}" registry:2
fi

if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "kind cluster ${CLUSTER_NAME} already exists. Skipping creation."
else
  echo "Creating kind cluster ${CLUSTER_NAME}..."
  kind create cluster --config "${KIND_CONFIG}"
fi

# Ensure the registry is connected to the kind network so pods can pull images.
if ! docker inspect "${REGISTRY_NAME}" | grep -q '"kind"'; then
  echo "Connecting registry to kind network..."
  docker network connect "kind" "${REGISTRY_NAME}" || true
fi

echo "Publishing local registry information to the cluster..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

echo "Installing ingress-nginx..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null
helm repo update >/dev/null
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.publishService.enabled=true \
  --set controller.metrics.enabled=true \
  --set controller.extraArgs.enable-ssl-passthrough=true \
  --set controller.hostPort.enabled=true \
  --set controller.hostPort.ports.http=80 \
  --set controller.hostPort.ports.https=443 \
  --set controller.nodeSelector."ingress-ready"=true

echo "Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io >/dev/null
helm repo update >/dev/null
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

echo "Applying certificate issuers..."
kubectl apply -f infra/addons/cert-manager-cluster-issuer.yaml

echo "Waiting for ingress and cert-manager components..."
kubectl wait --for=condition=Available deployment/ingress-nginx-controller -n ingress-nginx --timeout=180s
kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=180s
kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=180s

echo "Cluster bootstrap complete. Use 'kubectl get pods -A' to verify component status."
