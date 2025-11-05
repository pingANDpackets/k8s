#!/usr/bin/env bash
set -euo pipefail

REGISTRY="localhost:5001"

images=(
  "tenant-node-site|apps/node-site"
  "tenant-flask-site|apps/flask-site"
)

for entry in "${images[@]}"; do
  IFS='|' read -r name context <<<"${entry}"
  tag="${REGISTRY}/${name}:latest"
  echo "Building ${tag} from ${context}..."
  docker build -t "${tag}" "${context}"
  alt_tag="host.docker.internal:5001/${name}:latest"
  echo "Tagging ${tag} as ${alt_tag} for engine access..."
  docker tag "${tag}" "${alt_tag}"
  echo "Pushing ${alt_tag}..."
  docker push "${alt_tag}"
done

echo "Images built and pushed to ${REGISTRY}."
