# Principal Architecture and DevOps Review

> Historical Milestone 1 review. Milestone 2 resolves the primary application/RDS, node-wide database reachability, artifact publication, GitOps bootstrap, ALB/TLS, and focused observability gaps in code. See `docs/milestone-2-review.md` for the current score and remaining evidence gaps.

Review date: 2026-08-26

## Executive assessment

This is a credible **foundation portfolio**, not a production-ready regulated platform. Its strongest material is the explicit separation of low-cost demo choices from production safeguards, readable Terraform modules, hardened workload baseline, and safety-first CI. Its central weakness is the gap between the target diagram and a working end-to-end path: there is no published production image, installed platform controller, ingress/TLS path, database-consuming workload, cross-region data mechanism or DNS failover.

The repository is now syntactically valid and substantially safer than it was at the start of this review. Scores below reflect the post-remediation repository and do not treat documentation as runtime evidence.

| Score | Result | Rationale |
|---|---:|---|
| Overall architecture | **68/100** | Good regional foundations and trade-offs; target service path and DR are incomplete |
| Cloud Architect portfolio | **74/100** | Strong failure-domain and cost reasoning, weakened by unproven RTO/RPO and target-state breadth |
| Senior Cloud Engineer portfolio | **73/100** | Valid modular IaC and secure defaults, but no authenticated plan/apply or operational integration evidence |
| Senior DevOps portfolio | **79/100** | Strong workload/CI baseline; artifact publication, GitOps bootstrap, promotion and rollback evidence are missing |

## Architecture review

| Area | Assessment | Senior-level concern |
|---|---|---|
| VPC/subnets | Three AZs with distinct public, worker and database subnets is sensible. | One NAT is deliberately cheap but is an AZ dependency and can cause cross-AZ charges. VPC flow logs and endpoints are absent. |
| EKS | Private workers, private API default, explicit access entry, control-plane logging, restricted node egress, managed nodes and current add-ons are sound. | One general-purpose node group and two desired nodes do not prove three-AZ resilience. No node autoscaler, platform bootstrap or workload-specific AWS role exists. |
| Ingress | Public subnets are correctly tagged for an ALB target design. | No controller, Ingress, TLS certificate, ALB logging, WAF or rate limiting exists; the AWS application is not reachable. |
| PostgreSQL/RDS | Private, encrypted gp3 storage, forced TLS, managed password, backups and deletion settings are good module defaults. | The demo profile is single-AZ, seven-day backup retention and skip-final-snapshot. The API does not use RDS. Node-SG ingress grants every node workload network reachability. |
| IAM/secrets | Long-lived CI credentials are absent; cluster admin is an explicit IAM role. | There are no controller/workload IAM roles, secret delivery mechanism or application rotation test. A managed master secret alone is not an end-to-end secret design. |
| Kubernetes | Restricted Pod Security, tokenless ServiceAccount, probes, requests/limits, PDB, HPA, rollout limits, zone spread and default deny form a strong baseline. | Production ingress and database egress are intentionally not solved. NetworkPolicy enforcement depends on the CNI and is not runtime-tested. HPA depends on metrics-server, which is not installed by this repository. |
| Observability | Metrics endpoint, ServiceMonitor and control-plane logs show the intended integration. | No deployed metrics/log stack, application alerts, SLOs, audit archive, paging route or dashboard evidence exists. `/readyz` proves only the process, not dependencies. |
| GitOps | Argo CD desired-state separation is appropriate. | The repo URL is a placeholder; controller bootstrap, projects, credentials, notifications and multi-region ownership are absent. |
| Scalability/resilience | Stateless pods can scale and disruption behavior is specified. | Node capacity does not automatically scale. Database connection limits/pooling and application dependency behavior are untested. |
| State | Separate S3 backend declarations and committed provider locks are correct improvements. | Backend resources and their least-privilege/KMS/replication controls are not provisioned here. Module versions require exact pins because Terraform lock files do not lock registry modules. |

## Critical problems

These are critical for the stated regulated-enterprise target, though they do not make the local portfolio demo unsafe:

1. **Regional recovery is not executable.** There is no DR database source, application/controller bootstrap, routable endpoint or DNS failover. The 60-minute RTO and 15-minute RPO are unproven objectives.
2. **No production traffic path exists.** ALB, Ingress, TLS, WAF and Route 53 appear only in target documentation.
3. **No deployable production artifact path exists.** CI scans an image but does not publish a digest, sign it, update GitOps state or prove rollback. The production manifest still names the local demo image.
4. **The data architecture is disconnected.** Terraform creates RDS, but the application neither connects to it nor demonstrates identity, secret rotation, TLS verification, migrations, pooling, backup restore or failover behavior.

## High-priority improvements

