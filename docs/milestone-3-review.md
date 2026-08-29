# Milestone 3 Critical Review (Historical Checkpoint)

Review state at Milestone 3: the owner-safe local execution path passed end to end, while cloud runtime was not yet authorized. This document preserves that checkpoint; current results and scores are in [`implementation-status.md`](implementation-status.md) and [`aws-runtime-evidence.md`](aws-runtime-evidence.md).

## Separate scores

| Target role | Code/design | Executed evidence | Critical interpretation |
|---|---:|---:|---|
| Cloud Architect | **87/100** | **42/100** | The architecture and operational boundaries remain coherent, and local failure behavior now supports part of the availability design. No AWS topology, recovery measurement, bill validation or cloud teardown evidence exists, so the evidence increase is deliberately small. |
| Senior Cloud Engineer | **90/100** | **62/100** | Container/database integration, migrations, restart persistence, password rotation, non-root Kubernetes execution and network isolation now have runtime proof. Provider permissions, EKS/RDS/ALB reconciliation, managed rotation and cloud teardown remain unproven. |
| Senior DevOps | **93/100** | **78/100** | The actual image passed its security gate; kind admitted the workload; a broken rollout preserved 124/124 requests; rollback and recovery passed. Argo reconciliation, Prometheus rule/notification behavior, cloud publication and AWS delivery remain unexecuted. |

The evidence scores intentionally give no runtime credit for unexecuted cloud systems. The completed local demonstration raises Senior DevOps most, Senior Cloud Engineer materially, and Cloud Architect only modestly. A short, fully redacted AWS session with same-day teardown is the next legitimate evidence step.

## What improved in this milestone

- `scripts/local-demo.sh` defines one reproducible, secret-safe proof for container tests, runtime image, actual-image Trivy scanning, PostgreSQL migrations/API, persistence across app restart, password rotation and metrics.
- The kind failure drill now generates continuous traffic, requires zero old-replica failures, performs rollback and can emit machine-readable evidence.
- The full local path passed: data survived application and database restarts, local password rotation recovered, and the rollout drill recorded 124 requests with zero failures.
- Execution exposed and fixed Docker context, psycopg parameter, Colima mount, kind naming, PostgreSQL non-root filesystem and NetworkPolicy integration defects without weakening controls.
- Cloud actions are separated into preflight, read-only plan/status, explicitly typed apply, deliberately typed destroy and post-teardown checks.
- The owner runbook now has Gates 0–6, cost exposure before each billable phase, exact stop conditions and an eight-hour/USD 20 first-session limit.
- Runtime claims, public portfolio evidence and subjective engineering review are separated instead of conflated.

## Largest remaining credibility gaps

1. No AWS identity, provider plan/apply, EKS/RDS/ALB path, GitHub OIDC publication, External Secret rotation, Prometheus alert or teardown was observed.
2. Argo CD reconciliation and controller-level observability have only static configuration evidence.
3. The runtime still uses the RDS master principal for migrations and serving; production should split those duties.
4. DR remains a design with no measured RPO/RTO or failover/failback evidence.

## Promotion rule

Do not increase an evidence score from configuration screenshots or successful rendering. Increase it only after the corresponding command, timestamp, version, output, redaction review and teardown status appear in `docs/runtime-evidence.md` or a linked private evidence bundle.
