#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
echo "READ-ONLY CLOUD OPERATION: no AWS resource will be created, changed, or deleted."
command -v aws >/dev/null || { echo "AWS CLI is required"; exit 1; }

expected_account="${EXPECTED_AWS_ACCOUNT_ID:-}"
[[ "$expected_account" =~ ^[0-9]{12}$ ]] || {
  echo "Set EXPECTED_AWS_ACCOUNT_ID to the 12-digit sandbox account."
  exit 1
}
actual_account="$(aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || {
  echo "Blocked: AWS identity is account $actual_account, expected sandbox $expected_account."
  exit 1
}

region="${AWS_REGION:-us-east-1}"
project="${PROJECT_NAME:-careflow-portfolio}"
caller_arn="$(aws sts get-caller-identity --query Arn --output text)"
printf 'Account: %.4s****%.4s\n' "$actual_account" "${actual_account:8:4}"
case "$caller_arn" in
  *:assumed-role/*) echo "Identity: short-lived assumed role" ;;
  *:user/*) echo "Identity: IAM user (read-only checks only; do not apply)" ;;
  *) echo "Identity: unclassified" ;;
esac
echo "Region:  $region"
AWS_REGION="$region" PROJECT_NAME="$project" bash "$repo_root/scripts/check-aws-leftovers.sh"
