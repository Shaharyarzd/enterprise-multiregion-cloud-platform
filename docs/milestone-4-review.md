# Milestone 4 AWS Bootstrap Review

> Historical pre-runtime checkpoint. A later controlled apply attempt and its complete teardown are recorded in [`aws-runtime-evidence.md`](aws-runtime-evidence.md). The statement below that the saved plan had not been applied was true at this checkpoint.

Review date: 2026-08-27. Region: `us-east-1`. The account ID is intentionally omitted from this tracked report.

## Executed bootstrap

An MFA-authenticated one-hour session created the versioned, SSE-S3-encrypted, public-blocked state bucket; `careflow-deployment-role`; `careflow-platform-admin`; the GitHub OIDC provider; and `careflow-github-ecr-publisher` for `Shaharyarzd/enterprise-multiregion-cloud-platform`. The temporary bootstrap-executor policy was removed immediately afterward. The IAM user retains only its assume-role caller policy plus inherited read-only access.

The bootstrap apply contained 15 creates, zero changes and zero deletes. A narrowly targeted follow-up applied two in-place policy corrections, after which a normal refresh-enabled bootstrap plan reported no drift.

Both role hops were exercised successfully with STS: the deployment role and the separate platform-admin role returned assumed-role caller identities. No long-lived AWS key was added to GitHub.

## Remote backend and final plan

The primary root initialized against `careflow/primary/terraform.tfstate` in the bootstrap S3 bucket with native S3 locking. The final plan was generated under the short-lived deployment role and the lock was released normally. A plan does not create an S3 state object when no remote state exists yet; the successful initialization, lock cycle and plan establish backend access.

The reviewed final plan contains **87 creates, 9 reads, zero updates, zero deletes and zero replacements**. Its major resources are one VPC, nine subnets, one NAT gateway/EIP, one EKS cluster, one managed node group with two desired `t3.medium` nodes, one private encrypted single-AZ PostgreSQL RDS instance, one ECR repository, and one KMS key. The GitHub publisher role and policy are no longer in this count because the bootstrap owns them.

Security review confirmed a private EKS endpoint plus public access restricted to the current `/32`, explicit EKS access for `careflow-platform-admin`, disabled cluster-creator administrator access, private encrypted RDS, encrypted node volumes, immutable ECR, and no cross-region resources. Demo teardown controls intentionally use one NAT gateway, RDS `skip_final_snapshot`, disabled RDS deletion protection, and ECR force deletion.

The ignored local input was returned to `enable_cloud_resources = false` after plan capture. The saved plan remains evidence only and has not been applied.

## Cost and readiness

Persistent bootstrap cost is expected to remain below $0.01/month for tiny S3 state/version data; IAM, STS and the OIDC provider have no separate charge. The planned eight-hour workload estimate remains approximately $3, with a conservative $8 ceiling, excluding tax, unexpected traffic, pre-existing usage and failed teardown.

Read-only inventory after bootstrap found no CareFlow EKS clusters, RDS instances, EC2 instances, VPCs, NAT gateways or load balancers. The project is **READY FOR CONTROLLED AWS VALIDATION**, subject to a new explicit owner authorization immediately before the billable main apply and the existing time-boxed teardown procedure.

**No CareFlow workload infrastructure was created.**
