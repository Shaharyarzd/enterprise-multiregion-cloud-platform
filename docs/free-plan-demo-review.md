# Free-plan Demo Review (Historical Planning Checkpoint)

Review date: 2026-08-27. Scope at this checkpoint: redesign, validation, retained bootstrap-policy correction and a fresh remote Terraform plan only. The later final run used a new 89-create plan; current evidence is in [`aws-runtime-evidence.md`](aws-runtime-evidence.md).

## A. Selected worker type

The Free-plan demo selects **two `c7i-flex.large` workers**. AWS reported this type as Free-plan eligible, x86_64, 2 vCPU, 4,096 MiB memory, three network interfaces and ten IPv4 addresses per interface. The current on-demand Linux rate returned by the AWS Price List API for `us-east-1` is $0.08479/hour.

`t3.small` is cheaper but not credible for this workload with standard VPC CNI settings. Its three interfaces and four addresses per interface give `(3 × (4 - 1)) + 2 = 11` pods per node, or only 22 across two nodes. The required steady-state set is approximately 28 pods. `c7i-flex.large` provides `(3 × (10 - 1)) + 2 = 29` pods per node, or 58 total, without introducing ARM image compatibility risk.

The production target remains three desired `t3.medium` workers (minimum 2, maximum 6). The sandbox choice does not redefine production capacity.

## B. Expected cluster capacity

Using the EKS kubelet reservation formula and a 100 MiB hard-eviction allowance, one `c7i-flex.large` is expected to expose approximately **1,930 millicores and 3,422 MiB** allocatable. Two nodes therefore provide roughly **3,860 millicores, 6,844 MiB and 58 pod slots**.

Rendered pinned charts account for 16 controller pods requesting 950 millicores and 1,568 MiB. Prometheus and Alertmanager add approximately 125 millicores/320 MiB; two CareFlow replicas add 100 millicores/128 MiB. EKS add-ons contribute approximately eight pods: two CoreDNS replicas plus `aws-node`, `kube-proxy`, and the Pod Identity Agent on each node. The resulting steady state is about 28 pods. A conservative 600 millicore/700 MiB allowance for those system pods still leaves more than 2 vCPU, 4 GiB and 30 pod slots of aggregate headroom.

The focused observability profile keeps one Prometheus, one Alertmanager and the operator, with three-day ephemeral retention. Grafana, node-exporter and kube-state-metrics remain disabled for the demo. Argo CD and the required controllers have explicit reduced requests. Kyverno is now installed declaratively with its policies and is scoped to the labelled CareFlow namespace so third-party controllers are not accidentally blocked.

This capacity is suitable for a short functional validation, not a production load claim. Two workers across three subnet AZs do not prove three-AZ compute availability, and there is no cluster autoscaler.

## C. RDS retention

| Profile | Backup retention | Resilience/teardown behavior |
|---|---:|---|
| Production target | At least 7 days | Multi-AZ, deletion protection, final snapshot |
| Free-plan demo | 1 day | Single-AZ, deletion protection off, final snapshot skipped |

**One-day retention is an AWS Free-plan execution constraint and is NOT the recommended production retention.** Encryption, forced TLS, private networking, managed master credentials, PostgreSQL-only security-group access, and storage encryption remain unchanged.

## D. Architecture differences

Both profiles exercise the same Terraform modules and the same intended GitHub → ECR → Argo CD → EKS → ALB → CareFlow → RDS path.

| Area | Production target | Free-plan demo |
|---|---|---|
| Workers | 3 desired `t3.medium` | 2 desired `c7i-flex.large` |
| NAT | One per AZ | One shared NAT |
| Database | Multi-AZ, protected | Single-AZ, teardown-oriented |
| Backups | 7+ days | 1 day |
| Observability | Durable production design still required | Focused, ephemeral Prometheus evidence |
| Claims | Production architecture target | Constrained runtime validation only |

The demo can prove federation, immutable publication, GitOps reconciliation, workload identity, secret delivery, database connectivity, metrics, failed rollout/rollback and—if exercised—managed-secret rotation. It cannot prove production capacity, production backup durability, regional DR, durable audit retention or production HA.

## E. Fresh plan result

The fresh apply-eligible-format binary was generated through the remote S3 backend under `arn:aws:sts::*:assumed-role/careflow-deployment-role/careflow-validation`. The remote workload state contained zero entries before planning, and native S3 locking was acquired and released successfully.

