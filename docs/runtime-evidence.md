# Runtime Evidence

Local evidence date: 2026-08-26. A separately authorized AWS attempt ran on 2026-08-27 and is recorded in [`aws-runtime-evidence.md`](aws-runtime-evidence.md). `PASS` means the stated command or path genuinely ran. `PENDING` means it was not exercised. `PARTIAL` and `FAIL` are retained rather than converted into inferred success.

Successful local run: `20260826T143135Z-90098`, completed at `2026-08-26T14:34:25Z`. Its private, ignored evidence bundle is `artifacts/runtime-evidence/local-20260826T143135Z-90098/`.

Runtime toolchain: Python 3.9.6, curl 8.7.1, ripgrep 15.2.0, Docker client 29.7.2/server 29.5.2 through Colima 0.10.3, OpenSSL 3.6.3, Trivy 0.74.0, kind 0.32.0, kubectl 1.36.4/Kustomize 5.8.1 and kubeconform 0.8.0. actionlint 1.7.12 was also used for workflow validation.

## Final AWS validation update

The final authorized AWS validation completed the core cloud path and mandatory teardown. Exact Terraform execution was **89 added, 0 changed, 0 destroyed** from a reviewed 89-create/9-read plan. GitHub OIDC published an immutable digest to ECR and the digest-only promotion PR was squash-merged. Argo deployed two Ready CareFlow replicas; External Secrets, workload identity, pod security groups, migrations, private RDS connectivity, ALB HTTP routing and synthetic data persistence all passed.

The cloud failed-rollout drill served **145 requests with 0 failures over 222 seconds** while two old replicas stayed Ready. A Git revert merged to `main` and Argo restored the previous digest and full traffic/data health in **153 seconds**. Prometheus and the required application metrics/rules worked, but only one of two CareFlow scrape targets was reachable; observability is therefore **PARTIAL**. RDS managed-secret rotation recovery is **PENDING** because AWS rejected the rotation request before changing credentials. Trusted TLS remains **PENDING**.

Guarded teardown and the independent AWS inventory passed. Remote workload state contains zero objects, no native lock remains and no billable CareFlow workload remains. Six historical workload KMS keys are disabled in `PendingDeletion`; the intentional bootstrap layer and EKS node-group service-linked role may remain. Full details and historical attempt preservation are in [`aws-runtime-evidence.md`](aws-runtime-evidence.md).

`Cloud Runtime Validation Score: 88/100`

Portfolio readiness: **READY FOR WIFE REVIEW**.

## Historical Milestone 3 evidence matrix

| Evidence area | Status | Executed proof or reason |
|---|---|---|
| Unit tests | PASS | Host and Docker test target both passed all 13 tests |
| Image build | PASS | Docker test and runtime targets built successfully from the repository Dockerfile |
| Actual image scan | PASS | Trivy scanned the built runtime image for HIGH/CRITICAL vulnerabilities and secrets; zero findings |
| Local PostgreSQL | PASS | PostgreSQL 17.6 started, migrations ran, the API returned synthetic data, and data survived both application and database restarts |
| Kubernetes | PASS | A disposable kind cluster admitted and ran the local overlay: PostgreSQL 1/1 and CareFlow 2/2 Ready |
| Rollout failure | PASS | A deliberately readiness-broken revision stayed unready while the prior replicas continued serving |
| Rollback | PASS | `kubectl rollout undo` recovered the Deployment; post-rollback health and data smoke tests passed |
| Local observability | PASS | The live `/metrics` endpoint reported `careflow_database_dependency_healthy 1` |
| Prometheus/controller observability | PARTIAL cloud / PASS local metric | Final cloud run proved Prometheus metrics/rules; one of two cross-node targets timed out |
| AWS | PASS | Final controlled run created the reviewed 89-resource stack and proved the core application/data/edge path |
| ALB/TLS | PASS HTTP / PENDING trusted TLS | Two ALB targets and HTTP path passed; no controlled domain/validated ACM certificate was used |
| RDS | PASS application / PENDING rotation recovery | Private encrypted RDS, migrations, CRUD and restart persistence passed; managed rotation recovery did not execute |
| Rotation | PASS local / PENDING AWS recovery | Local pool replacement passed; AWS rotation was denied before changing credentials |
| Teardown | PASS | Remote workload state is 0 and the independent inventory is empty apart from expected KMS keys in `PendingDeletion` |

## Executed local proof

`bash scripts/local-demo.sh` genuinely executed the following sequence:

1. Built the Dockerfile test target and ran all 13 tests inside it.
2. Built the runtime image and scanned that exact image with Trivy.
3. Started isolated PostgreSQL with a generated local-only credential and named volume.
4. Triggered migrations through application readiness and validated synthetic API data.
5. Added a third synthetic appointment and verified it after an application restart and a PostgreSQL restart.
6. Rotated the PostgreSQL role password, updated the mounted secret file and observed readiness/pool recovery without changing source code.
7. Verified the live dependency metric.
8. Created a disposable kind cluster, deployed PostgreSQL and two CareFlow replicas, and confirmed they became Ready.
9. Sent continuous requests while applying a deliberately broken-readiness revision. The broken pod remained `0/1`; the two old replicas remained Ready and served 124 requests with zero failures.
10. Rolled back, waited for readiness and passed health/data smoke tests again.

