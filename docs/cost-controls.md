# Cost Controls

Cost is an architectural constraint in this portfolio, not just a billing concern.

## Default posture

- Local Kubernetes is the default development environment: cloud cost ₹0.
- No CI workflow runs `terraform apply`.
- Primary Terraform creates zero workload resources unless `enable_cloud_resources=true`.
- DR infrastructure is opt-in.
- NAT gateways, EKS control planes, workers/EBS, RDS/backups, ALB, ECR, Secrets Manager, logs, public IPv4, and cross-region traffic are considered chargeable resources.

## Order-of-magnitude review (2026-08-26)

This is a guardrail, not a quote; region, taxes, traffic and service changes matter. In common US regions:

- one standard-support EKS control plane is about **$73/month** at $0.10/hour ([AWS EKS pricing](https://aws.amazon.com/eks/pricing/));
- one NAT gateway is roughly **$36.50/month** before data processing when the $0.045 gateway and $0.005 public IPv4 hourly charges are combined ([AWS VPC pricing](https://aws.amazon.com/vpc/pricing/));
- worker compute, encrypted EBS volumes and a small RDS instance add the next largest baseline; the production target uses `t3.medium`, while the constrained Free-plan validation uses eligible `c7i-flex.large` workers for sufficient pod density;
- CloudWatch logs, NAT data processing, cross-AZ traffic, snapshots and public IPv4 addresses grow with use;
- enabling three NAT gateways, Multi-AZ RDS or a second regional cell materially increases the total.

A primary demo should therefore be expected to cost **well over $100/month if left running continuously**, even before ALB/WAF/DR are added. Use the AWS Pricing Calculator for an account- and region-specific estimate before applying.

## Safe cloud-demo pattern

1. Use a sandbox AWS account with billing alerts.
2. Plan first.
3. Deploy only the primary region for routine demos.
4. Use the smallest practical managed-node instance types.
5. Create DR only for a time-boxed recovery exercise.
6. Delete the Argo-managed Ingress before Terraform destroy so the controller removes the ALB and its security groups.
7. Destroy resources after evidence/screenshots are captured.
8. Run `scripts/check-aws-leftovers.sh` and verify the console for load balancers, NAT gateways, EBS volumes, snapshots, secrets, logs and Elastic IPs.
9. Remember that deletion protection can intentionally block destroy; inspect the plan and disable it through reviewed configuration only when decommissioning.

## Cheaper evidence paths

- Use kind for application/Kubernetes evidence and Terraform `init`/`validate` for routine review.
- For a cloud exercise, deploy one region, one NAT gateway and single-AZ RDS for a short, explicitly labelled non-production window.
- Prefer free S3/Dynamo-style gateway endpoints where they replace NAT data paths; price interface endpoints because several can cost more than one low-traffic NAT gateway.
- Capture plan output, timestamps and teardown verification rather than keeping EKS online for a portfolio link.
- WAF remains off because a synthetic, time-boxed demo has no traffic evidence justifying its continuing web-ACL/rule/request costs.
- Do not create the DR root until a time-boxed recovery drill is ready to run.

## Resources that may outlive testing

- final/manual RDS snapshots and retained automated backups;
- EBS volumes left `available` after a failed controller/PVC cleanup;
- ALBs and controller-created security groups if the Ingress was not deleted first;
- CloudWatch log groups;
- ECR repositories/images if destroy did not complete;
- Secrets Manager secrets in a recovery/deletion window;
- the intentionally retained Terraform state bucket/KMS/lock prerequisites.

Follow `docs/cloud-demo-runbook.md`; the read-only checker is a convenience, not proof that every AWS region and service is empty.

## Why not optimize for the absolute cheapest architecture?

A portfolio for senior cloud roles should show the engineer understands production patterns *and* their cost. The repository therefore documents expensive choices, keeps them optional, and distinguishes a reference production topology from a low-cost demo topology.
