# AWS Bootstrap Runbook

This runbook prepares identity and Terraform state only. It does **not** authorize or apply the main CareFlow infrastructure. The current repository value is **OWNER INPUT REQUIRED**; do not guess it.

## Resulting identity model

The permanent access key remains attached to `careflow-portfolio-admin` and retains AWS-managed `ReadOnlyAccess`. A small caller policy permits only `sts:AssumeRole` into `careflow-deployment-role`, and both the caller policy and role trust require MFA. AWS CLI then obtains temporary credentials for at most 3,600 seconds. Terraform plan/apply and teardown use the deployment role.

For Kubernetes administration, the deployment role assumes `careflow-platform-admin`. The main Terraform root grants that role `AmazonEKSClusterAdminPolicy` through an explicit EKS access entry. The platform-admin IAM policy itself permits only `eks:DescribeCluster`; Kubernetes authorization comes from the access entry. `enable_cluster_creator_admin_permissions` remains false so the identity that creates the cluster does not silently become a permanent cluster administrator.

The deployment role can create and remove only the service families represented by the reviewed plan: VPC/EC2 networking, EKS, RDS, project-prefixed IAM resources, one ECR path, tagged KMS resources, EKS logs, RDS managed-secret metadata, and the exact S3 state/lock objects. Some EC2 network relationship APIs cannot reliably be constrained by tags during creation or deletion; their explicitly enumerated actions use `Resource = "*"`. In an otherwise empty personal sandbox this is the narrowest practical Terraform policy, but it could change unrelated networking in the same account. Stop if unrelated resources appear.

## Stage A — No-cost preparation

### A1. Open the correct terminal and confirm the sandbox

Open Terminal on the Mac, change to this repository, and paste:

```bash
cd "<PROJECT_ROOT>"
aws sts get-caller-identity --profile careflow-preflight
aws configure get region --profile careflow-preflight
```

This reads identity metadata only, changes nothing in AWS, and costs nothing. Success shows the IAM user ARN ending in `user/careflow-portfolio-admin`, the expected sandbox account, and `us-east-1`. Stop if the account, user, or region is different.

### A2. Give the IAM user its own MFA device

Root MFA does not satisfy the deployment-role condition. Check the IAM user's device:

```bash
aws iam list-mfa-devices --profile careflow-preflight --user-name careflow-portfolio-admin --output table
```

This is read-only and free. Success shows one serial number. If the table is empty:

1. Sign in to the AWS console as `careflow-portfolio-admin`, not as root.
2. Open the account menu → **Security credentials**.
3. Under **Multi-factor authentication (MFA)** choose **Assign MFA device**.
4. Choose an authenticator app, scan the QR code, enter two consecutive codes, and finish.
5. Run the command again. Stop until one MFA serial appears.

Assigning MFA changes the user security configuration but creates no billable resource.

### A3. Prepare local bootstrap inputs

Retrieve the account ID without copying credentials:

```bash
export EXPECTED_AWS_ACCOUNT_ID="$(aws sts get-caller-identity --profile careflow-preflight --query Account --output text)"
cp bootstrap/aws/terraform.tfvars.example bootstrap/aws/terraform.tfvars
```

The first command is read-only; the second creates an ignored local file only. Neither changes AWS or costs money. Open `bootstrap/aws/terraform.tfvars` in a text editor and replace the example account ID in `account_id` and `state_bucket_name` with the displayed 12-digit sandbox ID. The intended bucket pattern is `careflow-tfstate-ACCOUNT_ID-us-east-1`.

For `github_repository`:

- if the exact live GitHub URL is known, enter only its `owner/repository` portion;
- otherwise leave it `null`. This intentionally omits both the GitHub OIDC provider and publisher role. Their status remains **OWNER INPUT REQUIRED**, and the main cloud plan stays blocked.

Do not put access keys, secret keys, MFA codes, passwords, or tokens in this file.

### A4. Validate files locally

Paste:

```bash
terraform fmt -check -recursive bootstrap/aws infra
jq empty bootstrap/aws/bootstrap-executor-policy.json
bash -n scripts/start-bootstrap-session.sh scripts/aws-bootstrap-plan.sh scripts/aws-bootstrap-apply.sh
python3 scripts/verify.py
```

These commands inspect local files only, change no AWS resource, and cost nothing. Success means every command exits without an error and the final line starts with `Verification passed`. Stop on any error.

## Stage B — Owner authorization needed

The read-only IAM user cannot bootstrap itself. Root is used only to attach one temporary, narrowly scoped inline policy; no root access key is created.

1. Sign in to the AWS console as the root user and complete root MFA.
2. Open **IAM** → **Users** → `careflow-portfolio-admin` → **Permissions**.
3. Choose **Add permissions** → **Create inline policy** → **JSON**.
4. In the local repository, open `bootstrap/aws/bootstrap-executor-policy.json`, choose all, and copy it. Paste it into the console editor. Do not write or alter the JSON.
5. Choose **Next**, name it `careflow-temporary-bootstrap-executor`, and create it.
6. Sign out of the root session immediately.

