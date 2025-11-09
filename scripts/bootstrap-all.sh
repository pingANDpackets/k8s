#!/usr/bin/env bash
set -euo pipefail

echo "[1/5] Setting up kind cluster and dependencies..."
./scripts/setup-kind.sh

echo "[2/5] Building/pushing tenant images..."
./scripts/build-images.sh

echo "[3/5] Deploying tenant namespaces..."
./scripts/deploy-tenants.sh

echo "[4/5] Installing observability stack..."
./scripts/install-observability.sh

echo "[5/5] Starting Kafka stack..."
./scripts/start-kafka.sh

echo "All components are up. Validate with:"
echo "  kubectl get pods -A"
echo "  curl -sk https://user1.127.0.0.1.sslip.io"
