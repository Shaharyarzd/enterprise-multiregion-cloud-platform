# AWS Runtime Evidence

Execution date: 2026-08-27. Region: `us-east-1`. Account identifiers, resource IDs, credentials and secret values are omitted. Raw plans and ephemeral evidence remain under ignored `artifacts/`.

## Fourth controlled validation outcome

**Infrastructure deployment result: PASS. Runtime vertical-slice result: STOPPED WITH BLOCKERS. Terraform teardown and independent cleanup: PASS.** The single owner-authorized fourth run used the short-lived `careflow-deployment-role`, remote S3 state with native locking, and the previously reviewed `free-plan-demo` binary plan. Terraform applied exactly **88 creates, 0 changes and 0 destroys**. There was no retry or second apply.

The prior IAM remediations worked in live execution. The private encrypted Single-AZ PostgreSQL database and RDS-managed secret reached `available`; the custom EC2 launch-template path completed; `AWSServiceRoleForAmazonEKSNodegroup` was created for `eks-nodegroup.amazonaws.com`; the managed node group reached `ACTIVE`; and exactly two private `c7i-flex.large` workers became Kubernetes `Ready` in separate availability zones. ECR was immutable with scan-on-push, the EKS API remained restricted to the owner `/32`, and all five control-plane log types wrote to a 30-day log group.

Repository-pinned Argo CD installed successfully. Argo began reconciling External Secrets, Kyverno, metrics-server and AWS Load Balancer Controller, but runtime events exposed two material blockers before any CareFlow workload was submitted:

1. The EKS VPC resource controller could not create trunk ENIs because the cluster role lacks the `AmazonEKSVPCResourceController` managed policy required by the repository's `ENABLE_POD_ENI=true` and `SecurityGroupPolicy` design.
2. AWS Load Balancer Controller v3.5.0 crash-looped because its chart values supplied the cluster name but not explicit `region` and `vpcId`. Hardened worker IMDS settings correctly prevented the controller from discovering the VPC through instance metadata.

The authorization required an immediate stop for a material IAM or configuration fix. No IAM edit, architecture change, speculative probe or second apply was performed. GitHub-to-ECR publication was also not attempted: GitHub CLI was signed out and the named remote repository was verified to be empty. No issued ACM certificate exists in `us-east-1`, so trusted public TLS could not have been claimed in this run.

## Remediation prepared after the fourth run

The repository now attaches AWS-managed `AmazonEKSVPCResourceController` to the workload-created EKS cluster role, exactly as required for `ENABLE_POD_ENI=true`. Its EC2 ENI operations include AWS-required wildcard resource scopes; `CreateNetworkInterfacePermission` is constrained by the AWS-managed `eks:eni:owner=eks-vpc-resource-controller` resource-tag condition. It contains no IAM, `PassRole`, policy-management, credential, or general EC2 instance-launch permissions.

AWS Load Balancer Controller retains hardened worker IMDS (`http_tokens=required`, hop limit 1) and instead receives explicit `region=us-east-1` and the Terraform-created VPC ID. Argo sync waves are deterministic, and bootstrap now waits for all workers to become Ready and to report the VPC resource-controller trunk label before installing the controller set. The default production Ingress is HTTP-only so ALB/listener/routing evidence does not depend on a purchased domain; an optional, disabled patch enables ACM-backed redirect/HTTPS when a validated certificate exists. Trusted TLS remains **PENDING**.

These changes have passed local invariants, Python/shell syntax, Terraform primary/DR/bootstrap validation, Kustomize/kubeconform rendering, pinned Helm chart rendering, and GitHub Actions lint. The two `c7i-flex.large` workers retain estimated steady-state headroom: approximately 1.74 vCPU and 2.4 GiB requested including the observed EKS system baseline, against approximately 3.86 vCPU and 6.68 GiB allocatable. This is configuration/readiness evidence, not a runtime score increase.

The GitHub prerequisite is still operationally blocked: this workspace has no `.git` metadata, GitHub CLI is signed out, and the named remote repository has no refs. The `portfolio-publish` environment therefore cannot yet be verified. No GitHub publication claim is made.

The subsequent non-billable AWS checks used a fresh MFA source session and one-hour `careflow-deployment-role` session. Account bootstrap refreshed cleanly with **No changes**; no bootstrap apply was needed. The exact live AWS-managed policy (default version `v1`) matched the reviewed eight ENI/IP actions. Access Analyzer returned no findings, and IAM simulation proved the conditioned allow plus unrelated-action denies. Remote workload state was empty and native S3 locking acquired/released normally.