This changes IAM authorization but creates no billable resource. The policy permits only the three named CareFlow roles, the named user's caller policy, the GitHub OIDC provider, and an S3 bucket beginning `careflow-tfstate-`; every allowed action also requires an MFA-authenticated session. It is not `AdministratorAccess` and it is removed immediately after bootstrap. Stop if AWS reports broader permissions than those names.

Back in Terminal, create an in-memory one-hour MFA session:

```bash
source scripts/start-bootstrap-session.sh
aws sts get-caller-identity
```

The script prompts privately for the six-digit IAM-user MFA code, obtains temporary STS credentials, and exports them only into the current shell. It does not print secrets, write credentials to the repository, create resources, or incur cost. Success says the temporary MFA session is active; the identity output still names `careflow-portfolio-admin`. Stop if it names another user/account or the script says MFA is missing.

If an automation process cannot share that shell, run `bash scripts/create-bootstrap-profile.sh` instead. It stores the same one-hour session in the local `careflow-bootstrap-session` AWS profile without printing credentials. For an explicitly authorized time-boxed validation that needs a longer teardown window, set `BOOTSTRAP_SESSION_DURATION_SECONDS` to a reviewed value between 3,600 and 129,600 seconds; the deployment-role credentials themselves remain limited to one hour and can be refreshed only while the MFA source session is valid. Use `AWS_PROFILE=careflow-bootstrap-session` for bootstrap commands, then immediately run `bash scripts/clear-bootstrap-profile.sh` after bootstrap or validation.

## Stage C — Bootstrap creation

### C1. Create and review a plan

In the same Terminal window, paste:

```bash
EXPECTED_AWS_ACCOUNT_ID="$EXPECTED_AWS_ACCOUNT_ID" AWS_REGION=us-east-1 bash scripts/aws-bootstrap-plan.sh
```

This initializes Terraform, refreshes only the bootstrap objects, and saves a plan. Planning changes no AWS resource and is not billable, although provider download uses internet access. Success ends with `No AWS resource was created or changed` and writes `bootstrap/aws/bootstrap-plan.txt`. Stop if the plan contains anything except the state-bucket controls, the two operating roles, the user caller policy, and—only when a real repository was supplied—the GitHub provider/publisher role.

### C2. Apply only after a separate owner authorization

The following command is intentionally **not authorized by preparation of this runbook**. Run it only in a future session after the owner reviews `bootstrap-plan.txt` and explicitly authorizes creation:

```bash
EXPECTED_AWS_ACCOUNT_ID="$EXPECTED_AWS_ACCOUNT_ID" AWS_REGION=us-east-1 bash scripts/aws-bootstrap-apply.sh
```

This changes AWS. It creates only bootstrap IAM/OIDC prerequisites and the S3 state bucket; IAM/OIDC are free and tiny S3 state storage is negligibly priced. It never invokes the main CareFlow Terraform root. Success prints Terraform outputs and `Bootstrap finished`; stop on any error and do not retry blindly.

Retain the ignored `bootstrap/aws/terraform.tfstate` on the Mac's encrypted disk. It is needed to manage these persistent prerequisites and may contain infrastructure metadata. Never commit or share it.

### C3. Immediately remove temporary authorization

After a successful bootstrap, sign in as root with MFA and open **IAM** → **Users** → `careflow-portfolio-admin` → **Permissions**. Expand `careflow-temporary-bootstrap-executor` and choose **Remove**. Sign out of root. This changes IAM, costs nothing, and leaves the user with only `ReadOnlyAccess` plus the Terraform-managed `careflow-assume-deployment-role` inline policy.

Then clear the bootstrap session from the current Terminal:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

This changes only the local shell. Success is silent.

## Stage D — Verification

Use the permanent read-only profile to verify names and bucket controls:

```bash
aws iam get-role --profile careflow-preflight --role-name careflow-deployment-role --query 'Role.[Arn,MaxSessionDuration]' --output table
aws iam get-role --profile careflow-preflight --role-name careflow-platform-admin --query 'Role.[Arn,MaxSessionDuration]' --output table
aws s3api get-bucket-versioning --profile careflow-preflight --bucket "careflow-tfstate-${EXPECTED_AWS_ACCOUNT_ID}-us-east-1"
aws s3api get-public-access-block --profile careflow-preflight --bucket "careflow-tfstate-${EXPECTED_AWS_ACCOUNT_ID}-us-east-1"
aws s3api get-bucket-encryption --profile careflow-preflight --bucket "careflow-tfstate-${EXPECTED_AWS_ACCOUNT_ID}-us-east-1"
```

These are read-only and normally cost nothing beyond negligible S3 request pricing. Success shows 3,600-second role sessions, versioning `Enabled`, all four public-access values `true`, and `AES256`. Stop if any control differs.

If `github_repository` was set, also run:

```bash
aws iam get-open-id-connect-provider --profile careflow-preflight --open-id-connect-provider-arn "arn:aws:iam::${EXPECTED_AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
aws iam get-role --profile careflow-preflight --role-name careflow-github-ecr-publisher --query 'Role.Arn' --output text
```

