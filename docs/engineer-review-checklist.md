# Experienced Engineer Judgment Review

This checklist is for architectural judgment after automated checks and runtime evidence have been supplied separately. Answer briefly with “accept,” “change,” or “needs evidence,” plus the reason. It intentionally excludes questions that a test, linter, plan, scan, or live command can answer objectively.

## Production realism and boundaries

1. Is a warm-standby regional design proportionate to CareFlow’s stated recovery objectives, or does it spend complexity before the workload justifies it?
2. Is EKS a defensible platform choice for this service and team, compared with a smaller managed container platform, once operational ownership is included?
3. Does the boundary between Terraform-owned AWS infrastructure, Argo-owned Kubernetes resources, and one-time bootstrap work remain understandable during incident recovery?
4. Is using the RDS-managed master principal for both migrations and runtime acceptable for a short portfolio demonstration, and what is the minimum credible migration/runtime split for production?
5. Should External Secrets use the application service account as designed, or should the controller and workload have separate identities despite the added machinery?

## Security and blast radius

6. Are the trust boundaries among GitHub OIDC, ECR publication, Argo promotion, IRSA, pod security groups, and RDS narrow enough for the claimed senior-level design?
7. Does the demo’s public ALB and restricted public EKS endpoint present an honest and proportionate exposure model, or should either interface be private for the intended audience?
8. Is omitting WAF defensible for a short-lived synthetic demo, and what traffic or threat threshold should reverse that decision?
9. Are the evidence-redaction rules sufficient for a public portfolio, considering account IDs, ARNs, repository names, hostnames, log metadata, screenshots, and Terraform output?

## Scaling and dependency behavior

10. Is a five-connection pool per pod compatible with a small RDS class at the HPA maximum, and where should the connection budget be enforced as the system grows?
11. Should load-balancer health, Kubernetes readiness, and database readiness share the same dependency sensitivity, or do they need different failure semantics to avoid a cascading outage?
12. Do the two-replica rollout policy, disruption budget, and topology rules express the right availability promise for both the low-cost demo and a real multi-AZ workload?

## Resilience and operational trust

13. Does a five-minute secret refresh plus connection-pool replacement provide an acceptable rotation recovery window, and which failure modes still require a pod restart or operator action?
14. Are the documented rollback and warm-standby procedures simple enough to execute under pressure without creating split ownership, stale data, or accidental failback?
15. Which one design choice or missing piece most limits your willingness to trust this platform in production, and what evidence would change your judgment?
