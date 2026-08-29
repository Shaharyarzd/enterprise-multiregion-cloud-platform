# AWS Preflight Review (Historical Checkpoint)

> This captures the initial preflight configuration and pricing review. It is not the final executed profile; see [`free-plan-demo-review.md`](free-plan-demo-review.md) and [`aws-runtime-evidence.md`](aws-runtime-evidence.md).

Review date: 2026-08-27. Scope: no-cost, read-only AWS readiness in `us-east-1`. No Terraform apply or destructive command was run.

## A. AWS identity status

**BLOCKED FOR DEPLOYMENT; usable for read-only planning.** Profile `careflow-preflight` authenticates to masked account `2939****5338` in `us-east-1`. The caller is an IAM user loaded from the shared credentials file, not a short-lived SSO/assumed-role session. CareFlow-tagged inventory is empty and organization membership was not observable, but account ownership cannot be proven from CLI metadata alone. The owner must continue to treat this as a sandbox-only account and must never substitute an employer/customer profile.

Installed tooling passed cloud preflight: AWS CLI 2.36.31, Terraform 1.15.8, kubectl 1.36.4, Helm 4.2.4, Git 2.50.1 and GitHub CLI 2.98.0. GitHub CLI is not authenticated; that is not required for Terraform planning.

## B. No-op plan result

**PASS.** With ignored `terraform.tfvars` left at `enable_cloud_resources = false`, the review-only local-backend plan contains **zero resource changes and zero AWS resource changes**. Evidence is private under `artifacts/cloud-plan/primary-noop/`.

The repository now distinguishes two planning paths:

- default `remote`: the only path permitted to produce an apply-eligible `cloud-demo.tfplan` after the state prerequisites exist;
- `CLOUD_PLAN_BACKEND_MODE=local-review`: produces `review-only.tfplan`, which `cloud-apply.sh` explicitly rejects.

## C. Real deployment plan result

**BLOCKED.** A complete enabled review-only plan succeeded after repository defects were fixed. It contains **89 creates, 10 data reads, zero changes, zero deletes and zero replacements**. The configuration was returned to `enable_cloud_resources = false` after capture.

Milestone 4 subsequently moved the GitHub publisher identity into the separate account bootstrap and made EKS role names deterministic for IAM scoping. The 89-create result remains the reviewed architecture baseline, not a reusable/apply-eligible artifact; a final remote-state plan must be regenerated and may have a different count.

The plan is architecturally reviewable but is not apply-eligible because the remote state bucket, dedicated EKS administrator role and account-level GitHub OIDC provider do not exist. The configured GitHub repository could not be publicly verified. The plan was also generated under an IAM user, so its EKS KMS key administration policy reflects that long-lived principal; a final remote plan must be regenerated under the approved short-lived role.

Execution found and fixed four plan blockers: an unknown-value database security-group `for_each`, an invalid IAM role name derived from an ECR path, unencrypted EKS node root volumes when account-default EBS encryption is off, and a non-empty ECR repository that would have blocked demo teardown.

## D. Expected resource summary

| Area | Enabled review plan | Interpretation |
|---|---:|---|
| Region/DR | 1 / none | `us-east-1` only; no DR root |
| VPC/subnets | 1 / 9 | Three public, three private worker and three database subnets across three AZs |
| Internet/NAT | 1 IGW, 1 NAT, 1 EIP | Cost-saving single-NAT demo; not production HA |
| EKS | 1 cluster | Kubernetes 1.36, standard support through 2027-08-02; private endpoint plus public endpoint restricted to one current `/32` |
| Workers | 1 managed node group / 2 nodes | Two on-demand `t3.medium`; 20 GiB encrypted gp3 root volume each; desired/min 2, max 4 |
| RDS | 1 instance | PostgreSQL 17 `db.t4g.micro`, 20 GiB gp3, private, encrypted, single-AZ, managed password, 7-day backup retention |
| ECR | 1 repository | Immutable, scan-on-push, AES-256; force-delete enabled only in ephemeral demo tfvars |
| IAM | 5 roles plus policies/attachments | EKS/node, GitHub publisher, CareFlow secret reader and load-balancer controller scopes |
| Encryption/logging | 1 KMS key, 1 EKS log group | EKS secret encryption, encrypted RDS/EBS, all five EKS control-plane log types, 30-day retention |
| Network controls | 4 security groups plus scoped rules | RDS accepts PostgreSQL only from the CareFlow pod security group; nodes remain private |
| ALB/WAF | Not in Terraform / none | ALB is created later by the Kubernetes controller; WAF remains intentionally omitted for the short synthetic demo |

No unexpected cross-region resources, additional EKS clusters, multiple NAT gateways, Multi-AZ RDS, public database, broad EKS API CIDR, oversized node type, delete or replacement appeared.

## E. Cost estimate

Eight-hour, low-traffic planning estimate, excluding tax and free-tier credits:

| Component | Eight-hour expected cost |
|---|---:|
| EKS standard-support control plane | $0.80 |
| NAT gateway plus one public IPv4, before data | $0.40 |
| Two `t3.medium` workers | $0.67 |
| Two 20 GiB gp3 root volumes | $0.04 |
| Single-AZ `db.t4g.micro` plus 20 GiB storage | about $0.15 |
| Later ALB, low LCU use and public IPv4 addresses | about $0.36 |
| One Secrets Manager secret | under $0.01 |
| One customer-managed KMS key | about $0.01 |
| ECR, S3 state and low-volume API requests | under $0.02 |
| CloudWatch and low data transfer | about $0.10–$0.50 |

