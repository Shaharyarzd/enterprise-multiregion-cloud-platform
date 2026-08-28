# Security Threat Model

## Assets

- application container images
- deployment manifests
- cloud control-plane permissions
- database content
- Terraform state
- CI identity

## Key threats and controls

| Threat | Example control |
|---|---|
| Credential leakage | No committed secrets; GitHub OIDC and IRSA short-lived identity |
| Container privilege escalation | non-root, read-only root FS, dropped capabilities, Kyverno |
| Lateral movement | default-deny NetworkPolicy, segmented subnets, and a pod-specific RDS security group |
| Public database exposure | private DB subnets; no public accessibility |
| Mutable artifact substitution | immutable ECR tags and production digest reference; reject `latest` |
| IaC drift | Terraform plan/review plus Git ownership |
| Unsafe automated changes | cloud apply is manual; PR checks are read-only |
| Single-AZ outage | multi-AZ network and workload placement |
| Region outage | documented recovery runbook; cross-region data and DNS controls remain planned |

## Implemented controls versus residual risk

- **Control plane:** the EKS API is private by default; public access requires explicitly trusted non-global CIDRs. An explicit IAM role, not the provisioning identity, receives cluster-admin access.
- **Auditability:** EKS API, audit, authenticator, controller-manager and scheduler logs are enabled with 30-day retention. Organization-level CloudTrail, immutable archival, alerts and access-review evidence are not implemented.
- **Workloads:** restricted Pod Security, tokenless ServiceAccount, non-root execution, read-only root filesystem, dropped capabilities, seccomp and default-deny policies are implemented. Runtime detection and controller installation are not.
- **Database:** private placement, encrypted storage, forced server TLS, RDS-managed rotation, External Secrets delivery, application-side hostname validation, and a pod-specific security group are implemented in code. The master database principal remains too privileged for a long-lived production workload; split migrator/runtime roles are documented next work.
- **Supply chain:** third-party Actions are SHA-pinned and Trivy gates source/IaC/image findings. GitHub OIDC publishes to immutable ECR and promotion changes only a digest through a pull request. SBOM retention, provenance, signing and admission verification remain planned after cloud proof.
- **Egress:** the upstream EKS module's all-protocol node egress was replaced by VPC-internal traffic, DNS, time sync and internet TCP/443. Trivy cannot distinguish this from all-protocol unrestricted egress, so a path-scoped, documented exception expires on 2026-11-30 pending an egress-proxy/VPC-endpoint decision.
- **Ingress:** ALB IP targets, dependency health checking, ACM input, HTTP redirect, and a modern TLS policy are implemented in code. WAF is deliberately deferred for cost/threat justification; ALB access-log storage and runtime evidence are pending cloud execution.

## Trust boundaries

1. Internet to load balancer.
2. Load balancer to Kubernetes workloads.
3. Workloads to data services.
4. CI to cloud control plane.
5. Human operators to cloud and Git repositories.
6. Terraform state backend to AWS control planes and operators.

## Highest-risk attack paths

1. A compromised CareFlow pod can use the privileged RDS master principal after reading its mounted secret. Network and IAM scope are narrow, but the database privilege split is still required for a persistent production design.
2. A compromised GitHub workflow on the protected main branch could publish an image or open a promotion PR; environment approval, branch protection, SHA pins, and review are required outside this repository.
3. A malicious-but-scanned digest could be promoted because signing/attestation verification is not yet implemented.
4. A primary-region event can remove application, data and potentially state access because cross-region recovery dependencies are not implemented or tested.

## Compliance note

This repository demonstrates *security engineering patterns*. It does not claim that deploying it produces a compliant healthcare environment. Formal compliance depends on organizational controls, policies, evidence, contracts, logging, key management, access review, vulnerability management, incident response, and many other controls beyond source code.
