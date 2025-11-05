#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="infra/kafka/docker-compose.yaml"

if command -v docker-compose >/dev/null 2>&1; then
  docker-compose -f "${COMPOSE_FILE}" down
elif docker compose version >/dev/null 2>&1; then
  docker compose -f "${COMPOSE_FILE}" down
else
  echo "WARNING: docker compose plugin or docker-compose is required." >&2
  exit 1
fi

echo "Kafka stack stopped."
