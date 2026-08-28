# IAM Remediation Review

Review date: 2026-08-27. Region: `us-east-1`. This milestone changed only the inline policy on `careflow-deployment-role`; it did not apply the CareFlow workload.

## Exact runtime denials

CloudTrail recorded the following service calls from the MFA-backed `careflow-deployment-role` session:

| Blocker | Exact action | Evidence and required scope |
|---|---|---|
| RDS managed master password | `secretsmanager:CreateSecret` | RDS invoked Secrets Manager and was denied on the generated `rds!db-*` secret. AWS documents `CreateSecret`, `TagResource`, and `kms:DescribeKey` for RDS-managed password creation. |
| EKS managed node group | `ec2:RunInstances` | EKS invoked EC2 and was denied first on the account's `instance/*` resource while using the Terraform-created launch template. AWS documents `RunInstances` and `CreateTags` for a managed node group with a custom launch template. |

`secretsmanager:TagResource` is a documented dependent permission that could not execute after `CreateSecret` failed. Existing policy already allowed `kms:DescribeKey` through read-only KMS metadata access, `ec2:CreateTags`, and a project-role-only `iam:PassRole`. CloudTrail showed the RDS storage-key `kms:CreateGrant` call succeeding. No new KMS, tagging, or PassRole action was added.

References: [RDS managed-password permissions](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html), [EKS custom launch-template permissions](https://docs.aws.amazon.com/eks/latest/userguide/launch-templates.html), [EC2 RunInstances resource authorization](https://docs.aws.amazon.com/service-authorization/latest/reference/list_ec2.html), and [Secrets Manager authorization reference](https://docs.aws.amazon.com/service-authorization/latest/reference/list_secretsmanager.html).

## Added permissions and classification

| Action | Classification | Scope and conditions |
|---|---|---|
| `secretsmanager:CreateSecret` | REQUIRED | Same account/region `secret:rds!db-*`, plus `secretsmanager:Name = rds!db-*` |
| `secretsmanager:TagResource` | REQUIRED | Same account/region `secret:rds!db-*`; no secret-value or policy access |
| `ec2:RunInstances` | REQUIRED | Split across the resource types EC2 evaluates: project-tagged launch template/subnets/security groups, project-tagged new instances/ENIs/volumes, and Amazon-owned AMIs/snapshots |
| Amazon-owned AMI/snapshot ARN patterns | AWS API WILDCARD LIMITATION | IDs are selected dynamically by EKS. `ec2:Owner = amazon` and the same-account regional launch-template condition restrict the wildcard. |

No OPTIONAL action was added. No statement uses unrestricted `Resource: "*"` for either new action. The EC2 statements additionally require `c7i-flex.large`, IMDSv2, `Project=careflow-portfolio`, and a same-account `us-east-1` launch template. The launch template, instance, volume, and ENI tags in the fresh Terraform plan satisfy those conditions.

## Security assessment

- **Blast radius:** confined to RDS-generated secret names and the existing tagged CareFlow EC2 path in `us-east-1`.
- **Privilege escalation:** no IAM policy-management action was added. The deployment role cannot use the new statements to grant itself permissions.
- **PassRole:** unchanged; only `careflow-portfolio-*` roles may be passed, and only to EC2/EKS.
- **Launch-template abuse:** wrong instance type, wrong request tag, wrong launch-template project tag, and non-Amazon AMI all returned `implicitDeny` in IAM simulation. The allowed path returned `allowed` for every required EC2 resource type.
- **Secrets Manager abuse:** only creation/tagging of `rds!db-*` is permitted. `GetSecretValue`, `PutSecretValue`, `UpdateSecret`, `DeleteSecret`, rotation, replication, and resource-policy actions were not added.
- **Policy validation:** the six new statements produced zero AWS Access Analyzer findings. Full-policy validation retained one pre-existing non-blocking finding for the unrelated invalid action name `eks:DescribeAccessPolicy`; it was not changed because this milestone is restricted to the two runtime blockers.

The safety model remains acceptable for the synthetic sandbox. Actual EKS/RDS service execution still requires a separately authorized controlled validation.

## Bootstrap execution

The refresh-enabled bootstrap plan contained **0 creates, 1 in-place update, 0 deletes**. The sole target was `aws_iam_role_policy.deployment`. The guarded bootstrap apply completed with **0 added, 1 changed, 0 destroyed**. A subsequent refresh-enabled bootstrap plan returned **No changes**.

The temporary executor policy was removed by the owner and independently verified absent. The MFA bootstrap profile was then cleared locally.

## Temporary-role and backend validation

- STS returned the expected `assumed-role/careflow-deployment-role/careflow-validation` identity.
- Remote workload state was readable and empty.
- Both remote plans acquired and released native S3 locking; no lock object remained afterward.
- Read-only IAM simulation allowed the intended Secrets Manager and EC2 contexts and denied the negative EC2 cases.

## Fresh remote workload plan

The first newly generated plan correctly reflected the local safety default `enable_cloud_resources=false`; it changed no AWS resource. Planning was then explicitly enabled to create a second, new binary review plan under `artifacts/cloud-plan/iam-remediation-final/`. The local switch was restored to `false` immediately afterward.

The final fresh plan contains **88 creates, 9 reads, 0 updates, 0 deletes, and 0 replacements**. It includes one VPC, nine subnets, one NAT/EIP, one EKS cluster, one managed node group with two desired `c7i-flex.large` workers, one private encrypted Single-AZ PostgreSQL RDS instance with one-day retention, one immutable ECR repository, one regional workload KMS key, and scoped IAM/security resources. It contains no DR, WAF, extra NAT, Multi-AZ RDS, or cross-region resource. The public EKS endpoint remains limited to the currently verified owner `/32`; the private endpoint is enabled.

Teardown settings remain suitable for a short synthetic validation: RDS deletion protection is off, no final snapshot is requested, ECR force-delete is enabled, EBS volumes delete on termination, and the single NAT/EIP are Terraform-owned. KMS deletion still uses AWS's mandatory pending-deletion lifecycle.

Expected cost remains approximately $3.50 for the controlled demo window, with the previously approved $6 conservative maximum and $20 absolute stop ceiling. No apply was run.

## Readiness

- IAM Remediation Confidence: **93/100**
- Cloud Deployment Readiness Score: **88/100**
- Classification: **READY FOR THIRD CONTROLLED AWS VALIDATION**

Runtime-evidence scores are unchanged. A third workload apply requires a new explicit owner authorization and mandatory teardown.

**No CareFlow workload infrastructure was created during this remediation milestone.**
