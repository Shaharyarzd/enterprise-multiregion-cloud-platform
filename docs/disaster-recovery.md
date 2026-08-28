# Disaster Recovery Runbook

## Strategy

Target: active-primary / warm-standby regional recovery.

Current implementation: a disabled-by-default DR network/EKS scaffold. This is closer to a **cold infrastructure seed** than a warm standby because no DR database, application reconciliation bootstrap, ingress, regional image guarantee or DNS failover exists.

### Targets

- RTO target: <= 60 minutes
- RPO target: <= 15 minutes

These are unvalidated objectives for the fictional workload, not measured production claims. The current repository cannot substantiate either target for a regional event.

## Capability ledger

| Recovery capability | Status | Evidence / gap |
|---|---|---|
| Primary RDS automated backups and point-in-time recovery | **IMPLEMENTED** | Production target retains 7 days; Free-plan demo is account-constrained to 1 day; restore has not been exercised |
| Separate DR VPC/EKS Terraform root | **PARTIALLY IMPLEMENTED** | Initializes/validates and is opt-in; no runtime evidence |
| Independent DR Terraform state | **PARTIALLY IMPLEMENTED** | Separate backend example exists; bucket/replication/access are prerequisites |
| Application recovery in DR | **DOCUMENTED ONLY** | No controller bootstrap or deployable regional image reference |
| Cross-region database recovery | **PLANNED** | No replica, automated-backup replication, snapshot copy or restore code |
| Route 53 health checks/failover | **PLANNED** | No DNS resources exist |
| Backup restore validation | **PLANNED** | No automated test or drill evidence exists |
| RTO <= 60 minutes / RPO <= 15 minutes | **DOCUMENTED ONLY** | Targets are neither instrumented nor measured |

## Preconditions

- DR Terraform can initialize and validate; an authenticated cloud plan must still be captured.
- Container images are available outside the failed region or reproducible.
- GitOps desired state is region-independent where possible.
- A cross-region database recovery source is available and has passed a restore test.
- DNS access is independent of the failed application region.

## Failover procedure

1. Declare the primary region unavailable using explicit incident criteria.
2. Freeze non-essential infrastructure changes.
3. Confirm the latest recoverable database point and record expected data loss window.
4. Provision/scale the DR regional cell.
5. Restore/promote the data tier.
6. Reconcile application state through GitOps.
7. Run `/healthz`, `/readyz`, synthetic API and data-integrity checks.
8. Shift DNS to DR.
9. Observe error rate, latency, saturation and application correctness.
10. Communicate RTO/RPO achieved versus targets.

## Missing implementation decisions

Before calling this warm standby, select and implement a data mechanism. For this workload, evaluate cross-region automated-backup replication versus a cross-region read replica; document cost, achievable RPO, promotion behavior, KMS/key policy and restore testing. Also bootstrap GitOps/controllers in DR, replicate or make images globally available, create health-checked DNS failover, and test that Terraform state remains accessible during a primary-region outage.

## Failback

Failback is a separate controlled change. Do not automatically redirect traffic merely because the original region becomes reachable.

1. Rebuild/validate primary.
2. Re-establish data synchronization.
3. Verify application version parity.
4. Schedule traffic return.
5. Shift gradually where supported.
6. Keep DR available until post-change validation is complete.

## Drill evidence to capture

- start/end timestamps
- recovery point selected
- infrastructure convergence time
- data restore time
- workload readiness time
- DNS change time
- observed RTO/RPO
- issues and remediation actions
