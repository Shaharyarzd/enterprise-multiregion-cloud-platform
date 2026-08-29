# Principal Architecture and DevOps Review

Review updated after the final controlled AWS validation. Historical plan and failed-run evidence remains in [`aws-runtime-evidence.md`](aws-runtime-evidence.md); the current capability ledger is [`implementation-status.md`](implementation-status.md).

## Executive assessment

This is a credible senior-level portfolio reference platform with a genuinely executed primary-region vertical slice. It demonstrates architecture judgment, secure delivery, operational recovery and lifecycle ownership—not merely a list of cloud products. It is **not** a production-ready regulated platform: the validated demo intentionally trades availability and retention for cost, and several production controls remain design-level.

| Role | Code/design | Executed evidence | Assessment |
|---|---:|---:|---|
| Cloud Architect | 88/100 | 90/100 | Strong boundaries, threat/cost trade-offs and executed primary topology; multi-region recovery remains unproved |
| Senior Cloud Engineer | 90/100 | 94/100 | Full AWS/Kubernetes/data/edge path and teardown executed; observability and rotation have bounded gaps |
| Senior DevOps | 93/100 | 94/100 | Keyless immutable delivery and GitOps failure recovery executed; Kyverno convergence is not perfectly clean |

`Cloud Runtime Validation Score: 88/100`

## Strongest engineering evidence

1. A reviewed **89-create** Terraform plan produced the expected VPC/EKS/RDS/ECR topology and returned to zero state after guarded teardown.
2. GitHub Actions used exact-subject OIDC to test, scan and publish an immutable digest; no static AWS key was required.
3. Runtime AWS identifiers were injected through an ignored patch layer while portable Git desired state remained public-safe.
4. Modern VPC CNI readiness and pod branch ENIs narrowed RDS access to the CareFlow workload identity.
5. The PostgreSQL path passed migrations, synthetic CRUD and persistence after pod restart through the ALB.
6. A bad GitOps revision served **145/145 successful requests** from old replicas; Git revert and Argo restored the prior digest in **153 seconds**.
7. Runtime IAM failures drove narrow policy changes; broad administrator-style permissions were rejected.
8. The environment was completely torn down and independently audited rather than left running as a portfolio endpoint.

## Architecture assessment

| Area | Executed strength | Residual production concern |
|---|---|---|
| Network/EKS | Three-AZ subnet design, private workers, hardened IMDS, scoped API `/32`, two-AZ scheduling | Demo has one NAT, two workers and no autoscaler; it does not prove production HA/capacity |
| Data | Private encrypted RDS, verified TLS, managed secret, External Secrets, pod SG, migrations and persistence | Demo is Single-AZ and uses the managed master identity; production should split migrator/runtime roles |
| Delivery | OIDC, tests, Trivy, immutable ECR, digest PR and Argo reconciliation | Signing/provenance and verified admission remain planned |
| Policy | Kyverno blocked non-digest deployment as intended | Healthy enforcement coexisted with Argo OutOfSync chart/live-object differences |
| Edge | ALB IP targets and two healthy `/readyz` targets proved the HTTP path | Trusted TLS, access logs and WAF/rate controls require production context |
| Observability | Prometheus metrics and rules executed | One cross-node scrape failed; retention and receivers are demo-grade |
| Recovery | Failed rollout and GitOps rollback measured with zero request failures | Region/AZ data recovery and RTO/RPO remain design targets |
| Operations | MFA/STS, remote locking, cost ceiling and complete teardown proved | Persistent environments need stronger audit, patching and access-review operations |

## Remaining priorities

1. Correct the cross-node Prometheus-to-pod security-group path and prove both targets.
2. Resolve Kyverno chart/hook/live-mutation drift without weakening enforcement.
3. Add narrowly reviewed rotation authorization and execute managed-secret refresh/pool recovery.
4. For a persistent production deployment, add domain-valid TLS, edge logging and threat-justified WAF/rate limiting.
5. Split database migration/runtime privileges and implement durable observability/audit retention.
6. Build and measure the cross-region data/DNS recovery path before claiming RTO/RPO.

## Honest classification

**READY FOR WIFE REVIEW.** The core portfolio story is supported by executed evidence. It should not be presented as automatically compliant, production HA, trusted-TLS-complete, rotation-proven or multi-region-validated.
