# Architecture

The diagrams separate the executed primary-region slice from the stronger production target. “Implemented” describes repository capability; runtime claims are made only where the final controlled validation produced evidence. Earlier safely failed attempts remain historical in [`aws-runtime-evidence.md`](aws-runtime-evidence.md).

## Explicit execution profiles

The same Terraform modules support two guarded profiles; they are not separate architectures.

| Setting | Production target | Free-plan demo |
|---|---|---|
| Purpose | Regulated-workload design target | Time-boxed sandbox validation only |
| Workers | Three desired `t3.medium` workers, min 2/max 6 | Two `c7i-flex.large` workers, min/desired 2 |
| Standard VPC-CNI capacity | 17 pods/node; production sizing must be load-tested | 29 pods/node; 58 total slots before system pods |
| RDS | Multi-AZ, at least 7-day backup retention, deletion protection, final snapshot | Single-AZ, 1-day retention, teardown-oriented controls |
| NAT | One per AZ | One shared NAT gateway |

`c7i-flex.large` is x86_64 and Free-plan eligible in this account. Two `t3.small` nodes were rejected during design review despite their lower price: each offers only 11 standard VPC-CNI pod slots and roughly 1.5 GiB allocatable memory, while the required system, GitOps, security, observability and two application replicas need about 28 steady-state pods. Two `c7i-flex.large` nodes provide roughly 3.34 GiB and 1.93 vCPU allocatable each, enough pod density and useful headroom without changing the application path. The one-day RDS retention is an AWS Free-plan execution constraint and is **not** the recommended production retention.

## Validated primary-region architecture

```mermaid
flowchart TB
    USER["Internet user"]
    GHA["GitHub Actions<br/>OIDC; no static AWS keys"]
    MAIN["main<br/>promoted digest"]

    subgraph AWS["Validated AWS primary region"]
        ECR["Immutable ECR digest"]
        SM["RDS-managed secret<br/>rotation recovery PENDING"]
        EKSCP["EKS control plane<br/>ACTIVE"]

        subgraph VPC["CareFlow VPC"]
            subgraph PUB["Public subnets"]
                ALB["ALB<br/>HTTP listener"]
            end

            subgraph APPNET["Private application subnets"]
                subgraph AZA["AZ A"]
                    NODE1["Private worker 1"]
                    APP1["CareFlow replica 1"]
                    NODE1 --> APP1
                end
                subgraph AZB["AZ B"]
                    NODE2["Private worker 2"]
                    APP2["CareFlow replica 2"]
                    NODE2 --> APP2
                end

                PLATFORM["Argo CD + controllers"]
                SVC["Kubernetes Service"]
                KYV["Kyverno<br/>enforced; Argo sync PARTIAL"]
                ESO["External Secrets"]
                PROM["Prometheus<br/>one target PARTIAL"]
                SGP["Security Groups for Pods<br/>branch ENIs"]
            end

            subgraph DBNET["Private database subnets"]
                RDS[("Encrypted Single-AZ RDS<br/>PostgreSQL")]
            end

            ALB -->|"Ingress backend"| SVC
            SVC -. "IP target; /readyz" .-> APP1
            SVC -. "IP target; /readyz" .-> APP2
            SGP --> APP1
            SGP --> APP2
            APP1 -->|"TLS / TCP 5432"| RDS
            APP2 -->|"TLS / TCP 5432"| RDS
        end

        EKSCP --> NODE1
        EKSCP --> NODE2
        ESO -->|"IRSA read; one secret"| SM
        ESO -->|"mounted JSON"| APP1
        ESO -->|"mounted JSON"| APP2
        KYV -. "digest admission" .-> APP1
        KYV -. "digest admission" .-> APP2
        APP1 -. "metrics" .-> PROM
        APP2 -. "metrics" .-> PROM
        ECR -. "digest-pinned pull" .-> APP1
        ECR -. "digest-pinned pull" .-> APP2
    end

    USER --> ALB
    GHA --> ECR
    GHA --> MAIN
    MAIN --> PLATFORM
```

The implemented AWS path is a primary-region, synthetic-data portfolio slice. The final run proved GitHub OIDC publication, immutable digest promotion, Argo reconciliation, two Ready CareFlow replicas, private RDS CRUD/restart persistence and two healthy ALB targets over HTTP. ECR uses immutable tags, the Kubernetes overlay pins a digest, and CI opens a pull request rather than changing the cluster. The default Terraform apply is a no-op until `enable_cloud_resources=true` is deliberately selected.

## Validated CI/CD and GitOps flow