The machine-readable `summary.json` marks every local check `PASS`. `kind/rollout-summary.json` records `forced_readiness_failure_rejected: true`, 124 old-replica requests, zero failures and rollback `PASS`.

## Repository fixes required by execution

The failures were not skipped or masked. They exposed the following repository issues, which were corrected before the complete rerun:

- `apps/careflow-api/.dockerignore`: allowed the Docker test stage to receive the test suite.
- `.gitignore` and `scripts/local-demo.sh`: staged disposable secret files under ignored `.runtime/`, which is mountable by Colima, normalized generated kind names to lowercase and bounded URL checks with a two-second timeout.
- `apps/careflow-api/persistence.py`: translated the application secret field `username` to psycopg/libpq's `user` keyword.
- `apps/careflow-api/tests/test_persistence.py`: added regression coverage for that secret-to-driver mapping.
- `k8s/overlays/local/postgres.yaml`: ran the pinned PostgreSQL image explicitly as its real non-root UID/GID 70 and used a writable `PGDATA` child directory without adding a privileged init container.
- `k8s/base/networkpolicy.yaml`: added the missing reciprocal PostgreSQL ingress allowance from CareFlow pods on TCP 5432 while retaining default-deny isolation.
- This document, `docs/implementation-status.md`, `docs/milestone-3-review.md` and `README.md`: replaced obsolete local-runtime pending claims with executed results.

No security context, severity gate, readiness condition, test or secret-handling control was weakened.

## Evidence integrity and cleanup

All files under `artifacts/runtime-evidence/` were inspected by filename and content patterns. No database password, token, AWS credential, private key, personal path or unrelated personal information was found. A high-entropy scan match in image-build logs was the public SHA-256 checksum for the AWS RDS CA bundle, not a secret. Evidence contains only synthetic patient/appointment identifiers.

Raw evidence remains private because `artifacts/` is ignored. Generated credentials lived only under ignored `.runtime/`, were never copied to evidence and were deleted by the exit trap. After the successful run, no kind cluster, CareFlow container, named CareFlow volume, run-specific CareFlow network or generated CareFlow image remained.

## Additional validation

| Check | Status | Result |
|---|---|---|
| Local preflight | PASS | Every required and optional local tool passed; the Docker daemon was reachable |
| Unit tests | PASS | 13/13 on the host and 13/13 in the Docker test target |
| Kubernetes rendering/schemas | PASS | local 12/12 valid; failure 12/12 valid; production 11 native valid/5 CRDs skipped; platform 6 CRDs skipped |
| GitHub Actions lint | PASS | all workflows passed actionlint 1.7.12 |
| Shell syntax | PASS | every shell script under `scripts` and `platform` passed `bash -n` |
| Repository invariants | PASS | `python3 scripts/verify.py` |
| Trivy repository scan | PASS | dependency, secret and misconfiguration scan had zero HIGH/CRITICAL findings with generated `.terraform` trees excluded |
| Terraform offline validation | PASS | primary and DR roots had previously initialized with backend disabled and validated; this remains static evidence, not an AWS plan/apply claim |

## Historical cloud gaps after the fourth run

At the fourth-run checkpoint, GitHub publication, CareFlow-on-EKS, RDS application connectivity/rotation recovery, ALB/TLS, Prometheus rules, cloud rollback and DR timing were pending. The final run subsequently proved every listed core path except managed-rotation recovery, trusted TLS, complete two-target Prometheus scraping and DR. This paragraph is retained to preserve checkpoint history rather than describe current status.

Post-fourth-run remediation adds the exact AWS-managed EKS VPC resource-controller policy, explicit ALB-controller `us-east-1`/VPC configuration, controller ordering, node/trunk readiness gates, and an executable HTTP-only no-domain ingress path. Repository invariants, Terraform validation, chart/Kustomize rendering, schema checks and workflow lint pass. These are readiness controls only; the two runtime blockers remain historical FAIL evidence until a new explicitly authorized AWS validation proves them.

The fresh remediation plan at that checkpoint passed at 89 creates/9 reads/0 updates/0 deletes/0 replacements. It was later replaced by a completely fresh, reviewed final plan and applied during the separately authorized run recorded in [`aws-runtime-evidence.md`](aws-runtime-evidence.md).

## Machine-readable evidence contract

`scripts/local-demo.sh` writes redacted logs plus `summary.json` under ignored `artifacts/runtime-evidence/local-<UTC-run-id>/`. When kind is available, `rollout-summary.json` includes continuous request and failure counts. A failed run remains failed/incomplete; evidence JSON must never be hand-edited to claim success.
