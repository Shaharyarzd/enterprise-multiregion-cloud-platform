#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
echo "POST-TEARDOWN READ-ONLY CHECK. Empty tables are required; this script deletes nothing."
bash "$repo_root/scripts/cloud-status.sh"

echo
echo "Manual console checks still required: every visited region, EC2 instances, EBS volumes/snapshots,"
echo "Elastic IP/public IPv4, ALBs, EKS/node groups, RDS/backups/snapshots, ECR, Secrets Manager,"
echo "CloudWatch logs/alarms, IAM/OIDC resources, tagged KMS keys, and controller-created security groups."
echo "Follow docs/aws-leftover-checklist.md; retain state prerequisites only with their owner's approval."
echo "Keep the budget alert enabled for several days because billing data is delayed."
