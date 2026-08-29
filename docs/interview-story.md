# Interview Story

## 60-second version

“I built a production-oriented AWS reference platform for a fictional regulated SaaS workload, then validated one complete low-cost primary-region slice. Terraform created the reviewed VPC, EKS, private RDS and security boundaries. GitHub Actions used OIDC—no static AWS key—to test and scan an image, publish an immutable ECR digest and promote it through a pull request. Argo deployed two CareFlow replicas with External Secrets and Security Groups for Pods. The application passed PostgreSQL CRUD and restart persistence through an ALB. During a deliberately broken release, all 145 requests succeeded against the old replicas; a Git revert and Argo restored the prior digest in 153 seconds. I then destroyed the full workload and verified Terraform state returned to zero. I explicitly separate that cost-optimized proof from the stronger Multi-AZ, TLS, audit and DR controls a real regulated production platform still needs.”

## Senior-level discussion points

### Why two profiles?

The `free-plan-demo` preserves the security and delivery path while using two `c7i-flex.large` workers, one NAT and Single-AZ RDS for a short teardown-oriented run. The production target retains stronger HA, retention and edge controls. Cost reduction is explicit rather than disguised as production architecture.

### How was IAM handled?

GitHub uses repository/environment-scoped OIDC; humans use MFA-backed role sessions. Deployment permissions evolved from exact runtime denials and provider behavior. Broad managed administrator policies were not used, and temporary cleanup permission was scoped to two orphan ENIs and removed immediately.

### How are public GitOps and private AWS identifiers reconciled?

Git contains portable desired state and the promoted digest. An ignored runtime generator patches the live VPC ID, RDS secret ARN, IAM role ARNs and private ECR repository into Argo's source composition. Guards reject those identifiers from tracked or staged files.

### What did the failure drill prove?

A bad readiness revision entered through GitOps while continuous ALB traffic ran. Kubernetes retained two Ready old replicas and served 145/145 requests. Recovery used Git revert → merge → Argo reconciliation, restoring the previous digest and full health in 153 seconds.

### What remains incomplete?

One Prometheus target timed out cross-node, Kyverno retained Argo drift despite enforcing policy, managed-secret rotation recovery was not authorized, trusted TLS lacked a controlled domain/certificate, and multi-region recovery remains unexecuted.

### What changes for real healthcare production?

Do not claim automatic compliance. Add governance, data classification, contracts, access review, immutable audit retention, vulnerability/patch operations, split database identities, production TLS/edge controls, backup validation and measured regional recovery/failback.
