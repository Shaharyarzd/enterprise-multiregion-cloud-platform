#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

mode="${1:-all}"
case "$mode" in
  local|cloud|all) ;;
  *) echo "Usage: bash scripts/preflight.sh [local|cloud|all]"; exit 2 ;;
esac

missing_required=0
missing_optional=0

check_tool() {
  local tool="$1"
  local requirement="$2"
  if command -v "$tool" >/dev/null 2>&1; then
    printf 'PASS  %-12s %s\n' "$tool" "$(command -v "$tool")"
  elif [[ "$requirement" == "required" ]]; then
    printf 'FAIL  %-12s required for %s proof\n' "$tool" "$mode"
    missing_required=1
  else
    printf 'PENDING %-10s optional; its evidence stage will be skipped\n' "$tool"
    missing_optional=1
  fi
}

echo "CareFlow preflight ($mode) — inspection only; no resource is created or changed."
check_tool python3 required
check_tool curl required
check_tool rg required

if [[ "$mode" == "local" || "$mode" == "all" ]]; then
  check_tool docker required
  check_tool openssl required
  check_tool trivy required
  check_tool kind optional
  check_tool kubectl optional
fi

if [[ "$mode" == "cloud" || "$mode" == "all" ]]; then
  check_tool aws required
  check_tool terraform required
  check_tool kubectl optional
  check_tool helm optional
  check_tool gh optional
  if python3 "$repo_root/scripts/verify.py"; then
    echo "PASS  cloud repository invariants"
  else
    echo "FAIL  cloud repository invariants"
    missing_required=1
  fi
fi

if [[ "$mode" == "local" || "$mode" == "all" ]] && command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    echo "PASS  docker-daemon reachable"
  else
    echo "FAIL  docker-daemon is not reachable"
    missing_required=1
  fi
fi

if [[ "$mode" == "cloud" || "$mode" == "all" ]] && command -v aws >/dev/null 2>&1; then
  if aws sts get-caller-identity --output json >/dev/null 2>&1; then
    caller_arn="$(aws sts get-caller-identity --query Arn --output text)"
    if [[ "$caller_arn" == *":assumed-role/"* ]]; then
      echo "PASS  aws-identity short-lived assumed-role credentials are usable"
    elif [[ "$caller_arn" == *":user/"* ]]; then
      echo "WARN  aws-identity IAM user credentials are usable for read-only planning; assume a short-lived role before apply"
    else
      echo "WARN  aws-identity is usable but not a confirmed short-lived assumed role"
    fi
  else
    echo "FAIL  aws-identity is unavailable; sign in with the sandbox SSO/role"
    missing_required=1
  fi
fi

if (( missing_required != 0 )); then
  echo "Preflight failed. Nothing was created."
  exit 1
fi

if (( missing_optional != 0 )); then
  echo "Preflight passed for required tools; optional evidence remains PENDING."
else
  echo "Preflight passed."
fi
