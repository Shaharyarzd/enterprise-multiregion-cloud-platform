# CareFlow Operations and SLOs

## Service objectives

The demo measures only the implemented HTTP and PostgreSQL path. The proposed 30-day objectives are 99.5% successful request availability and p95 application latency below 500 ms. These are portfolio objectives, not measured production claims. Database readiness is critical because appointments cannot be served meaningfully without PostgreSQL.

An incident begins when any critical alert fires, or when the 5xx ratio remains above 5% for ten minutes. A warning requires investigation during the demo window; a critical alert requires stopping promotion and beginning recovery. Alert routing to a real person is deliberately a cloud-demo configuration because the repository cannot safely contain contact details.

## Availability incident

1. Check the Argo CD application health and current image digest.
2. Check `kubectl -n careflow get pods,deploy,ingress` and pod events.
3. Confirm whether `/healthz`, `/readyz`, and `/metrics` fail independently.
4. If the latest rollout caused the incident, follow `docs/rollout-rollback.md`.
5. Record timestamps, digest, symptoms, command output, and recovery time.

## Database dependency incident

1. Stop image and schema promotions.
2. Check the `ExternalSecret` Ready condition; never print the generated Secret.
3. Confirm the RDS instance status, RDS events, security group IDs, and PostgreSQL log export.
4. Confirm the pod security group, DNS resolution, and TLS hostname match.
5. If rotation occurred, allow at least one External Secrets refresh interval and then recheck readiness. The application detects the updated mounted JSON and replaces its pool.
6. Escalate to restore/failover only after identifying an RDS service or data failure.

## HTTP error incident

Compare the error ratio by path and status, inspect structured pod logs, and test `/readyz`. A database-related 503 is a dependency incident; a new application 5xx after promotion is a rollback candidate.

## Latency incident

Compare request latency with database health and pool saturation. Check CPU/memory throttling and RDS connections before scaling replicas: more pods also create more database connections. The configured maximum is five database connections per pod.

## Evidence integrity

Do not fabricate screenshots or success output. Store only redacted command output. Never capture Secret values, AWS tokens, database connection strings, or Argo CD passwords.