Success shows audience `sts.amazonaws.com` and the publisher role ARN. In GitHub, configure the `portfolio-publish` environment so only `main` can deploy, then add environment variables `AWS_REGION=us-east-1` and `AWS_PUBLISH_ROLE_ARN` from the bootstrap output. AWS trust uses the exact environment-form subject `repo:OWNER/REPOSITORY:environment:portfolio-publish`; the workflow trigger and GitHub environment rule enforce `main`. No GitHub AWS access key is created.

To display the publisher output without exposing credentials, run `terraform -chdir=bootstrap/aws output github_publisher_role_arn`. This reads local bootstrap state only.

## Stage E — Switch to temporary assumed-role identities

Get the IAM-user MFA serial, then create local AWS CLI profile settings. These commands change only `~/.aws/config`, never AWS, and contain no secret keys:

```bash
export CAREFLOW_MFA_ARN="$(aws iam list-mfa-devices --profile careflow-preflight --user-name careflow-portfolio-admin --query 'MFADevices[0].SerialNumber' --output text)"
aws configure set profile.careflow-deployment.role_arn "arn:aws:iam::${EXPECTED_AWS_ACCOUNT_ID}:role/careflow-deployment-role"
aws configure set profile.careflow-deployment.source_profile careflow-preflight
aws configure set profile.careflow-deployment.mfa_serial "$CAREFLOW_MFA_ARN"
aws configure set profile.careflow-deployment.role_session_name careflow-owner
aws configure set profile.careflow-deployment.duration_seconds 3600
aws configure set profile.careflow-deployment.region us-east-1
aws configure set profile.careflow-platform-admin.role_arn "arn:aws:iam::${EXPECTED_AWS_ACCOUNT_ID}:role/careflow-platform-admin"
aws configure set profile.careflow-platform-admin.source_profile careflow-deployment
aws configure set profile.careflow-platform-admin.role_session_name careflow-kubectl
aws configure set profile.careflow-platform-admin.region us-east-1
```

Verify the deployment role:

```bash
aws sts get-caller-identity --profile careflow-deployment
```

The CLI prompts for MFA and then caches short-lived role credentials. Success shows an ARN containing `assumed-role/careflow-deployment-role/`; this is the required identity for future main Terraform plan/apply and teardown. Stop if the ARN contains `user/`.

Only after the EKS cluster exists, configure `kubectl` with the separate identity:

```bash
aws eks update-kubeconfig --profile careflow-platform-admin --region us-east-1 --name careflow-portfolio-primary --alias careflow-portfolio-primary
kubectl config current-context
```

`update-kubeconfig` changes only the local kubeconfig and calls read-only EKS APIs; it creates no AWS resource and costs nothing. Success shows the alias. Do not run it before the cluster exists.

For the primary backend, copy `bootstrap/aws/backend-primary.hcl.example` to ignored `infra/environments/primary/backend.hcl`, replace only the bucket value with the bootstrap output, and retain `use_lockfile = true`. SSE-S3 avoids the recurring charge and policy lifecycle of a customer-managed KMS key; S3 still encrypts state at rest. A dedicated KMS key would add key-policy and recovery complexity without a compelling benefit for this short synthetic sandbox. DynamoDB is not required for native S3 locking.

Also copy `infra/environments/primary/terraform.tfvars.example` to the ignored `terraform.tfvars` and set the four bootstrap outputs/owner values: the platform-admin ARN, exact GitHub repository, GitHub OIDC provider ARN, and GitHub publisher role ARN. Leave `enable_cloud_resources = false`. This is local preparation only and keeps the main plan blocked until every prerequisite is real and reviewed.

## Access-key end-of-demo lifecycle

The permanent key is never copied into Terraform, scripts, GitHub, or repository files. It stays read-only and can request only the intended MFA-gated deployment role. After the workload has been destroyed, leftovers have been checked, and no further role sessions are needed:

1. Sign in to AWS as `careflow-portfolio-admin` with MFA.
2. Open **Security credentials** → **Access keys**.
3. Choose the active key → **Deactivate**. Verify read-only scripts are no longer needed for 24 hours.
4. Return to the same page and choose **Delete**, enter the requested confirmation, and finish.
5. Remove the matching local entry from `~/.aws/credentials`; never paste it into a cleanup command or ticket.

Deactivation/deletion changes authentication but costs nothing. Do not delete the key before workload teardown and verification unless another tested access path exists. The S3 state bucket and bootstrap roles may remain after the eight-hour workload; [IAM and STS have no additional charge](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html) and the OIDC provider has no separate line-item charge. [S3 has no minimum charge and bills storage/requests](https://aws.amazon.com/s3/pricing/); a few small versioned state objects in S3 Standard should therefore remain far below $0.01/month, with negligible request charges. Noncurrent versions expire after 90 days. Unexpected data, access logging, replication, or retained main workload resources would change that estimate.

## Stop conditions

Stop immediately if the identity/account differs, IAM-user MFA is absent, the real GitHub repository is unknown but OIDC resources appear, a plan includes main VPC/EKS/RDS resources, the temporary policy resembles administrator access, or any command requests a permanent deployment access key. This runbook never authorizes the main CareFlow apply.
