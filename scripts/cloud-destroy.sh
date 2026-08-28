#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tf_dir="$repo_root/infra/environments/primary"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-}"
region="${AWS_REGION:-us-east-1}"

command -v aws >/dev/null || { echo "AWS CLI is required; nothing was destroyed."; exit 1; }
command -v terraform >/dev/null || { echo "Terraform is required; nothing was destroyed."; exit 1; }
[[ "$expected_account" =~ ^[0-9]{12}$ ]] || { echo "Set EXPECTED_AWS_ACCOUNT_ID first."; exit 1; }
[[ -f "$tf_dir/backend.hcl" && -f "$tf_dir/terraform.tfvars" ]] || {
  echo "backend.hcl and terraform.tfvars are required for deliberate teardown."
  exit 1
}
actual_account="$(aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || {
  echo "Blocked: AWS identity is account $actual_account, expected $expected_account."
  exit 1
}
caller_arn="$(aws sts get-caller-identity --query Arn --output text)"
[[ "$caller_arn" == "arn:aws:sts::$expected_account:assumed-role/careflow-deployment-role/"* ]] || {
  echo "Blocked: teardown requires the short-lived careflow-deployment-role session."
  exit 1
}
configured_region="$(sed -nE 's/^aws_region[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$tf_dir/terraform.tfvars")"
[[ -n "$configured_region" && "$configured_region" == "$region" ]] || {
  echo "Blocked: AWS_REGION=$region does not match terraform.tfvars aws_region=$configured_region."
  exit 1
}

evidence_dir="${EVIDENCE_DIR:-$repo_root/artifacts/cloud-plan/primary}"
mkdir -p "$evidence_dir"
destroy_plan="$evidence_dir/destroy.tfplan"
terraform -chdir="$tf_dir" plan -destroy -input=false -var-file=terraform.tfvars -out="$destroy_plan"
terraform -chdir="$tf_dir" show -no-color "$destroy_plan"

phrase="DESTROY CAREFLOW IN $expected_account IN $region"
echo "DESTRUCTIVE: review the plan above, then type exactly: $phrase"
IFS= read -r confirmation </dev/tty
[[ "$confirmation" == "$phrase" ]] || { echo "Confirmation did not match; nothing was destroyed."; exit 1; }
terraform -chdir="$tf_dir" apply -input=false "$destroy_plan"