**Low: $2.30. Expected: about $3.00. Conservative maximum: $8.00.** The USD 20 ceiling is not threatened under the planned eight-hour limit, but it is a stop condition rather than a guarantee. Failed teardown, traffic, taxes, pre-existing usage and resources outside this plan are excluded.

Rates were checked against the AWS Price List API for `us-east-1`: `t3.medium` $0.0416/hour, `db.t4g.micro` PostgreSQL Single-AZ $0.016/hour and ALB $0.0225/hour. AWS publishes EKS standard support at $0.10/cluster-hour, NAT at $0.045/hour plus $0.045/GB, public IPv4 at $0.005/hour, gp3 at $0.08/GiB-month, Secrets Manager at $0.40/secret-month, KMS at $1/key-month and ECR at $0.10/GB-month. Sources: [EKS pricing](https://aws.amazon.com/eks/pricing/), [EKS version lifecycle](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html), [VPC pricing](https://aws.amazon.com/vpc/pricing/), [EBS gp3](https://aws.amazon.com/ebs/general-purpose/), [Secrets Manager pricing](https://aws.amazon.com/secrets-manager/pricing/), [KMS pricing](https://aws.amazon.com/kms/pricing/), [ECR pricing](https://aws.amazon.com/ecr/pricing/) and [CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/).

## F. Security blockers

Deployment blockers:

1. Replace the long-lived IAM user session with a short-lived sandbox assumed role/SSO session. `cloud-apply.sh` now enforces this.
2. Pre-create and grant least-privilege access to the versioned, encrypted S3 state bucket defined by ignored `backend.hcl`.
3. Create the dedicated `careflow-platform-admin` role; cluster-creator admin is disabled, so the cluster would otherwise be inaccessible.
4. Create the account-level GitHub Actions OIDC provider and verify the exact GitHub owner/repository before trusting its `main` branch.
5. Confirm USD 10/USD 20 billing alerts in the sandbox account.
6. Generate a new remote-backend plan under the short-lived role and review it; the local review plan is deliberately non-applicable.

Senior-review observations that do not block this short demo:

- node egress permits TCP/443 to the internet for AWS APIs, registries and approved dependencies; endpoints/egress proxies would tighten a persistent environment;
- the VPC CNI policy remains attached to the node role rather than a dedicated add-on identity;
- the load-balancer controller policy is necessarily broad and must be version-reviewed when upgraded;
- the application still combines privileged migrations and runtime access through the RDS master principal;
- VPC flow logs, WAF and durable observability retention are intentionally excluded from this low-cost session.

Positive controls in the actual plan include private workers, a private RDS instance, security-group-to-security-group database access, one `/32` EKS public API CIDR, IMDSv2, encrypted EKS secrets/RDS/node disks, immutable ECR, exact GitHub repository/branch trust, service-account-bound secret access and complete EKS control-plane logs.

## G. Teardown readiness

**NOT READY until remote state and the short-lived deployment role exist; repository procedure is prepared.** The destroy wrapper binds account/region, creates a saved destroy plan and requires an exact phrase. The apply wrapper rejects local review plans. Ephemeral tfvars disable RDS deletion protection, skip the final snapshot and allow the non-empty ECR repository to be deleted. Node root volumes delete on termination.

The read-only leftover checker now covers VPCs, EC2, EKS, RDS, NAT, ALB, EBS, EIPs, security groups, ENIs, ECR, Secrets Manager, CloudWatch logs/alarms, RDS snapshots, IAM roles and tagged KMS keys. The operational sequence and retained-prerequisite rules are in `docs/aws-leftover-checklist.md`.

Remote state requirements are manual prerequisites: an S3 bucket with versioning, public-access blocking, default encryption and TLS-only policy; native S3 `use_lockfile = true`; and least-privilege access to only the bucket and `careflow/primary/` state/lock objects. The current backend uses SSE-S3. If a customer-managed KMS key is chosen, add `kms_key_id`, a key policy and only the required encrypt/decrypt/data-key permissions. No DynamoDB table is required by the current backend.

The local-review backend is appropriate for zero-state planning only. It must never be used for apply because it cannot coordinate, recover or prove ownership of deployed state.

## H. Exact owner action

Assign MFA to `careflow-portfolio-admin`, then follow `docs/aws-bootstrap-runbook.md`. The prepared bootstrap creates the state bucket, MFA-gated deployment role, separate platform-admin role, and—only after the exact repository is supplied—GitHub OIDC publisher identity. Do not authorize the bootstrap or main apply merely because the implementation is prepared.

## I. Explicit declaration

**No AWS workload resources were created during this milestone.**

## Cloud Deployment Readiness Score

**76/100 — READY WITH BLOCKERS.** Plan correctness, architecture and cost safety are strong; identity, external prerequisites and remote-state teardown proof prevent `READY FOR CONTROLLED AWS VALIDATION`. Runtime-evidence scores are unchanged.
