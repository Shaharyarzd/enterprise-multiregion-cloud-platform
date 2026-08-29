# Fourth-Run Runtime Remediation Review (Historical Checkpoint)

This review follows the safely stopped and fully torn-down fourth controlled AWS validation. It preserves the pre-final-run checkpoint; the later final result is in [`aws-runtime-evidence.md`](aws-runtime-evidence.md).

## Narrow remediations

1. The workload-created EKS cluster role now receives AWS-managed `AmazonEKSVPCResourceController`, the documented prerequisite for security groups for pods. No bootstrap/deployment-role permission changes are involved.
2. AWS Load Balancer Controller chart values now receive `region: us-east-1` and a dynamically substituted Terraform VPC ID. Worker IMDS remains token-required with hop limit 1.
3. Argo applications use explicit dependency waves: External Secrets `-50`, AWS Load Balancer Controller `-40`, Kyverno `-30`, Kyverno policies `-29`, metrics-server `-20`, observability `-10`, and CareFlow `10`.
4. Bootstrap waits for all workers to be Ready and for the EKS VPC resource-controller trunk-ENI label. It uses condition-based waits, not arbitrary sleeps.
5. Production ingress defaults to HTTP for no-domain ALB routing proof. A disabled optional patch adds an ACM certificate, HTTP-to-HTTPS redirect, and the TLS 1.2/1.3 policy.

## IAM security assessment

`AmazonEKSVPCResourceController` permits the EKS control plane to manage ENIs and secondary IP addresses. Several EC2 network-interface APIs do not support a narrower resource ARN and therefore use `Resource: *`; `ec2:CreateNetworkInterfacePermission` is condition-limited to the AWS EKS VPC resource-controller owner tag. The policy grants no IAM role creation, policy attachment, `iam:PassRole`, secret access, general instance launch, or credential operations. The blast radius is network-interface lifecycle/IP assignment through the EKS cluster service role. The remaining risk is AWS-managed-policy evolution, which should be reviewed periodically.

This is a workload EKS cluster-role attachment, not account bootstrap IAM. Consequently the expected bootstrap plan is **No changes**, and no bootstrap apply is appropriate.

## Local verification

- repository regression invariants: PASS
- Python and shell syntax: PASS
- Terraform primary, DR and bootstrap validation: PASS
- Terraform formatting: PASS
- Kustomize production and Argo rendering: PASS
- kubeconform native-resource validation: PASS; expected CRDs skipped
- all pinned Helm chart renders: PASS
- GitHub Actions lint: PASS
- no-domain and ACM-enabled manifest configuration tests: PASS
- capacity review: PASS for the bounded two-node demo profile

## Remaining external gates

- A fresh remote-state `free-plan-demo` plan ran under `assumed-role/careflow-deployment-role/careflow-validation`: **89 creates, 9 reads, 0 updates, 0 deletes and 0 replacements**. Native S3 locking was acquired and released, and the workload state was empty. The one-create increase from the fourth-run plan is exactly `AmazonEKSVPCResourceController` on `careflow-portfolio-primary-cluster`.
- The account bootstrap plan returned **No changes**. Because this remediation belongs to the workload-created EKS cluster role, no bootstrap apply was run.
- Access Analyzer returned zero findings for the live AWS-managed policy document. IAM simulation allowed the required ENI permission/actions with the EKS owner-tag context and implicitly denied the permission with a wrong owner tag, `iam:CreateServiceLinkedRole`, `iam:PassRole`, and `ec2:RunInstances`.
- GitHub publication is blocked because the local directory is not a Git repository, GitHub CLI is signed out, and the named remote is empty. Initialize/commit/push and configure the `portfolio-publish` environment only through an owner-authenticated GitHub session.
- Trusted public TLS is optional and remains PENDING until the owner supplies a validated domain and ACM certificate.
- Runtime proof requires a new explicit owner authorization. Never reuse the fourth-run plan and never apply merely because this remediation is ready.

No CareFlow workload infrastructure was created during this remediation work.

Classification: **READY WITH BLOCKERS**. Runtime Remediation Confidence: **96/100**. Cloud Deployment Readiness Score: **92/100**. The infrastructure/controller remediation is ready for validation, but an end-to-end fifth run should wait until the owner authenticates GitHub and the expected repository/publication environment can be verified. The prior Cloud Runtime Validation Score remains **52/100**; static remediation does not increase executed runtime evidence.