A completely new remote `free-plan-demo` plan contains **89 creates, 9 reads, 0 updates, 0 deletes and 0 replacements**. The only count change from the fourth-run plan is the intended `AmazonEKSVPCResourceController` attachment. It retains one VPC, nine subnets, one NAT/EIP, one EKS cluster/node group with two `c7i-flex.large` workers, one private encrypted Single-AZ RDS instance with one-day retention, one immutable ECR repository, one workload KMS key, and no DR, WAF, additional NAT, Multi-AZ database or cross-region resource. No plan was applied.

## Latest executed evidence matrix

| Area | Status | Executed result |
|---|---|---|
| STS identity/account/region | PASS | MFA-backed deployment role and a separate in-memory platform-admin role hop; expected sandbox; `us-east-1` |
| Remote backend/locking | PASS | Remote state readable; native lock acquired/released for apply, destroy and post-check; post-destroy resource state is empty |
| Reviewed plan integrity | PASS | 88 create, 9 read, 0 update/delete/replace; `free-plan-demo`; no DR/WAF/Multi-AZ/cross-region resources |
| Terraform apply | PASS infrastructure | Exactly 88 added, 0 changed, 0 destroyed; no retry |
| EKS control plane | PASS | `ACTIVE`; private and `/32`-restricted public endpoints; five log types; 30-day retention |
| EKS workers | PASS | Managed node group `ACTIVE`; two private `c7i-flex.large` instances; both Kubernetes `Ready` across two AZs |
| EKS pod security groups | FAIL | Trunk ENI creation was denied; cluster role lacks `AmazonEKSVPCResourceController` |
| RDS | PASS infrastructure / PENDING application | Private, encrypted, Single-AZ PostgreSQL; one-day retention; RDS-managed rotation enabled; no application connection attempted |
| ECR | PASS infrastructure / PENDING publication | Immutable and scan-on-push; no image was published |
| GitHub OIDC bootstrap | PASS static / PENDING runtime | Scoped provider/role retained, but GitHub CLI was signed out and the remote repository was empty |
| Argo CD | PASS bootstrap / PARTIAL reconciliation | Pinned chart installed and server became Available; controller Applications began reconciliation |
| Approved controllers | PARTIAL/FAIL | External Secrets and Kyverno started; metrics-server was progressing; ALB controller failed VPC discovery through blocked IMDS |
| CareFlow / RDS API path | PENDING | Stop condition occurred before workload submission; no pod or synthetic request existed |
| ALB / TLS | PENDING | No Ingress or ALB was created; no issued ACM certificate existed |
| Cloud observability | PARTIAL | EKS control-plane logs executed; application Prometheus targets/rules/alerts were not exercised |
| Failed rollout / rollback | PENDING on AWS | No CareFlow Deployment existed; local kind proof remains PASS |
| RDS secret rotation | PASS service configuration / PENDING application recovery | AWS reported managed rotation enabled; no application refresh/recovery test ran |
| Terraform teardown | PASS | Argo Applications removed first; no controller ALB/SG existed; guarded plan was 0 add, 0 change, 88 destroy; apply completed |
| Independent leftovers | PASS | Owner deleted the exact zero-byte RDS log group and API verification returned empty; no billable workload remains; service-linked role intentionally persists |

## Fourth-run teardown and cost

The apply started at `14:19:52Z`, completed in approximately 13 minutes, and runtime validation stopped at approximately `14:42Z`. Controller-aware cleanup preceded Terraform destroy. The final guarded destroy completed at approximately `15:02Z`, so the billable stack existed for about 43 minutes. No ALB was ever created.

The post-destroy inventory found no project VPC, running EC2 instance, EKS cluster, RDS instance, NAT gateway, EIP, ALB, EBS volume, ENI, ECR repository, managed secret, workload IAM role or controller-created security group. The two EC2 records are terminated history. The EKS node-group service-linked role intentionally persists as an account prerequisite. Four workload KMS keys from the controlled attempts are disabled in AWS-enforced `PendingDeletion` and are not billable. One zero-byte RDS PostgreSQL log group survived outside Terraform state; the owner deleted that exact group and a subsequent API query returned empty.

The MFA source profile, temporary platform-admin profile, temporary kubeconfig and the two CareFlow AWS CLI role-cache files were cleared after the final inventory. Credential-field length checks returned empty and the former deployment session could no longer authenticate.

