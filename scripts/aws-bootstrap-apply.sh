#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
bootstrap_dir="$repo_root/bootstrap/aws"
plan_file="$bootstrap_dir/bootstrap.tfplan"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-}"
region="${AWS_REGION:-us-east-1}"

echo "STATE-CHANGING BOOTSTRAP ONLY: this does not apply the main CareFlow infrastructure."
command -v aws >/dev/null || { echo "AWS CLI is required; nothing was applied."; exit 1; }
command -v terraform >/dev/null || { echo "Terraform is required; nothing was applied."; exit 1; }
[[ "$expected_account" =~ ^[0-9]{12}$ ]] || { echo "Set EXPECTED_AWS_ACCOUNT_ID first; nothing was applied."; exit 1; }
session_token_present=false
if [[ -n "${AWS_SESSION_TOKEN:-}" ]]; then
  session_token_present=true
elif [[ -n "${AWS_PROFILE:-}" ]] && [[ -n "$(aws configure get aws_session_token --profile "$AWS_PROFILE" 2>/dev/null || true)" ]]; then
  session_token_present=true
fi
[[ "$session_token_present" == true ]] || { echo "Blocked: an MFA-backed temporary session is required; nothing was applied."; exit 1; }
unset session_token_present
[[ -f "$plan_file" ]] || { echo "Reviewed bootstrap plan not found; nothing was applied."; exit 1; }

actual_account="$(aws sts get-caller-identity --query Account --output text)"
caller_arn="$(aws sts get-caller-identity --query Arn --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Wrong account; nothing was applied."; exit 1; }
[[ "$caller_arn" == "arn:aws:iam::$expected_account:user/careflow-portfolio-admin" ]] || {
  echo "Blocked: bootstrap requires the MFA session for the named IAM user; nothing was applied."
  exit 1
}

phrase="CREATE CAREFLOW BOOTSTRAP IN $expected_account IN $region"
echo "This creates only the S3 state bucket and named IAM/OIDC prerequisites."
echo "Type exactly: $phrase"
IFS= read -r confirmation </dev/tty
[[ "$confirmation" == "$phrase" ]] || { echo "Confirmation did not match; nothing was applied."; exit 1; }

terraform -chdir="$bootstrap_dir" apply -input=false "$plan_file"

echo "Bootstrap finished. Remove the temporary inline executor policy in IAM now."
echo "Then run: unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN"
