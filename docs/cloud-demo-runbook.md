# Cloud Demo Runbook for the Repository Owner

This is the only supported AWS demonstration path. Stop at the end of any gate; later gates are optional. The repository never applies cloud infrastructure from CI. Commands labelled **READ-ONLY** inspect or plan. Commands labelled **BILLABLE** create or operate AWS resources.

## Session limit and cost decision

The first AWS validation is limited to **one primary region, low synthetic traffic, and eight elapsed hours from apply to verified teardown**. Use **USD 20 as the conservative maximum estimate for that controlled session**, excluding a domain purchase, AWS Support, taxes, unexpected traffic, pre-existing resources, or a configuration changed from the demo profile. This is a planning ceiling, not an AWS guarantee. Stop before apply if the AWS Pricing Calculator estimate is above USD 20 or the owner cannot afford the full amount.

Why the limit matters: standard-support EKS alone is $0.10 per cluster-hour; the NAT gateway, its public IPv4 address and processed data bill separately; workers/EBS, RDS, ALB/LCU, Secrets Manager, CloudWatch and transfer add to it. The relevant current sources are [EKS pricing](https://aws.amazon.com/eks/pricing/), [NAT gateway pricing](https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-pricing.html), [Elastic Load Balancing pricing](https://aws.amazon.com/elasticloadbalancing/pricing/), and [RDS for PostgreSQL pricing](https://aws.amazon.com/rds/postgresql/pricing/).

Before every billable gate, write down the session start time and planned teardown deadline. A budget alert is delayed and is not a hard cap.

## How to use the commands

Open the macOS **Terminal** application. Paste one code block at a time and press Return. Keep the Terminal open. Begin in the repository:

```bash
cd "<PROJECT_ROOT>"
```

When this runbook says “ask for help,” stop typing commands. Send the complete non-secret error plus the gate number to an experienced AWS engineer. Never send a password, token, Terraform state, `database.json`, secret value, or unredacted account details.

## Gate 0 — prerequisites and free local proof

**Cost/state:** local-only; no AWS access and no cloud changes.

You need Python 3, curl, Docker Desktop with its engine running, OpenSSL and Trivy. kind and kubectl are optional for the Kubernetes portion. Check them:

```bash
bash scripts/preflight.sh local
```

Rough success output starts with `CareFlow preflight (local)` and ends with `Preflight passed`. `PENDING kind` is acceptable only if you are intentionally postponing Kubernetes runtime proof. `FAIL` means stop and install/start the named tool.

Run the complete local evidence path:

```bash
bash scripts/local-demo.sh
```

Rough success output includes container tests, a successful Trivy image scan, PostgreSQL readiness, `apt-demo-persistence` surviving application and database restarts, readiness after a local password rotation, and a final evidence directory under `artifacts/runtime-evidence/`. If kind is present, it also reports a rejected broken rollout, continuous requests with zero failures, and rollback success.

Stop and ask for help if any check fails. Do not proceed to AWS merely to work around a local failure.

## Gate 1 — sandbox identity and billing protections

**Cost/state:** AWS read-only checks. Creating a Budget may have pricing above the service’s free allowance; do that deliberately in the console.

Prerequisites:

- a personal/sandbox AWS account, never an employer or customer account;
- billing-console access and an email you monitor;
- AWS CLI v2 authenticated with a short-lived SSO/role session;
- Terraform 1.11.1 or newer, kubectl, Helm 3, Git, GitHub CLI and curl;
- an experienced reviewer available before Gate 3;
- an existing domain you control only if you want browser-trusted TLS evidence.

In the AWS console, create a monthly budget with alerts at USD 10 and USD 20. In Terminal, set the intended account and region; replace the example account ID:

```bash
export EXPECTED_AWS_ACCOUNT_ID='123456789012'
export AWS_REGION='us-east-1'
export AWS_DEFAULT_REGION="$AWS_REGION"
export PROJECT_NAME='careflow-portfolio'
bash scripts/preflight.sh cloud
bash scripts/cloud-status.sh
aws freetier get-account-plan-state --query '[accountPlanType,accountPlanStatus]' --output table
```

Rough success output shows the same account ID, `us-east-1`, and read-only resource tables. AWS rejected the original `production-target` settings under its `FREE` account plan during the first controlled attempt. The profile-aware plan/apply guard now blocks `production-target` before apply; for `free-plan-demo` it verifies one-day retention and the selected instance type's live `FreeTierEligible` flag. Stop if the caller is not the sandbox account, credentials are long-lived/unexplained, the profile check fails, a table contains unknown resources, or you cannot see billing. Ask an AWS engineer to identify resources; do not delete unknown objects.

## Gate 2 — read-only Terraform plans

**Cost/state:** Terraform initialization and planning read AWS/state and write local plan artifacts; they do not create workload resources. The separately managed state bucket/lock/KMS prerequisites can already incur small charges.

An AWS administrator must supply a versioned/encrypted Terraform state bucket, access to it, an EKS admin role, and the account’s GitHub Actions OIDC provider. Copy the untracked examples:

```bash
cp infra/environments/primary/backend.hcl.example infra/environments/primary/backend.hcl
cp infra/environments/primary/terraform.tfvars.free-plan.example infra/environments/primary/terraform.tfvars
```

Open those two copied files in a plain-text editor. Replace every `REPLACE_ME`, example account ID and example IP. Keep `enable_cloud_resources = false`. Never commit either file.

Before the remote state prerequisites exist, an engineer may use `CLOUD_PLAN_BACKEND_MODE=local-review` for a zero-state architecture review. That mode creates `review-only.tfplan`, which `cloud-apply.sh` rejects. It is not deployment approval and cannot replace the final remote-state plan.

Create the no-op plan:

```bash
EXPECTED_AWS_ACCOUNT_ID="$EXPECTED_AWS_ACCOUNT_ID" bash scripts/cloud-plan.sh primary
```

Rough output ends with `No resource was created or changed.` With cloud resources disabled, stop if the plan proposes EKS, EC2, NAT, RDS, ECR or IAM workload resources.

Next, obtain an account/region-specific AWS Pricing Calculator estimate. If it is no more than USD 20 for the eight-hour session and the owner explicitly accepts it, change only this line in the untracked `terraform.tfvars`:

```hcl
enable_cloud_resources = true
```

Generate the billable deployment plan, still without applying it:

```bash
EXPECTED_AWS_ACCOUNT_ID="$EXPECTED_AWS_ACCOUNT_ID" bash scripts/cloud-plan.sh primary
less artifacts/cloud-plan/primary/cloud-demo.txt
```

Press `q` to leave `less`. An experienced engineer must review the entire plan. For `free-plan-demo`, expected categories are one VPC across three AZs, one NAT gateway, one standard-support EKS cluster, two `c7i-flex.large` workers with encrypted 20 GiB gp3 roots, one private Single-AZ RDS PostgreSQL instance with one-day retention, an immutable ECR repository, scoped IAM roles/policies and security groups. The ALB is created later by the Kubernetes controller. Use `terraform.tfvars.example` only to review the stronger `production-target`; this Free account must not apply it.

Stop on any unexplained delete/replacement, multiple NAT gateways, Multi-AZ RDS, DR resources, public database access, a broad EKS API CIDR, an extended-support Kubernetes fee, or a calculator estimate over USD 20.

## Gate 3 — infrastructure deployment

**Cost/state:** **BILLABLE AND STATE-CHANGING.** EKS, NAT, EC2/EBS and RDS begin billing as they are created. Start the eight-hour clock now.

Required before pasting: owner authorization, engineer approval of `cloud-demo.txt`, USD 20 budget tolerance, and at least three uninterrupted hours remaining for deploy/evidence/destroy.

Apply only the saved reviewed plan:

```bash
EXPECTED_AWS_ACCOUNT_ID="$EXPECTED_AWS_ACCOUNT_ID" AWS_REGION="$AWS_REGION" \
  bash scripts/cloud-apply.sh artifacts/cloud-plan/primary/cloud-demo.tfplan
```

The wrapper prints an account-and-region phrase. Type it exactly. Terraform then applies without a second interactive prompt. Rough success output ends with `Apply complete` and non-secret output names.

Connect to the new cluster:

```bash
CLUSTER_NAME="$(terraform -chdir=infra/environments/primary output -raw cluster_name)"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
kubectl config current-context
kubectl get nodes
```

Expected: the context names the sandbox cluster and two nodes become `Ready`. Stop if the context points elsewhere, apply fails, nodes are not Ready after 20 minutes, spend/alarms are unexpected, or fewer than two hours remain for teardown.

## Gate 4 — application, TLS and runtime evidence

**Cost/state:** **BILLABLE.** The existing infrastructure keeps billing; creating the Ingress adds an ALB and public IPv4/LCU usage.

If you control a domain, request and DNS-validate an ACM certificate in the same region. Otherwise omit `ACM_CERTIFICATE_ARN`: the default manifest creates an HTTP listener so ALB routing can still be proved, while trusted public TLS remains explicitly **PENDING**. Do not buy a domain for this exercise and do not claim `curl -k` as certificate validation.

Generate the cluster-specific Argo root Application under ignored `.runtime/`. This injects AWS identifiers during Argo rendering; it never edits the public templates:

```bash
export GITHUB_REPOSITORY='OWNER/enterprise-multiregion-cloud-platform'
python3 scripts/configure-cloud-manifests.py \
  --github-repository "$GITHUB_REPOSITORY" \
  --region "$AWS_REGION" \
  --cluster-name "$CLUSTER_NAME" \
  --vpc-id "$(terraform -chdir=infra/environments/primary output -raw vpc_id)" \
  --secret-arn "$(terraform -chdir=infra/environments/primary output -raw database_master_secret_arn)" \
  --workload-security-group "$(terraform -chdir=infra/environments/primary output -raw careflow_workload_security_group_id)" \
  --careflow-role-arn "$(terraform -chdir=infra/environments/primary output -raw careflow_secrets_role_arn)" \
  --load-balancer-role-arn "$(terraform -chdir=infra/environments/primary output -raw load_balancer_controller_role_arn)" \
  --ecr-repository "$(terraform -chdir=infra/environments/primary output -raw ecr_repository_url)"
git diff --exit-code -- platform k8s/overlays/production
git check-ignore .runtime/cloud-manifests/root-application.yaml
python3 scripts/check-public-repo-identifiers.py
```

If a validated certificate is available, export its ARN and repeat the configuration command with `--acm-certificate-arn "$ACM_CERTIFICATE_ARN"`; the ignored runtime root adds the trusted-TLS annotations. Without it, HTTP proof remains enabled and trusted TLS remains PENDING. Never stage `.runtime/` or replace tracked placeholders with live AWS identifiers.

Configure the GitHub environment `portfolio-publish` with `AWS_REGION`, `AWS_PUBLISH_ROLE_ARN`, and `ECR_REPOSITORY_URL` as variables, enable required approval, then manually run **Publish CareFlow Image**. It must test and scan the built image, assume AWS via OIDC, push to ECR, and open a digest-only promotion PR. The private ECR URL is injected by the ignored runtime root, not committed. Review and merge the PR; never use long-lived AWS keys or a mutable image tag.

Bootstrap GitOps and inspect conditions without printing secrets:

```bash
bash platform/bootstrap/bootstrap-argocd.sh
kubectl -n argocd get applications
kubectl -n careflow get externalsecret,secretstore,deployment,pods,service,ingress
kubectl -n careflow rollout status deployment/careflow-api --timeout=10m
kubectl -n observability get pods
kubectl -n careflow get servicemonitor,prometheusrule
```

Without a domain, prove the ALB HTTP listener and routing through its generated DNS name. With validated DNS/TLS, paste:

```bash
export CAREFLOW_HOSTNAME='careflow.example.com'
curl --fail --head "http://$CAREFLOW_HOSTNAME/healthz"
curl --fail "https://$CAREFLOW_HOSTNAME/readyz"
curl --fail "https://$CAREFLOW_HOSTNAME/api/v1/appointments"
```

Expected: HTTP redirects to HTTPS, readiness says the database is `ok`, appointments say `synthetic: true`, controller applications are healthy, and monitoring objects/pods exist. Stop on secret-sync errors, certificate mismatch, missing digest, non-synthetic data, pod crash loops, unexpected public exposure, or any request that requires printing a Secret.

## Gate 5 — rotation and controlled failure

**Cost/state:** **BILLABLE AND DISRUPTIVE TO THE DEMO.** Existing resources continue billing. This gate intentionally creates application failure signals but must not touch real users.

Only proceed while the system serves synthetic data and at least 90 minutes remain before the teardown deadline. Follow `docs/rollout-rollback.md` to generate continuous traffic, submit the deliberately unready release through GitOps, prove old replicas still serve, and revert the Git commit. Fill the evidence template with real redacted timestamps/output.

For secret rotation, an experienced operator triggers the RDS-managed secret rotation. Observe only External Secret conditions, pod readiness and API readiness for at least one five-minute refresh interval. Do not run `kubectl get secret -o yaml`, print `database.json`, or paste Terraform state.

Expected: broken pods never become Ready, continuous traffic shows no failures, the Git revert returns Argo to `Synced/Healthy`, the mounted secret refreshes, and readiness recovers without a source-code change. Stop if old replicas fail, rollback exceeds ten minutes, rotation causes sustained outage, credentials appear anywhere, or teardown time is approaching.

## Gate 6 — deliberate teardown and leftovers

**Cost/state:** **DESTRUCTIVE.** This removes the demo. Some retained snapshots, logs, secrets or prerequisite state storage can continue billing until separately reviewed.

First delete the Argo workload and wait for controller-owned ALB resources to disappear:

```bash
kubectl -n argocd delete application careflow-api --wait=true
kubectl -n careflow get ingress
aws elbv2 describe-load-balancers --region "$AWS_REGION" \
  --query 'LoadBalancers[?contains(LoadBalancerName, `careflow`)].[LoadBalancerName,State.Code]' \
  --output table
```

Expected: no CareFlow Ingress and an empty ALB table. Do not run Terraform destroy until that is true. Confirm the untracked tfvars still describe the deployed environment and `database_deletion_protection = false`, then generate/review/apply a destroy plan through the deliberate wrapper:

```bash
EXPECTED_AWS_ACCOUNT_ID="$EXPECTED_AWS_ACCOUNT_ID" AWS_REGION="$AWS_REGION" \
  bash scripts/cloud-destroy.sh
```

Type the exact destroy phrase only after reading the displayed plan. Rough success output ends with `Destroy complete`.

Run the read-only post-check:

```bash
EXPECTED_AWS_ACCOUNT_ID="$EXPECTED_AWS_ACCOUNT_ID" AWS_REGION="$AWS_REGION" \
  PROJECT_NAME="$PROJECT_NAME" bash scripts/cloud-teardown-check.sh
```

Every project table should be empty. Also use the console in every visited region to check EC2 instances, EBS volumes/snapshots, Elastic IPs/public IPv4, NAT gateways, ALBs, EKS/node groups, RDS/backups/snapshots, ECR, Secrets Manager, CloudWatch logs/alarms, IAM/OIDC resources, tagged KMS keys and controller-created security groups. The state bucket/KMS/lock objects are prerequisites and should be retained or removed only by their owner. Follow `docs/aws-leftover-checklist.md`.

If anything remains, keep the budget enabled, record its ARN/ID without secrets, and ask an AWS engineer to confirm ownership before deletion. Re-run the check after cleanup and review Billing for several days.

## Universal stop conditions

Stop immediately if the account or region differs, any credential/secret is displayed, a plan contains unexplained replacement/deletion, the price estimate exceeds USD 20, a budget alert fires, the deadline leaves less than 90 minutes for teardown, Terraform state cannot be read, Kubernetes points to a non-sandbox cluster, real data appears, or teardown leaves an unidentified resource.