| Action | Count |
|---|---:|
| Creates | **88** |
| Data reads | **9** |
| Updates | **0** |
| Deletes | **0** |
| Replacements | **0** |

The one-resource increase from the historical 87-create plan is an `aws_ec2_tag` applying `Profile=free-plan-demo` to the EKS-created primary security group. Major planned resources remain one VPC, nine subnets across `us-east-1a/b/c`, one NAT gateway, one EIP, one EKS cluster, one managed node group with two desired eligible workers, one private encrypted Single-AZ PostgreSQL RDS instance, one ECR repository, one KMS key and scoped IAM/security resources. The ALB is created later by the Kubernetes controller and is not part of this Terraform count.

No DR root, second cluster, second database, extra NAT, WAF, public database, cross-region resource, delete, update or replacement appears.

## F. Security review

The demo profile preserves private workers; private encrypted RDS; forced PostgreSQL TLS; managed credentials; pod-specific database network identity; encrypted EBS and EKS secrets; IMDSv2; all five EKS control-plane log types; immutable ECR; exact GitHub repository/environment OIDC trust; scoped workload identity; and Kyverno enforcement. The EKS private endpoint is enabled, and its public endpoint is limited to the verified current `<OWNER_PUBLIC_IP>/32` egress address.

The demo-only security/recovery reductions are Single-AZ RDS, one-day backups, one shared NAT and teardown-oriented deletion settings. Node HTTPS egress remains internet-wide on TCP/443 for registries, GitOps and service APIs; this is a documented temporary exception rather than unrestricted all-protocol egress. No new broad IAM permission was added: the retained role gained the exact teardown action `ec2:DisassociateAddress` and read-only `freetier:GetAccountPlanState` for the apply gate.

## G. Cost

Eight-hour, low-traffic gross estimate before credits:

| Component | Estimate |
|---|---:|
| EKS standard-support control plane | $0.80 |
| NAT gateway + one public IPv4, before data | $0.40 |
| Two `c7i-flex.large` workers | $1.36 |
| Two 20 GiB gp3 roots | $0.04 |
| Single-AZ `db.t4g.micro` + 20 GiB storage | about $0.15 |
| Later ALB, low LCU use and public IPv4 | about $0.36 |
| KMS, Secrets Manager, ECR, S3 and low API use | about $0.04 |
| CloudWatch, NAT processing and low transfer | about $0.10–$0.50 |

**Gross low: about $3.25. Expected: about $3.50. Conservative maximum: $6.00.** The account API reported $100 of remaining Free-plan credits. Expected incremental cost may therefore be $0 if the credits apply to every incurred service, but that is not guaranteed and must not replace the USD 20 stop ceiling or immediate teardown.

## H. Bootstrap-role correction

The reviewed bootstrap plan showed **0 add, 1 in-place update, 0 destroy**. It updated only `careflow-deployment-role:careflow-sandbox-deployment`, adding `ec2:DisassociateAddress` and read-only `freetier:GetAccountPlanState`. The apply completed successfully, a second bootstrap plan returned **No changes**, and the live policy contains both actions. The temporary bootstrap executor was then removed; the IAM user again has only `careflow-assume-deployment-role` inline plus group-provided read-only access.

After the MFA source profile was cleared, the cached STS session still returned the expected assumed-role ARN. The deployment role can read the empty remote state and plan successfully. Its scoped policy cannot run the ALB inventory call; the separate read-only profile completed the full leftover audit without broadening deployment permissions.

## I. Deployment readiness

**READY FOR SECOND CONTROLLED AWS VALIDATION.** Cloud Deployment Readiness Score: **94/100**.

The remaining conditions are operational, not planning defects: a new explicit owner authorization is required immediately before any workload apply; the USD 20/8-hour stop controls remain mandatory; runtime evidence is still pending; browser-trusted TLS still requires a controlled domain/ACM certificate; and the KMS key from the safely failed first run remains disabled in `PendingDeletion` until 2026-09-26.

The previous failed attempt remains recorded in `docs/aws-runtime-evidence.md`: account restrictions were discovered, automation stopped safely, teardown passed, the profile was redesigned, and this new remote plan was reviewed. No CareFlow workload infrastructure was created during this milestone.
