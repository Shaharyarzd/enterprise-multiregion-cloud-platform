# Milestone 2 Critical Review

Review state: implementation complete, offline validation complete, cloud/runtime execution pending.

## Score

| Portfolio dimension | Milestone 1 | Milestone 2 | Critical rationale |
|---|---:|---:|---|
| Overall architecture | 68/100 | **82/100** | One coherent primary-region slice now connects artifact, identity, traffic, application, data, monitoring, and recovery; regional DR and runtime evidence remain incomplete |
| Cloud Architect portfolio | 74/100 | **84/100** | Implemented/target diagrams, explicit decisions, pod-level blast radius, TLS/domain honesty, WAF restraint, and cost opt-in are strong; data-principal separation and measured recovery remain gaps |
| Senior Cloud Engineer portfolio | 73/100 | **85/100** | Valid Terraform now covers workload/controller IAM, immutable ECR, security groups for pods, and safe outputs/runbooks; there is no authenticated plan/apply or live AWS evidence |
| Senior DevOps portfolio | 79/100 | **88/100** | Tests, exact-image scanning/publication, digest promotion PR, Argo bootstrap, dependency ordering, SLO alerts, and rollback drill form a credible delivery system; its runtime behavior is still unproven |

These scores do not treat declarative configuration as cloud evidence. A clean sandbox execution, real image digest, Argo reconciliation export, TLS request, rotation test, alert result, and timed rollback could raise the portfolio; failed or undocumented execution should lower it.

## What now genuinely works without AWS

- Twelve persistence/API unit tests pass, including migration execution, secret change detection, pool replacement, dependency readiness, redacted failures, and controlled readiness failure.
- Terraform 1.15.9 initializes with the committed provider locks and validates both roots without an AWS account or backend.
- Local, production, GitOps platform, and failure-scenario Kustomize builds render successfully.
- All native local/failure resources pass strict Kubernetes 1.36 schemas; all native production resources pass, while five controller CRs are explicitly skipped because their CRD schemas are not vendored. Six Argo CRs are likewise rendered/parsed with CRD schema validation pending controller installation.
- actionlint, shell syntax, repository invariants, and Trivy dependency/secret/IaC/Kubernetes misconfiguration scans pass.
- The digest updater rejects malformed ECR URLs/digests and produced the expected production manifest update in a temporary-file test.

## Status by evidence level

### IMPLEMENTED

- PostgreSQL application contract, migrations, connection pool, TLS verification input, readiness/liveness behavior, metrics, tests, and hardened image definition
- Secrets Manager/IRSA/External Secrets delivery and rotation-aware file contract
- pod-specific RDS network identity
- immutable ECR and repository/branch-scoped GitHub OIDC role
- exact-image test/scan/push and digest-only GitOps promotion PR workflow
- Argo CD bootstrap and required dependency applications
- ALB/TLS Ingress and focused Prometheus monitor/rules
- rollback scenario, cost opt-in, teardown checker, and non-technical runbook

### PARTIALLY IMPLEMENTED

- end-to-end primary AWS path: complete in code, unexecuted in cloud
- local PostgreSQL/kind path: executable, unexecuted here because Docker/kind are unavailable
- controller custom resources: render successfully; live CRD admission/reconciliation is pending
- TLS: the interface is complete; trusted public verification needs a domain the owner already controls

### DOCUMENTED ONLY

- WAF reconsideration criteria
- split migration/runtime database principals
- durable audit/metrics retention and a real paging receiver

### PLANNED

- cross-region database recovery, DNS failover, measured DR, signing/attestation admission, and central audit archive

## Validation record

Passed:

- `terraform fmt -check -recursive infra`
- `terraform init -backend=false -input=false -lockfile=readonly` for primary and DR
- `terraform validate` for primary and DR
- `python3 -m unittest discover -s apps/careflow-api/tests -p 'test_*.py'` — 12 tests
- `kubectl kustomize` for local, production, platform, and readiness-failure manifests
- kubeconform 0.8.0 strict Kubernetes 1.36 validation for native resources; missing CRD schemas explicitly skipped
- actionlint 1.7.12 for every workflow
- `make check-shell`
- `python3 scripts/verify.py`
- Trivy 0.74.0 filesystem scan with vulnerability, secret, and misconfiguration scanners at high/critical severity; cached `.terraform` modules excluded
- temporary-file test of `scripts/update-image-digest.py`

Pending, not claimed:

- Docker runtime/test-target build and image vulnerability scan
- kind PostgreSQL smoke test and rollback drill
- Helm/Argo controller bootstrap
- GitHub OIDC/ECR publication and promotion PR
- AWS Terraform plan/apply, External Secrets sync/rotation, pod security group behavior, ALB/ACM traffic, Prometheus alert delivery, and destroy verification

No AWS credentials were available and no billable AWS resource was created.

## Residual concerns before presentation

1. The application uses the rotating RDS master principal so the same identity can migrate and serve. This is intentionally small but too privileged for persistent production; a migration Job and restricted application user are the clearest next hardening step.
2. Runtime evidence is the largest credibility gap. Do not add another platform product before executing the existing runbook.
3. Prometheus storage is ephemeral and alert routing is deliberately unset. That is appropriate for a short demo, not for production operations.
4. The ALB controller IAM policy is based on the official v3.5.0 policy with optional WAF/Shield/Cognito permissions removed; it should be re-reviewed when the controller version changes.
5. The supplied directory is not a Git worktree, so branch protection, workflow permissions, GitOps PR creation, and a normal file diff cannot be tested locally.
