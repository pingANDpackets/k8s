#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <tenant-host>" >&2
  echo "Example: $0 user1.127.0.0.1.sslip.io" >&2
  exit 1
fi

HOST="$1"
DURATION="60s"
CONCURRENCY=${CONCURRENCY:-20}

echo "Generating load against https://${HOST} for ${DURATION} with concurrency ${CONCURRENCY}..."
docker run --rm --network host williamyeh/hey:latest -z ${DURATION} -c ${CONCURRENCY} -disable-compression https://${HOST}/ || {
  echo "WARNING: Ensure Docker is running and the host is reachable." >&2
  exit 1
}

echo "Load generation completed. Inspect HPA with 'kubectl get hpa -A'."