```mermaid
flowchart LR
    PUSH["Git push"] --> ACTIONS["GitHub Actions"]

    subgraph CI["Build and security"]
        ACTIONS --> TESTS["Unit + container tests"]
        TESTS --> TRIVY["Trivy HIGH/CRITICAL gate"]
        TRIVY --> OIDC["GitHub OIDC<br/>no static AWS credentials"]
    end

    subgraph AWS["AWS publication"]
        OIDC --> ECR["Immutable ECR digest"]
    end

    subgraph GIT["Public Git ownership"]
        ECR --> PR["Digest-only PR"]
        PR --> MERGE["Squash merge to main"]
        MERGE --> DESIRED["Generic manifests<br/>+ promoted digest"]
    end

    subgraph RUNTIME["Ignored local runtime ownership"]
        VALUES[".runtime patches<br/>VPC, secret, roles, ECR URL"]
    end

    subgraph CLUSTER["Kubernetes reconciliation"]
        DESIRED --> ARGO["Argo CD"]
        VALUES --> ARGO
        ARGO --> KYV["Kyverno digest enforcement"]
        KYV --> CARE["CareFlow on EKS"]
        ECR -. "exact digest" .-> CARE
    end
```

The workflow cannot deploy directly with `kubectl` or Helm. Git owns the portable desired state and digest; the ignored runtime layer supplies live AWS-specific values to Argo without publishing them.

## Ownership and configuration boundaries

| Owner | Objects / fields |
|---|---|
| Terraform | AWS VPC/EKS/RDS/ECR/KMS/IAM resources and remote state |
| GitHub Actions | tested/scanned image, immutable ECR digest and digest-only promotion PR |
| Git | generic Kubernetes desired state, controller Applications and promoted digest |
| Ignored runtime layer | live VPC ID, RDS secret ARN, IAM role ARNs, cluster name and private ECR repository URL |
| Argo CD | reconciles Git state with the generated runtime patches; it does not write those values back to Git |
| External Secrets | reads the single authorized AWS secret and owns the generated Kubernetes Secret |

`scripts/configure-cloud-manifests.py` writes the runtime composition only below ignored `.runtime/`. Pre-commit/CI guards reject live AWS runtime identifiers from tracked or staged files.

## Production and DR target — not runtime evidence

The stronger target adds Multi-AZ RDS, per-AZ NAT where justified, domain-valid TLS, edge logging/WAF controls, durable audit/observability, signed artifacts, a cross-region recovery data source and health-evaluated DNS failover. These are **design-level/PENDING**. The existing DR Terraform root is only a disabled VPC/EKS scaffold; no DR data path or failover was executed.

## Request and dependency behavior

- `/healthz` is process liveness and does not restart a healthy process merely because RDS is unavailable.
- `/readyz` runs a PostgreSQL query and migration check. Database loss removes a pod from Kubernetes and ALB endpoints.
- `/api/v1/appointments` returns synthetic IDs/statuses from PostgreSQL or a redacted HTTP 503. Production uses `verify-full` with a checksum-pinned AWS RDS global CA bundle in the image.
- A pool is bounded to five connections per pod. The mounted secret is fingerprinted; a new secret version replaces the pool without putting credentials in source, arguments, or ordinary environment variables.
- Schema migrations are ordered SQL files, serialized with a PostgreSQL advisory transaction lock, and recorded in `schema_migrations`.

## Failure domains and honest limitations

- Rolling updates keep ready old pods because `maxUnavailable=0`; the executed cloud drill served 145/145 requests while a bad revision stayed unready, and GitOps rollback restored full health in 153 seconds.
- Two demo worker nodes across three configured AZs do not prove three-AZ compute availability. No cluster autoscaler is implemented.
- The Free-plan demo uses one NAT gateway and single-AZ RDS. It is explicitly not production HA. The production target retains per-AZ NAT and Multi-AZ RDS.
- RDS network ingress trusts only the CareFlow pod security group, not the shared worker-node group. VPC CNI network policy and security groups for pods use standard enforcement mode.
- The small observability profile retains three days in ephemeral Prometheus storage. It proves operational signals, not durable audit retention.
- The RDS-managed master credential is used to keep this slice small enough to demonstrate migrations and rotation-aware delivery. Managed rotation recovery itself remains PENDING. A real production design should split a privileged migration identity from a restricted runtime database role.

## Important architecture decisions

### PostgreSQL and migrations in the application image

- **Decision:** Use psycopg connection pooling and small SQL migrations serialized by a PostgreSQL advisory lock.
- **Why:** It proves a real stateful path without adding a migration platform.
- **Alternatives considered:** ORM/Alembic; a separate migration Job; in-memory demo data.
- **Trade-offs:** Simple and testable, but application startup owns DDL and uses a privileged credential.
- **Cost implication:** No additional service.
- **Operational implication:** Failed migrations keep readiness false; production should eventually separate migrator and runtime roles.

### IRSA plus External Secrets

