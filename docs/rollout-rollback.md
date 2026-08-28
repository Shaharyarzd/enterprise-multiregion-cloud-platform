# Controlled Rollout and Rollback Proof

This drill proves an ordinary Kubernetes rolling update before adding a progressive-delivery controller. It uses the same image with `APP_VERSION=0.2.0-readiness-failure` and `FORCE_READINESS_FAILURE=true` as the controlled v2 failure. No screenshot or runtime result is claimed here.

## Local test

Prerequisites: Docker, kind, kubectl, curl, and OpenSSL.

```bash
make local-up
bash scripts/rollout-failure-demo.sh
```

Expected sequence:

1. v1 reports a successful rollout and serves a PostgreSQL-backed appointment response.
2. v2 pods start but return HTTP 503 from `/readyz`.
3. `kubectl rollout status` times out as expected.
4. Because `maxUnavailable: 0`, ready v1 pods remain behind the Service while the unready v2 pod receives no traffic.
5. The smoke test still passes through v1.
6. `kubectl rollout undo` restores the previous pod template and the final smoke test passes.

If v1 is unavailable, stop: the result does not prove safe rollout behavior. If v2 becomes ready, the failure injection is broken and the script exits non-zero. Do not use `kubectl delete` as the recovery demonstration.

## Cloud/GitOps variation

Pause automated sync only for the bounded drill, apply an equivalent reviewed failure commit through Git, observe Argo report degraded health, then revert that Git commit. Argo must reconcile the revert. Do not use CI or an operator shell to make an undocumented permanent production change.

## Recovery procedure

For the local imperative drill, the script performs `kubectl rollout undo`. For production GitOps, revert the promotion commit or merge a PR that restores the last known-good digest. Confirm Deployment availability, Argo `Synced/Healthy`, ALB target health, `/readyz`, and the appointment smoke test.
