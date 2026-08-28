#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
bootstrap_dir="$repo_root/bootstrap/aws"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-}"
region="${AWS_REGION:-us-east-1}"

echo "READ-ONLY TERRAFORM OPERATION: this validates and plans bootstrap prerequisites. It never applies."
command -v aws >/dev/null || { echo "AWS CLI is required."; exit 1; }
command -v terraform >/dev/null || { echo "Terraform is required."; exit 1; }
[[ "$expected_account" =~ ^[0-9]{12}$ ]] || { echo "Set EXPECTED_AWS_ACCOUNT_ID to the sandbox account ID."; exit 1; }
session_token_present=false
if [[ -n "${AWS_SESSION_TOKEN:-}" ]]; then
  session_token_present=true
elif [[ -n "${AWS_PROFILE:-}" ]] && [[ -n "$(aws configure get aws_session_token --profile "$AWS_PROFILE" 2>/dev/null || true)" ]]; then
  session_token_present=true
fi
[[ "$session_token_present" == true ]] || { echo "Blocked: an MFA-backed temporary session is required."; exit 1; }
unset session_token_present
[[ -f "$bootstrap_dir/terraform.tfvars" ]] || { echo "Copy and complete bootstrap/aws/terraform.tfvars.example first."; exit 1; }

actual_account="$(aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || {
  echo "Blocked: current session is account $actual_account, expected $expected_account."
  exit 1
}
rg -q "account_id[[:space:]]*=[[:space:]]*\"$expected_account\"" "$bootstrap_dir/terraform.tfvars" || {
  echo "Blocked: bootstrap terraform.tfvars does not contain the expected account ID."
  exit 1
}
if rg -n '123456789012|REPLACE.ME' "$bootstrap_dir/terraform.tfvars"; then
  echo "Blocked: replace every example value printed above."
  exit 1
fi

terraform -chdir="$bootstrap_dir" init -input=false -lockfile=readonly
terraform -chdir="$bootstrap_dir" validate
terraform -chdir="$bootstrap_dir" plan \
  -input=false \
  -var-file=terraform.tfvars \
  -out=bootstrap.tfplan
terraform -chdir="$bootstrap_dir" show -no-color bootstrap.tfplan > "$bootstrap_dir/bootstrap-plan.txt"

echo "Bootstrap plan saved to bootstrap/aws/bootstrap-plan.txt. No AWS resource was created or changed."
echo "Stop here until the plan has been reviewed and the owner authorizes bootstrap creation."
