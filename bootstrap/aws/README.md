# AWS account bootstrap

This independent Terraform root prepares only the prerequisites needed by the primary CareFlow root:

- a versioned, private, bucket-owner-enforced SSE-S3 state bucket with TLS-only/object-role-only policies and 90-day expiry of noncurrent versions;
- `careflow-deployment-role`, assumable only by `careflow-portfolio-admin` with MFA;
- `careflow-platform-admin`, assumable only from the deployment role;
- the IAM user's narrowly scoped caller policy;
- optionally, the account GitHub OIDC provider and `careflow-github-ecr-publisher` role.

`github_repository` deliberately defaults to `null`. The OIDC resources are omitted until the owner supplies the exact real `owner/repository`, immutable owner ID, and immutable repository ID. Trust uses GitHub's exact immutable repository/environment subject and `aud=sts.amazonaws.com`; no repository identity is inferred and no wildcard subject is accepted.

Bootstrap uses local Terraform state because the S3 backend does not exist before the first bootstrap apply. The ignored `terraform.tfstate` must be retained on an encrypted device. The long-lived platform state uses the S3 backend instead. Do not destroy this bootstrap root while the workload or remote state still exists; the bucket also has `prevent_destroy`.

The deployment policy is service- and project-scoped to the resources in the reviewed 89-create plan. Several EC2 network relationship and create/delete APIs do not consistently support request/resource-tag authorization, so those enumerated actions require `Resource = "*"`. KMS and supported creation paths require the `Project=careflow-portfolio` tag, IAM resources use a `careflow-portfolio-*` prefix, ECR is limited to one repository path, and S3 is limited to the primary state and lock objects. This is a sandbox deployment role, not an account administrator role.

Do not execute this root from ordinary permanent-key credentials. Follow [the owner runbook](../../docs/aws-bootstrap-runbook.md).
