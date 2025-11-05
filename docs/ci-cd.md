# CI/CD Runbook

## Workflow Entry Points

- Automatic: push to `main` or `staging` branch.
- Manual: `workflow_dispatch` (run from GitHub UI or locally using `act`).

## Pre-Requisites (local `act` run)

- Kind cluster bootstrapped (`make setup-kind`).
- Images registry reachable at `localhost:5001`.
- Kafka broker running (`make kafka-up`).
- Kubeconfig mounted into the `act` runner container (read-only is sufficient).
- `sslip.io` hostnames resolve back to the workstation (automatic when using `--network host`).

Example invocation (pushes via `host.docker.internal:5001` while Helm continues to deploy from `localhost:5001`):

```bash
act workflow_dispatch -W .github/workflows/ci-cd.yaml \
  -P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest \
  --container-options "--network host -v $HOME/.kube:/home/runner/.kube:ro" \
  --container-architecture linux/amd64 \
  --env REGISTRY=localhost:5001 \
  --env PUSH_REGISTRY=host.docker.internal:5001 \
  --env IMAGE_TAG=$(git rev-parse HEAD)
```

## Job Breakdown

1. **build**
  - Builds Node.js and Flask images.
  - Pushes both to `host.docker.internal:5001` (the runner-visible alias for the local registry) using the Git SHA as the tag while keeping `localhost:5001` tagged for Kubernetes pulls.
2. **deploy** (matrix per tenant)
   - Installs kubectl + Helm.
   - `helm upgrade --install` for the tenant namespace.
   - Waits for rollout; on failure, triggers `kubectl rollout undo` then fails fast.
   - Smoke tests HTTPS endpoint with retries.
   - Installs `kafka-python` and publishes a `WebsiteCreated` event describing the deployment.
   - Emits `kubectl get all` for auditing.

## Observing Rollbacks

- Force a failure by pushing an invalid image tag (e.g., edit `tenants/user1.values.yaml` to point to a non-existent tag, run `act`).
- The pipeline will detect the rollout failure, undo it, and surface a non-zero exit so the job fails visibly.

## Logs & Evidence

- Build job logs show Docker build and push outputs.
- Deploy job logs include `kubectl get all` snapshots per namespace.
- Kafka event step prints the partition/offset of the published message.
- Autoscaling evidence (see `docs/scaling-notes.md`) captures the HPA scaling story referenced in the pipeline deliverables.
