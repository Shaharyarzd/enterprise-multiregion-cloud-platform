# Public Portfolio Evidence Checklist

Use only evidence produced by a real run. Keep raw material private until every item is reviewed. Never publish credentials, Terraform state, secret contents, personal data, or employer/customer identifiers.

| Evidence item | What it proves | Why a recruiter cares | Public-safe? | Required redaction/review |
|---|---|---|---|---|
| Unit-test transcript | API, persistence, migration, readiness and rotation logic behave under controlled tests | Shows the implementation is executable, not diagram-only | Yes | Remove absolute home paths and environment details |
| Runtime image build log | The production target resolves and builds from the committed Dockerfile | Demonstrates artifact reproducibility | Yes | Remove private registry/cache URLs and hostnames |
| Trivy scan of the built image | The exact candidate was checked for high/critical vulnerabilities and secrets | Connects security policy to the shipped artifact | Yes | Review package inventory; never publish discovered secrets |
| Local PostgreSQL readiness/API output | The service migrates a real database and serves explicitly synthetic records | Proves the central application/data path | Yes | Confirm every record uses `*-demo-*`; omit generated password and secret file |
| Persistence-after-restart output | Newly inserted synthetic data survives an application restart | Distinguishes real persistence from a hard-coded response | Yes | Publish the synthetic ID and timestamps only |
| Local password-rotation result | The app notices a changed file and recreates database connections | Shows secret lifecycle thinking beyond injection | Yes | Show readiness before/after; never show old/new password or JSON secret |
| Metrics excerpt | Request, latency and dependency measurements are exposed | Shows operability is part of the application contract | Yes | Use a short excerpt; redact hostname/IP if desired |
| kind workload snapshot | Manifests schedule and become Ready on a real Kubernetes API | Demonstrates runtime integration, probes and resources | Yes | Remove local usernames, absolute paths and unrelated cluster contexts |
| Continuous-traffic failure summary | An unready replacement is rejected while old replicas serve | Makes zero-downtime rollout claims measurable | Yes | Publish totals/failures and times; no pod logs containing environment data |
| Rollback summary | The previous release is restored and readiness/API recover | Shows recovery is exercised, not merely documented | Yes | Redact commit SHAs if repository is private |
| Terraform plan summary | The expected AWS topology and blast radius were reviewed before apply | Demonstrates disciplined change planning | Conditionally | Never publish plan/state wholesale; redact account IDs, ARNs, IPs, bucket names and tags |
| AWS identity/region proof | The run occurred in an isolated intended account/region | Shows scope control | Conditionally | Mask account ID except last four digits; omit principal/session names |
| ECR immutable digest | The tested artifact was published and promoted by digest | Shows supply-chain continuity | Yes | Redact account ID in registry URL if desired; digest itself is safe |
| Argo application status | Git desired state reconciled into the cluster | Demonstrates GitOps ownership and dependency ordering | Conditionally | Redact repository URL, account IDs, cluster endpoint and private app details |
| ALB HTTPS response/certificate view | Public traffic uses redirect plus a hostname-valid certificate | Shows practical edge/TLS completion | Conditionally | Use a portfolio hostname; remove account/zone IDs and unrelated browser tabs |
| External Secret conditions | Secret reference and refresh reconcile without exposing the value | Shows workload identity and rotation integration | Conditionally | Conditions only; never publish Secret YAML, state, environment dump or mounted file |
| RDS rotation timeline | Managed rotation and application reconnection recover within a measured interval | Demonstrates lifecycle/resilience evidence | Conditionally | Times/status only; redact ARN, username, endpoints, request IDs and all values |
| Prometheus target/rule/alert proof | Metrics are scraped and an operational condition is evaluated/delivered | Shows monitoring closes the delivery loop | Conditionally | Redact receiver/contact data, internal URLs and tokens |
| AWS failure/rollback timeline | Old replicas serve, failed promotion is reverted, Argo returns healthy | Demonstrates controlled production-style recovery | Conditionally | Remove account/cluster/repository identifiers and secret-bearing logs |
| Terraform destroy result | Managed infrastructure was deliberately removed | Shows cost and lifecycle ownership | Conditionally | Publish resource categories/counts, not raw state or identifiers |
| Empty leftover checks plus billing follow-up | Common chargeable resources were checked after destroy | Signals responsible cloud use | Conditionally | Mask account ID, region-specific private names and billing/account details |

## Publication rule

An item may enter the portfolio only when its command, UTC timestamp, tool version, exit result and redaction review are recorded. Configuration screenshots may be labelled “design,” but they must never be labelled “runtime proof.” A `PENDING` item remains private and unclaimed.
