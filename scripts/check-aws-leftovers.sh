#!/usr/bin/env bash
set -euo pipefail

command -v aws >/dev/null || { echo "AWS CLI is required"; exit 1; }

region="${AWS_REGION:-us-east-1}"
project="${PROJECT_NAME:-careflow-portfolio}"
[[ "$project" =~ ^[a-z0-9-]+$ ]] || { echo "PROJECT_NAME must contain lowercase letters, digits, and hyphens only"; exit 1; }

echo "READ-ONLY leftover-resource check"
account="$(aws sts get-caller-identity --query Account --output text)"
caller_arn="$(aws sts get-caller-identity --query Arn --output text)"
printf 'Account: %.4s****%.4s\n' "$account" "${account:8:4}"
case "$caller_arn" in
  *:assumed-role/*) echo "Identity: short-lived assumed role" ;;
  *:user/*) echo "Identity: IAM user" ;;
  *) echo "Identity: unclassified" ;;
esac

echo "VPCs tagged for the project:"
aws ec2 describe-vpcs --region "$region" --filters "Name=tag:Project,Values=${project}" \
  --query 'Vpcs[].[VpcId,State,CidrBlock]' --output table

echo "EC2 instances tagged for the project:"
aws ec2 describe-instances --region "$region" --filters "Name=tag:Project,Values=${project}" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType]' --output table

echo "EKS clusters containing the project name:"
aws eks list-clusters --region "$region" --query "clusters[?contains(@, '${project}')]" --output table

echo "RDS instances containing the project name:"
aws rds describe-db-instances --region "$region" \
  --query "DBInstances[?contains(DBInstanceIdentifier, '${project}')].[DBInstanceIdentifier,DBInstanceStatus]" \
  --output table

echo "NAT gateways tagged for the project:"
aws ec2 describe-nat-gateways --region "$region" \
  --filter "Name=tag:Project,Values=${project}" "Name=state,Values=pending,available,deleting" \
  --query 'NatGateways[].[NatGatewayId,State,VpcId]' --output table

echo "Load balancers containing the project or CareFlow name:"
aws elbv2 describe-load-balancers --region "$region" \
  --query "LoadBalancers[?contains(LoadBalancerName, 'careflow')].[LoadBalancerName,State.Code,DNSName]" \
  --output table

echo "EBS volumes tagged for the project:"
aws ec2 describe-volumes --region "$region" \
  --filters "Name=tag:Project,Values=${project}" \
  --query 'Volumes[].[VolumeId,Size,State]' --output table

echo "Elastic IPs tagged for the project:"
aws ec2 describe-addresses --region "$region" --filters "Name=tag:Project,Values=${project}" \
  --query 'Addresses[].[AllocationId,AssociationId,PublicIp]' --output table

echo "Security groups tagged for the project:"
aws ec2 describe-security-groups --region "$region" --filters "Name=tag:Project,Values=${project}" \
  --query 'SecurityGroups[].[GroupId,GroupName,VpcId]' --output table

echo "Network interfaces tagged for the project:"
aws ec2 describe-network-interfaces --region "$region" --filters "Name=tag:Project,Values=${project}" \
  --query 'NetworkInterfaces[].[NetworkInterfaceId,Status,Description]' --output table

echo "ECR repositories containing the project name:"
aws ecr describe-repositories --region "$region" \
  --query "repositories[?contains(repositoryName, '${project}')].[repositoryName,repositoryUri]" \
  --output table

echo "Secrets containing the project name (a retained RDS secret can continue to exist):"
aws secretsmanager list-secrets --region "$region" \
  --query "SecretList[?contains(Name, '${project}')].[Name,DeletedDate]" --output table

echo "CloudWatch log groups containing the project name:"
aws logs describe-log-groups --region "$region" --log-group-name-pattern "$project" \
  --query 'logGroups[].[logGroupName,storedBytes,retentionInDays]' --output table

echo "CloudWatch alarms containing the project name:"
aws cloudwatch describe-alarms --region "$region" --alarm-name-prefix "$project" \
  --query 'MetricAlarms[].[AlarmName,StateValue]' --output table

echo "RDS snapshots containing the project name:"
aws rds describe-db-snapshots --region "$region" \
  --query "DBSnapshots[?contains(DBSnapshotIdentifier, '${project}')].[DBSnapshotIdentifier,Status,SnapshotType]" \
  --output table

echo "IAM roles containing the project name:"
aws iam list-roles --query "Roles[?contains(RoleName, '${project}')].[RoleName,Arn]" --output table

echo "KMS keys tagged for the project (PendingDeletion is expected briefly after destroy):"
aws resourcegroupstaggingapi get-resources --region "$region" --resource-type-filters kms:key \
  --tag-filters "Key=Project,Values=${project}" --query 'ResourceTagMappingList[].ResourceARN' --output table

echo "No resources were changed. Empty tables are the expected post-destroy result."