Conservative fourth-run cost is **under $0.50 before Free-plan credits**, dominated by roughly 43 minutes of EKS control-plane, two workers, one NAT gateway and a small RDS instance. Estimated cumulative cost across all four controlled attempts remains **under $1.75 before credits**. Billing telemetry is delayed, so these are estimates rather than invoice claims.

## Third controlled validation outcome

**Deployment result: FAIL (safe stop). Teardown result: PASS.** The owner-authorized third run used the short-lived `careflow-deployment-role`, the reviewed remote S3 backend with native locking and the `free-plan-demo` profile. Its immutable pre-apply gate passed with **88 creates, 9 reads, 0 updates, 0 deletes and 0 replacements**. The plan specified two `c7i-flex.large` workers, one-day RDS backup retention, one NAT gateway, private Single-AZ RDS, no DR, no WAF and no cross-region workload resource.

The preceding least-privilege remediation worked in real AWS execution: RDS created its managed Secrets Manager secret and the private encrypted database reached `available`; EKS created the custom launch template without an `ec2:RunInstances` denial. The EKS control plane also reached `ACTIVE`.

First-time managed-node-group creation then failed before any worker launched. AWS returned `InvalidRequestException: Failed to create service linked role: AWSServiceRoleForAmazonEKSNodegroup due to missing permissions for 'iam:CreateServiceLinkedRole'`. This is a new IAM scope change. The run therefore stopped without a policy edit or second apply, as required by the authorization boundary.

No node group, EC2 worker, controller, ALB or CareFlow application was created. Because Kubernetes had no worker, the GitHub publication, GitOps, application, observability, rollout/rollback and secret-rotation phases were not attempted.

## Third-run evidence matrix (historical)

| Area | Status | Executed result |
|---|---|---|
| STS identity/account/region | PASS | Assumed `careflow-deployment-role`; expected sandbox; `us-east-1` |
| Remote backend/locking | PASS | S3 backend initialized; native lock acquired/released; post-destroy remote state is empty |
| Reviewed plan integrity | PASS | 88 create, 9 read, 0 update/delete/replace; `free-plan-demo`; no DR |
| Free-plan controls | PASS | Account plan `FREE`; two `c7i-flex.large` workers eligible; one-day retention; one NAT; Single-AZ RDS |
| Terraform apply | FAIL | Partial creation stopped on the new EKS service-linked-role requirement; no second apply |
| EKS control plane | PASS (limited) | Cluster reached `ACTIVE` before teardown |
| EKS custom launch template | PASS | Launch template was created; the earlier EC2 authorization blocker did not recur |
| EKS workers | FAIL | `eks:CreateNodegroup` reached AWS but could not create `AWSServiceRoleForAmazonEKSNodegroup` without `iam:CreateServiceLinkedRole`; no worker launched |
| RDS | PASS (infrastructure only) | Private encrypted Single-AZ DB and RDS-managed secret were created; no application connection was attempted |
| GitHub OIDC bootstrap | PASS | The retained GitHub provider/publisher role exists for `Shaharyarzd/enterprise-multiregion-cloud-platform` |
| GitHub to ECR publication | PENDING | Runtime phase not reached; the empty ECR repository was destroyed |
| Controllers / Argo CD | PENDING | No worker nodes; no Kubernetes bootstrap attempted |
| CareFlow / RDS API path | PENDING | RDS existed, but no worker or application connected to it |
| ALB / TLS | PENDING | No controller or ingress was deployed |
| Cloud observability | PENDING | Control-plane log infrastructure existed briefly; app metrics/rules were not exercised |
| Failed rollout / rollback | PENDING on AWS | No cloud workload existed; local kind proof remains PASS |
| RDS secret rotation | PENDING | RDS and its managed secret existed, but rotation was not attempted after the node-group stop condition |
| Terraform teardown | PASS | Guarded destroy completed: 0 added, 0 changed, 85 destroyed |
| Leftover verification | PASS | Terraform state is empty; the service-created RDS log group was deleted separately; no workload remains; three disabled KMS keys are in `PendingDeletion` |
| Temporary source credentials | PASS | The MFA bootstrap profile was cleared after verification; all credential fields are zero-length |

## Teardown and retained bootstrap layer

The third apply started at `09:58:17Z`. The guarded destroy plan was generated at approximately `13:36Z`; Terraform then destroyed 85 resources, and final owner-assisted log cleanup was verified at approximately `13:49Z`. The longer elapsed window includes a paused owner-interaction interval. Terraform remote workload state is empty and native lock acquisition/release succeeded.

