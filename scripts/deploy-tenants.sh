#!/usr/bin/env bash
set -euo pipefail

command -v helm >/dev/null 2>&1 || {
  echo "WARNING: helm is required. Install from https://helm.sh/docs/intro/install/." >&2
  exit 1
}
command -v kubectl >/dev/null 2>&1 || {
  echo "WARNING: kubectl is required. Install from https://kubernetes.io/docs/tasks/tools/." >&2
  exit 1
}

TENANTS=("user1" "user2" "user3")

for tenant in "${TENANTS[@]}"; do
  values_file="tenants/${tenant}.values.yaml"
  if [ ! -f "${values_file}" ]; then
    echo "ERROR: Values file ${values_file} not found." >&2
    exit 1
  fi

  echo "Deploying tenant ${tenant}..."
  helm upgrade --install "${tenant}" charts/tenant-site \
    --namespace "${tenant}" \
    --create-namespace \
    -f "${values_file}"

  echo "Waiting for deployment to become ready..."
  kubectl rollout status deployment/"${tenant}"-tenant-site -n "${tenant}" --timeout=120s
  echo "Namespace ${tenant} status:"
  kubectl get all -n "${tenant}"
done

echo "Tenants deployed. Validate ingress with:"
echo "   curl -k https://user1.127.0.0.1.sslip.io"
