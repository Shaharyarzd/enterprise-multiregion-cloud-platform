#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
environment="${1:-primary}"
case "$environment" in
  primary|dr) ;;
  *) echo "Usage: EXPECTED_AWS_ACCOUNT_ID=123456789012 bash scripts/cloud-plan.sh [primary|dr]"; exit 2 ;;
esac

echo "READ-ONLY CLOUD OPERATION: this wrapper initializes, validates, refreshes, and plans. It never applies."
bash "$repo_root/scripts/preflight.sh" cloud

backend_mode="${CLOUD_PLAN_BACKEND_MODE:-remote}"
case "$backend_mode" in
  remote|local-review) ;;
  *) echo "CLOUD_PLAN_BACKEND_MODE must be remote or local-review."; exit 2 ;;
esac
export TF_PLUGIN_TIMEOUT="${TF_PLUGIN_TIMEOUT:-2m}"

expected_account="${EXPECTED_AWS_ACCOUNT_ID:-}"
[[ "$expected_account" =~ ^[0-9]{12}$ ]] || {
  echo "Set EXPECTED_AWS_ACCOUNT_ID to the 12-digit sandbox account before planning."
  exit 1
}
actual_account="$(aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || {
  echo "Blocked: AWS identity is account $actual_account, expected sandbox $expected_account."
  exit 1
}
if [[ "$backend_mode" == "remote" ]]; then
  caller_arn="$(aws sts get-caller-identity --query Arn --output text)"
  [[ "$caller_arn" == "arn:aws:sts::$expected_account:assumed-role/careflow-deployment-role/"* ]] || {
    echo "Blocked: remote-state planning requires the short-lived careflow-deployment-role session."
    exit 1
  }
fi

tf_dir="$repo_root/infra/environments/$environment"
[[ -f "$tf_dir/backend.hcl" && -f "$tf_dir/terraform.tfvars" ]] || {
  echo "Create $tf_dir/backend.hcl and terraform.tfvars from the examples, then review them."
  exit 1
}
if rg -n 'REPLACE_ME|203\.0\.113\.10|123456789012' "$tf_dir/backend.hcl" "$tf_dir/terraform.tfvars"; then
  echo "Blocked: replace every example value printed above."
  exit 1
fi
while IFS= read -r referenced_account; do
  [[ "$referenced_account" == "$expected_account" ]] || {
    echo "Blocked: terraform.tfvars references account $referenced_account, expected $expected_account."
    exit 1
  }
done < <(rg -o '[0-9]{12}' "$tf_dir/terraform.tfvars" | sort -u)

deployment_profile="$(sed -nE 's/^deployment_profile[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$tf_dir/terraform.tfvars")"
retention_days="$(sed -nE 's/^database_backup_retention_days[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p' "$tf_dir/terraform.tfvars")"
node_types=()
while IFS= read -r instance_type; do
  node_types+=("$instance_type")
done < <(sed -nE 's/^node_instance_types[[:space:]]*=[[:space:]]*(.*)/\1/p' "$tf_dir/terraform.tfvars" | rg -o '"[^"]+"' | tr -d '"')
bash "$repo_root/scripts/check-account-plan-profile.sh" plan "$deployment_profile" "$retention_days" "${node_types[@]}"

evidence_dir="${EVIDENCE_DIR:-$repo_root/artifacts/cloud-plan/$environment}"
mkdir -p "$evidence_dir"
plan_tf_dir="$tf_dir"
plan_file="$evidence_dir/cloud-demo.tfplan"
plan_text="$evidence_dir/cloud-demo.txt"

if [[ "$backend_mode" == "local-review" ]]; then
  runtime_root="$repo_root/.runtime"
  mkdir -p "$runtime_root"
  planning_root="$runtime_root/cloud-plan-$environment"
  plan_tf_dir="$planning_root/infra/environments/$environment"
  mkdir -p "$plan_tf_dir" "$planning_root/infra/modules"
  export TF_DATA_DIR="$planning_root/.terraform"
  cp "$tf_dir"/*.tf "$tf_dir/.terraform.lock.hcl" "$tf_dir/terraform.tfvars" "$plan_tf_dir/"
  cp -R "$repo_root/infra/modules/." "$planning_root/infra/modules/"
  sed 's/backend "s3" {}/backend "local" {}/' "$tf_dir/versions.tf" > "$plan_tf_dir/versions.tf"
  rg -q 'backend "local"' "$plan_tf_dir/versions.tf" || {
    echo "Blocked: failed to create the isolated local review backend."
    exit 1
  }
  plan_file="$evidence_dir/review-only.tfplan"
  plan_text="$evidence_dir/review-only.txt"
  echo "PLANNING-ONLY LOCAL BACKEND: this plan is for review and must never be passed to cloud-apply.sh."
  terraform -chdir="$plan_tf_dir" init -input=false -lockfile=readonly
else
  terraform -chdir="$plan_tf_dir" init -input=false -backend-config=backend.hcl -lockfile=readonly
fi

terraform -chdir="$plan_tf_dir" validate
terraform -chdir="$plan_tf_dir" plan -input=false -var-file=terraform.tfvars -out="$plan_file"
terraform -chdir="$plan_tf_dir" show -no-color "$plan_file" > "$plan_text"
terraform -chdir="$plan_tf_dir" show -json "$plan_file" > "$evidence_dir/plan.json"

echo "Plan created at $plan_file. No resource was created or changed."
echo "Review $plan_text and obtain an experienced-engineer approval before any apply."
