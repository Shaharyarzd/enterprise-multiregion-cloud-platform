#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
profile="${2:-}"
retention_days="${3:-}"
shift 3 || true
instance_types=("$@")

command -v aws >/dev/null || { echo "Blocked: AWS CLI is required for account-plan validation."; exit 1; }
[[ "$mode" == "plan" || "$mode" == "apply" ]] || { echo "Usage: check-account-plan-profile.sh [plan|apply] PROFILE RETENTION_DAYS INSTANCE_TYPE..."; exit 2; }
[[ "$profile" == "production-target" || "$profile" == "free-plan-demo" ]] || { echo "Blocked: unknown deployment profile '$profile'."; exit 1; }
[[ "$retention_days" =~ ^[0-9]+$ ]] || { echo "Blocked: RDS retention must be an integer."; exit 1; }
(( ${#instance_types[@]} > 0 )) || { echo "Blocked: at least one worker instance type is required."; exit 1; }

account_plan_type="$(aws freetier get-account-plan-state --query accountPlanType --output text)" || {
  echo "Blocked: unable to verify the AWS account plan."
  exit 1
}
echo "AWS account plan: $account_plan_type; Terraform profile: $profile"

if [[ "$account_plan_type" != "FREE" ]]; then
  echo "Account-plan/profile check passed."
  exit 0
fi

if [[ "$profile" == "production-target" ]]; then
  if [[ "$mode" == "apply" ]]; then
    echo "Blocked: production-target cannot be applied to an AWS FREE account plan. Use a newly reviewed free-plan-demo plan or upgrade the sandbox account plan."
    exit 1
  fi
  echo "Planning warning: production-target may be reviewed on this FREE account, but the apply guard will reject it."
  exit 0
fi

[[ "$retention_days" == "1" ]] || {
  echo "Blocked: the executed AWS FREE account rejected seven-day RDS retention; free-plan-demo requires the one-day account-constrained value."
  exit 1
}

for instance_type in "${instance_types[@]}"; do
  eligible="$(aws ec2 describe-instance-types \
    --instance-types "$instance_type" \
    --query 'InstanceTypes[0].FreeTierEligible' \
    --output text)"
  [[ "$eligible" == "True" ]] || {
    echo "Blocked: worker type $instance_type is not Free-tier eligible in this account."
    exit 1
  }
done

echo "FREE account compatibility passed: worker types are eligible and RDS retention is one day."
