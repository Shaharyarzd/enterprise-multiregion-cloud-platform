#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
plan_file="${1:-$repo_root/artifacts/cloud-plan/primary/cloud-demo.tfplan}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-}"
region="${AWS_REGION:-us-east-1}"

command -v aws >/dev/null || { echo "AWS CLI is required; nothing was applied."; exit 1; }
command -v terraform >/dev/null || { echo "Terraform is required; nothing was applied."; exit 1; }
command -v jq >/dev/null || { echo "jq is required; nothing was applied."; exit 1; }
python3 "$repo_root/scripts/verify.py"
[[ "$expected_account" =~ ^[0-9]{12}$ ]] || { echo "Set EXPECTED_AWS_ACCOUNT_ID first."; exit 1; }
[[ -f "$plan_file" ]] || { echo "Reviewed plan file not found: $plan_file"; exit 1; }
[[ "$(basename "$plan_file")" == "cloud-demo.tfplan" ]] || {
  echo "Blocked: only a remote-backend cloud-demo.tfplan is apply-eligible; local review plans can never be applied."
  exit 1
}
plan_file="$(cd "$(dirname "$plan_file")" && pwd)/$(basename "$plan_file")"
actual_account="$(aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || {
  echo "Blocked: AWS identity is account $actual_account, expected $expected_account."
  exit 1
}
caller_arn="$(aws sts get-caller-identity --query Arn --output text)"
[[ "$caller_arn" == "arn:aws:sts::$expected_account:assumed-role/careflow-deployment-role/"* ]] || {
  echo "Blocked: apply requires the short-lived careflow-deployment-role session."
  exit 1
}
plan_metadata="$(terraform -chdir="$repo_root/infra/environments/primary" show -json "$plan_file" | jq -c '{profile:.variables.deployment_profile.value,retention:.variables.database_backup_retention_days.value,node_types:.variables.node_instance_types.value}')"
plan_profile="$(jq -r '.profile' <<<"$plan_metadata")"
plan_retention_days="$(jq -r '.retention' <<<"$plan_metadata")"
plan_node_types=()
while IFS= read -r instance_type; do
  plan_node_types+=("$instance_type")
done < <(jq -r '.node_types[]' <<<"$plan_metadata")
bash "$repo_root/scripts/check-account-plan-profile.sh" apply "$plan_profile" "$plan_retention_days" "${plan_node_types[@]}"
unset plan_metadata
configured_region="$(sed -nE 's/^aws_region[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$repo_root/infra/environments/primary/terraform.tfvars")"
[[ -n "$configured_region" && "$configured_region" == "$region" ]] || {
  echo "Blocked: AWS_REGION=$region does not match terraform.tfvars aws_region=$configured_region."
  exit 1
}

phrase="APPLY CAREFLOW TO $expected_account IN $region"
echo "BILLABLE AND STATE-CHANGING: this applies exactly $plan_file"
echo "Type exactly: $phrase"
IFS= read -r confirmation </dev/tty
[[ "$confirmation" == "$phrase" ]] || { echo "Confirmation did not match; nothing was applied."; exit 1; }

terraform -chdir="$repo_root/infra/environments/primary" apply -input=false "$plan_file"
