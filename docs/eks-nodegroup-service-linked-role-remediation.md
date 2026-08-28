# EKS Node-Group Service-Linked-Role Remediation

Review date: 2026-08-27. Region: `us-east-1`. This milestone changed only the inline policy on `careflow-deployment-role`; it did not apply the CareFlow workload.

## Exact requirement and account state

The third controlled validation reached `eks:CreateNodegroup`, then Amazon EKS attempted `iam:CreateServiceLinkedRole`. CloudTrail recorded an `AccessDenied` at `2026-08-27T10:11:03Z` on the exact resource path `role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup`. The Terraform/AWS error independently reported that EKS could not create `AWSServiceRoleForAmazonEKSNodegroup` because `iam:CreateServiceLinkedRole` was missing.

AWS documents that:

- the service-linked role name is `AWSServiceRoleForAmazonEKSNodegroup`;
- its trusted service is `eks-nodegroup.amazonaws.com`;
- EKS automatically creates it when a managed node group is created; and
- if the role is later deleted, a subsequent managed-node-group creation recreates it.

References: [EKS node-group service-linked role](https://docs.aws.amazon.com/eks/latest/userguide/using-service-linked-roles-eks-nodegroups.html) and [IAM service-linked-role creation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create-service-linked-role.html).

Read-only `iam:GetRole` checks before and after this milestone returned `NoSuchEntity`. The role does not currently exist because no workload apply was run after the third validation teardown.

## Least-privilege policy delta

Exactly one statement was added to `bootstrap/aws/deployment-policy.tf`:

| Field | Value |
|---|---|
| Action | `iam:CreateServiceLinkedRole` |
| Resource | Exact same-account role ARN ending in `role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup` |
| Condition | `StringEquals`, `iam:AWSServiceName = eks-nodegroup.amazonaws.com` |

The permission does not use `Resource: "*"`. No `iam:CreateRole`, `iam:AttachRolePolicy`, new `iam:PassRole`, policy-management action, or unrelated service-linked-role service name was added.

## Security review

- **Blast radius:** one AWS-defined role name for one AWS service in the sandbox account.
- **Privilege escalation:** the deployment principal cannot choose a trust policy, permissions policy, arbitrary role name, or another service. AWS owns the service-linked-role definition and attaches its service-owned policy.
- **Other service-linked roles:** cannot be created through the new statement because both the exact ARN and the exact `iam:AWSServiceName` condition must match.
- **PassRole:** unchanged. The statement does not pass or assume the service-linked role.
- **Account bootstrap versus recurring deployment:** this is normally a first-use account prerequisite. After successful EKS creation, the role persists independently of the Terraform workload unless explicitly deleted. The narrowly scoped permission remains so a later node-group creation can safely recreate the role if it is ever removed.

IAM simulation of the isolated delta and the applied live role returned:

| Case | Expected | Result |
|---|---|---|
| Exact role ARN plus `eks-nodegroup.amazonaws.com` | PASS | `allowed` |
| Exact role ARN plus `lambda.amazonaws.com` | DENY | `implicitDeny` |
| Arbitrary Lambda service-linked-role ARN plus Lambda service name | DENY | `implicitDeny` |

AWS Access Analyzer validation of the new statement returned zero findings. Full-policy validation continues to report one pre-existing unrelated `INVALID_ACTION` finding for `eks:DescribeAccessPolicy`. That inert action predates this delta, did not cause any observed deployment failure, and was not changed because this milestone was explicitly restricted to the node-group prerequisite.

## Bootstrap execution

The refresh-enabled bootstrap plan contained **0 creates, 1 in-place update, 0 deletes**. Its sole changed address was `aws_iam_role_policy.deployment`. The guarded bootstrap apply completed with **0 added, 1 changed, 0 destroyed**. The refresh-enabled post-apply bootstrap plan returned **No changes**.

The owner removed `careflow-temporary-bootstrap-executor`; a read-only check showed that only `careflow-assume-deployment-role` remains on the IAM user. The MFA bootstrap profile and all temporary deployment-session credential fields were cleared and verified zero-length.

## Role, backend and fresh workload plan

STS returned the expected short-lived `assumed-role/careflow-deployment-role/careflow-validation` identity in the sandbox account and `us-east-1`. Remote state was readable and empty. The fresh plan acquired and released the native S3 lock.

The new remote plan under `artifacts/cloud-plan/eks-slr-remediation-final/` contains **88 creates, 9 reads, 0 updates, 0 deletes and 0 replacements**. It contains one VPC, nine subnets, one NAT/EIP, one EKS cluster, one managed node group with two desired `c7i-flex.large` workers, one private encrypted Single-AZ PostgreSQL RDS instance with one-day retention, one immutable ECR repository, one regional workload KMS key and the expected scoped IAM/security resources. It contains no DR, WAF, additional NAT, Multi-AZ RDS or cross-region resource.

Security and teardown controls remain unchanged: private EKS access is enabled; public EKS access is limited to the verified owner `/32`; RDS is private and encrypted; IMDSv2 and encrypted node volumes are required; ECR is immutable and scans on push; RDS deletion protection is off, final snapshot is skipped, ECR force-delete is enabled and KMS retains its AWS-enforced deletion waiting period. The ignored local `enable_cloud_resources` switch was restored to `false` after plan creation.

Expected cost remains approximately $3.50 for the controlled validation window, with the reviewed $6 conservative maximum and $20 absolute stop ceiling. No apply was run.

## Readiness

- IAM Remediation Confidence: **96/100**
- Cloud Deployment Readiness Score: **92/100**
- Classification: **READY FOR FOURTH CONTROLLED AWS VALIDATION**

No known IAM blocker remains for the previously observed node-group path. Runtime success is not inferred; any fourth workload apply still requires new explicit owner authorization and mandatory teardown.

**No CareFlow workload infrastructure was created during this IAM remediation milestone.**