- **Decision:** External Secrets uses a short-lived token for the CareFlow service account to read exactly one RDS-managed secret; the app receives a mounted file.
- **Why:** No static AWS key or secret value enters Git, Terraform variables, or pod environment output.
- **Alternatives considered:** EKS Pod Identity with controller-wide access; Secrets Store CSI Driver/ASCP; direct AWS SDK calls from the app.
- **Trade-offs:** ESO adds one controller and a Kubernetes Secret copy. The app itself has no AWS SDK dependency; the IRSA trust still belongs to its dedicated service account.
- **Cost implication:** ESO is compute-only; Secrets Manager charges for the managed secret and API calls.
- **Operational implication:** ESO refreshes every five minutes and the app recreates its pool when the mounted JSON changes. Secret delivery executed successfully; managed-rotation recovery remains PENDING because the rotation request lacked authorization and made no change.

### Security groups for pods

- **Decision:** Assign CareFlow a branch-ENI security group and make RDS trust only that group.
- **Why:** The Milestone 1 node-security-group rule gave every pod on every worker network reachability to PostgreSQL.
- **Alternatives considered:** Dedicated node group; only Kubernetes NetworkPolicy; service mesh/egress proxy.
- **Trade-offs:** Better blast radius with added ENI capacity limits and pod-start latency.
- **Cost implication:** Security groups have no direct hourly charge; extra ENI/IP consumption can affect sizing.
- **Operational implication:** VPC CNI must have pod ENI enabled. The final run verified v1.23.0, `CNINode/SecurityGroupsForPods`, `ENABLE_POD_ENI=true`, trunk ENIs and pod branch ENIs.

### ECR publication and GitOps promotion

- **Decision:** GitHub OIDC publishes a scanned image to immutable ECR, then opens a digest-change PR.
- **Why:** It proves AWS federation and keeps the cluster reconciled only from reviewed Git state.
- **Alternatives considered:** GHCR; mutable tags; direct `kubectl set image` from CI.
- **Trade-offs:** ECR has small storage/API cost and requires AWS setup; promotion takes a reviewed merge.
- **Cost implication:** ECR storage and transfer are billed; lifecycle policy keeps only 20 images.
- **Operational implication:** Rollback is a Git revert to a known digest; the CI role has no Kubernetes permission. This path restored the prior digest through Argo in 153 seconds.

### ALB proof without requiring a purchased domain

- **Decision:** Use HTTP as the executable no-domain default, with optional ACM certificate input, HTTPS redirect and a TLS 1.2/1.3 policy when a validated domain exists.
- **Why:** It demonstrates the real AWS traffic path while allowing any existing validated domain.
- **Alternatives considered:** NLB; ingress-nginx; buying a portfolio domain.
- **Trade-offs:** The final run proved HTTP routing and two healthy targets. Trusted TLS remains PENDING because the ALB DNS name alone cannot establish hostname-valid public TLS.
- **Cost implication:** ALB hours/capacity units are billed; ACM public certificates are generally not the main cost driver.
- **Operational implication:** `/readyz` controls target health; a bad database removes targets, so at least two replicas matter.

### Focused Prometheus profile

- **Decision:** Run Prometheus Operator, one Prometheus and one Alertmanager; disable Grafana, node-exporter, and kube-state-metrics.
- **Why:** Request/error/latency/dependency signals and alerts prove the required maturity without an oversized demo stack.
- **Alternatives considered:** Full kube-prometheus stack; CloudWatch Container Insights; managed Prometheus.
- **Trade-offs:** No included dashboards and only ephemeral three-day retention.
- **Cost implication:** Uses existing worker capacity; no managed telemetry bill by default.
- **Operational implication:** Four alerts cover database loss, error ratio, p95 latency and missing metrics. The metrics/rules executed, but one of two cross-node CareFlow scrape targets timed out; durable receivers remain outside the demo.

### WAF deferred

- **Decision:** Do not attach WAF in Milestone 2.
- **Why:** There is no real threat/traffic evidence, and a baseline managed-rule attachment would add continuing cost without improving this synthetic short-lived demo materially.
- **Alternatives considered:** AWS managed common rules; a rate-based rule only.
- **Trade-offs:** The public demo relies on ALB/Kubernetes/application controls during the time-boxed window.
- **Cost implication:** Avoids WAF web ACL, rule, and request charges.
- **Operational implication:** Reconsider WAF before a persistent public deployment, based on actual abuse cases and a cost estimate.

### Explicit cloud opt-in

- **Decision:** All primary modules have zero instances unless `enable_cloud_resources=true`; CI never applies Terraform.
- **Why:** An accidental default apply must not create EKS, NAT, ALB, or RDS charges.
- **Alternatives considered:** Documentation-only warning; CI apply with environment approval.
- **Trade-offs:** Outputs are null in safe mode and live setup has an extra deliberate step.
- **Cost implication:** Default apply creates no billable AWS workload resources.
- **Operational implication:** Cloud execution is manual, reviewed, time-boxed, and followed by a read-only leftover scan.