1. Complete one vertical slice before adding more platforms: publish to ECR/GHCR by digest, deploy through Argo CD, expose with TLS/ALB, and capture health/rollback evidence.
2. Connect a synthetic persistence path to RDS using a dedicated Pod Identity/IRSA role and External Secrets or an equivalent rotation-aware mechanism. Restrict network access with Security Groups for Pods or a justified alternative.
3. Choose and implement the DR database mechanism. Capture restore/promotion automation and a timed drill before retaining the stated RTO/RPO.
4. Bootstrap Argo CD, Kyverno, metrics-server and observability declaratively, including controller IAM, version pins and recovery ownership.
5. Add ALB/WAF/Route 53 only with access logs, TLS policy, health criteria, failover safeguards and cost estimates.
6. Add VPC flow logs or explicitly document a lower-cost audit alternative; centralize CloudTrail/audit logs with retention and tamper-resistance appropriate to the fictional data class.
7. Configure repository branch protection outside code: required CI/security checks, review requirements, CODEOWNERS for infrastructure/security paths, signed or verified commits if organizationally justified, and restricted workflow changes.

## Nice-to-have improvements

- use Graviton worker nodes after verifying all images are multi-architecture;
- add application latency/error metrics and a small SLO/alert rule rather than a broad observability stack;
- test PDB/topology behavior by draining a node and simulating an AZ-capacity loss;
- generate an SBOM and provenance at image publication time, then introduce Cosign verification at admission;
- add a dependency-update bot for pinned Actions/modules with required validation;
- add progressive delivery only after ordinary rollout and rollback are proven;
- replace placeholder diagrams with a small “implemented now” diagram next to the target diagram.

## Threat-model conclusions

The strongest protections are at the pod boundary and EKS administrative endpoint. The largest remaining blast-radius issue is the shared node security group used for RDS access. Supply-chain controls now catch high/critical findings and mutable workflow dependencies, but there is no signed artifact promotion chain. Audit coverage is limited to EKS control-plane logs; cloud, load-balancer, database and application security events have no implemented immutable destination. A time-bounded Trivy exception covers only the HTTPS-to-anywhere node rule because the scanner does not model its port restriction; it expires on 2026-11-30 and should drive an egress proxy or VPC endpoint decision.

Kyverno is appropriate here because the repository already has a concrete policy need. Trivy is appropriate because it covers the actual Docker/IaC path. Checkov would currently duplicate much of that IaC coverage, so it was not added for résumé breadth. Cosign should be added only when an image publication and admission-verification path exists.

## Disaster recovery classification

| Classification | Capabilities |
|---|---|
| **IMPLEMENTED** | Primary regional RDS backups; separate Terraform roots; infrastructure and workload declarations |
| **PARTIALLY IMPLEMENTED** | Optional DR VPC/EKS; separate backend design; GitOps and observability definitions |
| **DOCUMENTED ONLY** | Warm-standby operations, application recovery sequence, controlled failback, 60-minute RTO and 15-minute RPO |
| **PLANNED** | Cross-region database source/restore, image availability, controller bootstrap, DNS health failover, backup validation and measured drill |

## Cost review

EKS control planes, NAT gateways, worker EC2, RDS and log ingestion dominate the current design. At published US-region example rates, an EKS control plane alone is about $73/month ([AWS EKS pricing](https://aws.amazon.com/eks/pricing/)) and a NAT gateway plus its public IPv4 address is roughly $36.50/month before processing ([AWS VPC pricing](https://aws.amazon.com/vpc/pricing/)). Two workers, EBS and RDS place an always-on primary well above $100/month. Per-AZ NAT, Multi-AZ RDS, ALB/WAF and a second region can quickly multiply that baseline.

The local kind path is therefore the correct default. Cloud evidence should be time-boxed in a sandbox account with budgets/alerts, one primary region, explicit acknowledgement, a reviewed plan, and teardown verification. The cheap profile must never be described as production HA.

## Portfolio-quality review

The repository demonstrates senior reasoning when it names trade-offs and implementation gaps. It looks superficial when it lists many planned products without an operating path. Recruiters will place more weight on a short captured plan, an image digest, a GitOps reconciliation result, an alert screenshot/export and a measured recovery drill than on additional roadmap nouns. The next iteration should deepen evidence rather than broaden the tool list.

## Validation evidence

The review used Terraform 1.15.9, kubectl 1.36.4/Kustomize 5.8.1, kubeconform 0.8.0, Trivy 0.74.0, Docker client 29.7.2/server 29.5.2 and kind 0.32.0. No AWS credentials or billable resources were used.

- `terraform fmt -check -recursive infra`: passed after remediating invalid one-line blocks.
- `terraform init -backend=false -input=false` and `terraform validate`: passed for primary and DR roots.
- `kubectl kustomize` plus strict kubeconform 1.36 schemas: local and readiness-failure overlays passed 12/12; production passed 11 native resources with 5 controller CRDs skipped.
- platform CRDs: parsed; custom-resource schemas were skipped because controller schemas are not vendored.
- `python3 scripts/verify.py`: passed.
- `python3 -m unittest discover ...`: 13 tests passed on the host and in the Docker test target.
- shell scripts: `bash -n` passed.
- Trivy repository misconfiguration/secret scan: project-owned configuration had no unaccepted high/critical finding. One scanner finding against intentional TCP/443 node egress is narrowed in code and covered by a path-scoped exception expiring 2026-11-30.
- The rebuilt runtime image passed the Trivy HIGH/CRITICAL vulnerability and secret gate with zero findings.
- The local kind deployment, deliberate failed-readiness rollout, continuous-traffic check and rollback passed; authenticated AWS plan/apply remains unexecuted because cloud creation was neither required nor authorized.
- Git status/diff: unavailable because this supplied directory is not a Git working tree.
