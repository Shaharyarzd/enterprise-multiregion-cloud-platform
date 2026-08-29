# Implementation Status

This is the authoritative current capability ledger. Historical plans, remediations and safely failed runs remain in their dated documents and in [`aws-runtime-evidence.md`](aws-runtime-evidence.md). Configuration is never substituted for runtime proof.

## Current evidence ledger

| Capability | Status | Evidence / boundary |
|---|---|---|
| Terraform primary infrastructure | PASS | Reviewed 89-create plan applied in the sandbox; VPC, EKS, two workers, RDS, ECR, KMS and scoped IAM/security resources verified |
| Remote backend and native locking | PASS | S3 state remained readable; locking acquired/released; final workload state contains 0 objects |
| GitHub OIDC and ECR publication | PASS | Exact repository/environment trust, STS identity, tests, Trivy gate, immutable push and digest capture executed |
| Digest promotion and Argo delivery | PASS | Digest-only PR squash-merged to `main`; Argo reconciled the promoted digest |
| CareFlow / private RDS path | PASS | External Secret, workload identity, pod SG, migrations, synthetic CRUD and restart persistence executed |
| ALB HTTP path | PASS | Internet → ALB → Service → CareFlow → RDS; two targets healthy and `/readyz` returned 200 |
| Failed rollout / GitOps rollback | PASS | 145/145 requests succeeded during the bad revision; Git revert/merge/Argo restored health in 153 seconds |
| Modern VPC CNI readiness | PASS | VPC CNI v1.23.0, `CNINode/SecurityGroupsForPods`, `ENABLE_POD_ENI=true` and trunk ENIs verified |
| Observability | PARTIAL | Prometheus scraped CareFlow and required metrics/rules worked; one of two pod targets timed out cross-node |
| Argo/controller convergence | PARTIAL | Core applications were Synced/Healthy; Kyverno was healthy/enforcing but retained chart/live-object OutOfSync differences |
| Managed-secret rotation recovery | PENDING | Rotation request was denied before any secret change because deployment-role authorization was absent |
| Trusted public TLS | PENDING | Optional ACM/TLS path exists; no controlled domain/certificate was used for runtime proof |
| Multi-region DR | PENDING | Disabled VPC/EKS scaffold and runbook only; no data path, DNS failover or measured drill |
| Teardown / leftovers | PASS | Controller cleanup, guarded Terraform destroy, remote state 0 and independent inventory passed; no billable workload remains |

## Implemented engineering controls

- PostgreSQL persistence, migrations, bounded pooling, TLS verification, dependency readiness and rotation-aware mounted-secret handling.
- GitHub OIDC instead of static CI keys; immutable ECR and digest-only promotion.
- Argo health/wave ordering, External Secrets, AWS Load Balancer Controller, Kyverno, metrics-server and focused Prometheus.
- Private workers/database, pod-specific RDS network identity, default-deny NetworkPolicy, restricted pod security and hardened IMDSv2.
- Runtime-only AWS identifier injection under ignored `.runtime/`, enforced by staged/tracked-file guards.
- No-op cloud defaults, reviewed-plan-only apply, typed account/region confirmation, deliberate destroy and leftover auditing.

## Design-level or production-only work

- Multi-AZ RDS, per-AZ NAT, longer backup retention/deletion protection and production capacity validation.
- Split privileged migration and restricted runtime database identities.
- Domain-valid TLS, ALB access logs and threat-justified WAF/rate controls.
- Durable monitoring/audit retention and routed alert receivers.
- Cross-region database recovery, DNS failover and measured RTO/RPO/failback.
- Image signing/provenance and admission verification.

## Current scores

| Role | Code/design | Executed evidence |
|---|---:|---:|
| Cloud Architect | 88/100 | 90/100 |
| Senior Cloud Engineer | 90/100 | 94/100 |
| Senior DevOps | 93/100 | 94/100 |

`Cloud Runtime Validation Score: 88/100`

Classification: **READY FOR WIFE REVIEW**.

## Evidence rule

Use only `PASS`, `PARTIAL`, `PENDING` and `FAIL`. Plans, rendering, static checks and local tests cannot become AWS runtime evidence. Secret values and raw Terraform state/plans must never be published.
