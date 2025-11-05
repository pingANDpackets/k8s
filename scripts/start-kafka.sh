#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="infra/kafka/docker-compose.yaml"

command -v docker-compose >/dev/null 2>&1 || {
  if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
  else
    echo "WARNING: docker compose plugin or docker-compose is required." >&2
    exit 1
  fi
}

if command -v docker-compose >/dev/null 2>&1; then
  docker-compose -f "${COMPOSE_FILE}" up -d
else
  docker compose -f "${COMPOSE_FILE}" up -d
fi

echo "Kafka is starting on localhost:9092."
