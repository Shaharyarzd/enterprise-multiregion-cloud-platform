# Implementation Status

This ledger distinguishes code from runtime proof. Milestone 3 had no AWS deployment. Four later controlled AWS attempts are recorded separately and must not be described as an end-to-end cloud success.

## IMPLEMENTED

- PostgreSQL-backed synthetic patients/appointments model, bounded pool, forced TLS configuration, redacted dependency failures, dependency readiness, migrations, graceful shutdown, and unit tests
- executed local kind/PostgreSQL path with a generated local-only credential, restart persistence, password rotation and cleanup
- RDS-managed Secrets Manager credential, five-minute External Secrets refresh, IRSA restricted to one service account/secret ARN, and rotation-aware mounted-file pool replacement
- security groups for pods so RDS no longer trusts the shared node group
- immutable ECR repository and GitHub OIDC publisher role scoped to the repository main branch
- CI image test, Trivy gate, ECR push, digest capture, and GitOps promotion pull request
- declarative Argo CD bootstrap values/root application and applications for required controllers and CareFlow
- production ALB Ingress with IP targets and dependency health check; HTTP is the executable no-domain default, while optional ACM input enables HTTPS redirect and a TLS 1.2/1.3 policy
- EKS pod-security-group prerequisite through the AWS-managed `AmazonEKSVPCResourceController` cluster-role policy, plus explicit ALB-controller region/VPC values while retaining IMDSv2 and hop-limit hardening
- deterministic controller sync waves and worker/trunk-ENI readiness gates before Argo controller bootstrap
- focused Prometheus scraping and four SLO-oriented alert rules
- ordinary rolling update failure scenario, automated local rollback drill, recovery instructions, and honest pending-evidence template
- default no-op cloud Terraform opt-in and read-only AWS leftover-resource checker
- fail-safe local/cloud preflight, non-applying saved-plan wrapper, account/region-bound typed apply, deliberate destroy, and read-only teardown checks
- redacted machine-readable local evidence contract, including persistence, rotation, continuous traffic, failed rollout and rollback
- no-cost AWS planning mode with an apply-rejected local review plan, masked identity checks, explicit short-lived-role apply guard and expanded teardown inventory

## PARTIALLY IMPLEMENTED

- primary cloud vertical slice: the fourth controlled run created the full reviewed 88-resource stack, an ACTIVE cluster, two Ready private workers and available RDS; runtime stopped before CareFlow on the two preserved blockers. Their narrow repository remediations now pass static/local validation, but remain unproved in AWS until a separately authorized fifth run
- TLS: valid ACM certificate input and ALB configuration exist; trusted public TLS requires control of a real domain for certificate validation and DNS
- observability: metrics/rules/controller state exist; paging receiver and durable long-term retention are execution-environment responsibilities
- DR VPC/EKS: validates and remains disabled; it has no data tier or failover path
- remote state: the protected S3 backend and native locking worked in the sandbox and retained the partial-apply/teardown lifecycle

## DOCUMENTED ONLY

- WAF decision and trigger for reconsideration
- production split between privileged migrator and restricted runtime database principal
- persistent alert receiver and durable audit archive
- warm-standby operating sequence, DNS failover, and cross-region database recovery

## PLANNED

- measured cloud evidence from `docs/cloud-demo-runbook.md`
- cross-region recovery data source and timed DR drill
- signed image/attestation admission policy after the basic digest path is proven

## Evidence status

Unit tests, Docker image build and scan, local PostgreSQL, migrations, restart persistence, local password rotation, metrics, kind deployment, failed-readiness availability and rollback are PASS. AWS infrastructure execution and Ready EKS workers are PASS; the end-to-end runtime remains PARTIAL and Terraform teardown is PASS. Argo bootstrap is PASS with controller reconciliation PARTIAL; GitHub publication, CareFlow/RDS runtime, ALB/TLS, Prometheus rule evaluation and managed-rotation recovery remain PENDING or FAIL as detailed in `docs/aws-runtime-evidence.md`. Configuration is never substituted for runtime proof.

The post-fourth-run remediation has a reviewed fresh remote plan of 89 creates/9 reads with no update, delete or replacement, while bootstrap has no drift. It is **READY WITH BLOCKERS** because GitHub authentication/repository publication setup is not yet verifiable; no fifth workload apply is authorized.

## Portfolio rule

“Implemented” means code and an executable validation path exist. It does not mean the cloud path passed. Only the evidence template/runbook may be updated after real execution, and Secret values must never be captured.
