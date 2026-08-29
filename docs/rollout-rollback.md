# Controlled Rollout and Rollback Proof

This document defines the local and cloud recovery mechanisms. The final cloud run executed the GitOps variation: the bad revision served 145/145 requests from old replicas, and Git revert/merge/Argo restored the previous digest in 153 seconds. Detailed evidence is in [`aws-runtime-evidence.md`](aws-runtime-evidence.md).

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

Record the last-known-good digest from `main`, merge the equivalent reviewed failure commit through Git, and observe Argo report degraded health. Create and merge a Git revert of that exact failure commit; do not use `kubectl rollout undo` for cloud rollback. Argo must reconcile the reverted `main` commit.

**Executed result:** PASS. The final run followed this sequence; two old replicas remained Ready, ALB traffic had zero failures, the prior digest returned and Argo reported Synced/Healthy.

## Recovery procedure

For the local imperative drill, the script performs `kubectl rollout undo`. For production GitOps, revert the promotion commit or merge a PR that restores the recorded last-known-good digest. Success requires all five signals: the running pod `imageID` contains that exact previous digest; Argo reports `Synced` and `Healthy`; every CareFlow pod is Ready; ALB targets are healthy; and continuous traffic plus `/readyz` and the appointment smoke test recover. A Kubernetes-only rollback does not satisfy the cloud proof.
