# AWS Demo Teardown and Leftover Checklist

Use this only after an explicitly authorized CareFlow sandbox deployment. Never delete an unknown or untagged resource merely to make a table empty.

## Before Terraform destroy

- Record the account, region, session deadline and reviewed remote state path.
- Delete the CareFlow Argo CD Application/Ingress first.
- Wait until the ALB, listeners, target groups and controller-created security groups are gone.
- Confirm `database_deletion_protection = false`, `database_skip_final_snapshot = true` and `ecr_force_delete = true` describe this ephemeral demo.
- Confirm the remote backend is readable and the tfvars still match the deployed account/region.
- Generate and read the complete destroy plan. Stop on any resource outside the CareFlow project.

## Destroy

- Use only `scripts/cloud-destroy.sh` with the exact account and region.
- Type its full confirmation phrase only after reviewing the saved destroy plan.
- Do not interrupt a running destroy unless continuing would affect an unrelated resource.

## Automated read-only verification

Run `scripts/cloud-teardown-check.sh`. Every CareFlow table must be empty or explicitly explained. It checks:

- VPC, EC2 instances, EKS cluster/node group and launch-related resources;
- NAT gateway, Elastic IP, EBS volumes, network interfaces and security groups;
- RDS instance and manual/automated snapshots;
- ECR repository/images and Secrets Manager secret;
- CloudWatch log groups and alarms;
- CareFlow IAM roles and tagged KMS keys;
- ALB resources whose names contain CareFlow.

## Manual verification

- Check `us-east-1` and every other region visited during the session.
- Check EC2 Auto Scaling groups and launch templates if node-group deletion failed.
- Check ALB listeners, target groups, ENIs and controller-created security groups.
- Check RDS retained automated backups and snapshots.
- Check IAM policies, roles, EKS access entries and EKS-created OIDC providers.
- A Terraform-created KMS key normally remains `PendingDeletion` for its deletion window; record it. AWS states that keys scheduled for deletion do not incur the monthly key-storage charge.
- Retain the versioned state bucket, lock object history and optional state KMS key only if their sandbox owner accepts them. They are prerequisites, not workload resources.
- Keep billing alerts enabled and review Cost Explorer/Billing for several days because charges arrive late.

If any leftover is unidentified, stop, record its non-secret ID and ownership tags, and obtain owner confirmation before deletion.