The independent leftover check returned no project VPC, NAT gateway, EIP, EKS cluster, EC2 worker, RDS instance, EBS volume, ALB, ENI, security group, ECR repository, secret, alarm, snapshot or workload IAM role. One RDS service-created PostgreSQL log group survived Terraform because it was outside the state; the owner deleted it in CloudWatch and a subsequent API query returned no matching group. Three workload-tagged KMS keys (two from earlier attempts and one from this run) are disabled in `PendingDeletion`, scheduled for deletion on 2026-09-26. AWS enforces the waiting period; pending-deletion keys cannot be used and are not charged.

Only the intentional bootstrap layer remains: remote-state storage/locking, `careflow-deployment-role`, `careflow-platform-admin`, `careflow-github-ecr-publisher`, and the GitHub Actions OIDC provider. The long-lived IAM user's temporary MFA session was cleared locally after verification.

## Cost

The third partial stack existed for roughly 3 hours 40 minutes. No EC2 worker or ALB existed; the main billable resources were the EKS control plane, one NAT gateway and a small Single-AZ RDS instance. A conservative estimate is **under $0.75 before Free-plan credits** for this run and **under $1.25 cumulatively** across all three attempts. Billing telemetry is delayed, so these are estimates rather than invoice claims.

Sources: [AWS VPC/NAT pricing](https://aws.amazon.com/vpc/pricing/), [AWS EKS pricing](https://aws.amazon.com/eks/pricing/), [AWS KMS pricing](https://aws.amazon.com/kms/pricing/), and [KMS deletion lifecycle](https://docs.aws.amazon.com/kms/latest/developerguide/deleting-keys.html).

## Previous controlled validations

The second authorized run used the reviewed 88-create `free-plan-demo` plan. It reached an `ACTIVE` EKS control plane but stopped on exact `secretsmanager:CreateSecret` and `ec2:RunInstances` denials. Its guarded teardown destroyed 83 resources and left only two keys in `PendingDeletion`. Those denials led to the separately reviewed remediation in [`iam-remediation-review.md`](iam-remediation-review.md); they are retained as failure evidence rather than overwritten by the third run.

The earlier authorized plan contained 87 creates and used the production-target defaults. Its apply stopped safely when the account's Free plan rejected `t3.medium` workers and seven-day RDS retention. That attempt proved the initial IAM, remote-state, EKS-control-plane, stop and teardown paths. It led to the separately reviewed `free-plan-demo` profile used above; it is not presented as application-runtime success.

## Post-run IAM remediation

The two observed IAM blockers were subsequently remediated without another workload apply. CloudTrail identified `secretsmanager:CreateSecret` and `ec2:RunInstances`; the reviewed policy also includes the documented dependent `secretsmanager:TagResource`, while existing KMS metadata, EC2 tagging and scoped PassRole permissions were sufficient. The bootstrap-only update and fresh 88-create/9-read remote plan are recorded in [`iam-remediation-review.md`](iam-remediation-review.md).

The third run supplied new execution evidence for RDS managed-password provisioning and the custom launch-template path, but not for workers or application runtime. The subsequently reviewed `iam:CreateServiceLinkedRole` prerequisite is restricted to the exact `AWSServiceRoleForAmazonEKSNodegroup` ARN and `eks-nodegroup.amazonaws.com` service condition. Its IAM-only bootstrap apply, simulations, Access Analyzer result and fresh 88-create/9-read plan are recorded in [`eks-nodegroup-service-linked-role-remediation.md`](eks-nodegroup-service-linked-role-remediation.md). The separately authorized fourth run above proved that remediation and exposed the next runtime-layer blockers.

No credentials or secret values were captured or committed. Evidence contains no employer, customer or real patient data.

## Updated scores

| Role | Code/design | Executed evidence |
|---|---:|---:|
| Cloud Architect | 88/100 | 62/100 |
| Senior Cloud Engineer | 90/100 | 80/100 |
| Senior DevOps | 93/100 | 84/100 |

`Cloud Runtime Validation Score: 52/100`

Portfolio readiness: **STRONG BUT NEEDS FIXES**.

The four runs now prove the reviewed Free-plan gates, identity, remote state/locking, complete infrastructure creation, Ready private workers, RDS managed-password provisioning, custom launch-template and service-linked-role paths, initial Argo/controller bootstrap, safe runtime stop conditions and complete Terraform teardown. They do not prove the GitHub-to-RDS application path, pod security groups, ALB/TLS, application observability, cloud rollback or rotation recovery.
