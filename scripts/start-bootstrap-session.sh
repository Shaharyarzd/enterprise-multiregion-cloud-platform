#!/usr/bin/env bash

# Source this file so the temporary MFA session remains in the current terminal:
#   source scripts/start-bootstrap-session.sh
is_sourced=false
if [[ -n "${ZSH_EVAL_CONTEXT:-}" && "$ZSH_EVAL_CONTEXT" == *:file ]]; then
  is_sourced=true
elif [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "$0" ]]; then
  is_sourced=true
fi
if [[ "$is_sourced" != true ]]; then
  echo "Source this script instead of executing it: source scripts/start-bootstrap-session.sh"
  exit 2
fi
unset is_sourced

source_profile="${BOOTSTRAP_SOURCE_PROFILE:-careflow-preflight}"
user_name="careflow-portfolio-admin"

command -v aws >/dev/null || { echo "AWS CLI is required."; return 1; }
command -v jq >/dev/null || { echo "jq is required."; return 1; }
[[ -z "${AWS_ACCESS_KEY_ID:-}${AWS_SECRET_ACCESS_KEY:-}${AWS_SESSION_TOKEN:-}" ]] || {
  echo "Blocked: clear existing AWS credential environment variables before starting bootstrap."
  return 1
}

mfa_serial="$(aws iam list-mfa-devices \
  --profile "$source_profile" \
  --user-name "$user_name" \
  --query 'MFADevices[0].SerialNumber' \
  --output text)" || return 1

if [[ -z "$mfa_serial" || "$mfa_serial" == "None" ]]; then
  echo "Blocked: $user_name needs its own MFA device before bootstrap. Root MFA does not satisfy this session."
  return 1
fi

printf "Enter the current six-digit MFA code for %s: " "$user_name"
IFS= read -r -s mfa_code
echo
[[ "$mfa_code" =~ ^[0-9]{6}$ ]] || { echo "The MFA code must contain exactly six digits."; unset mfa_code; return 1; }

session_json="$(aws sts get-session-token \
  --profile "$source_profile" \
  --serial-number "$mfa_serial" \
  --token-code "$mfa_code" \
  --duration-seconds 3600 \
  --output json)" || { unset mfa_code; return 1; }
unset mfa_code

export AWS_ACCESS_KEY_ID="$(jq -r '.Credentials.AccessKeyId' <<<"$session_json")"
export AWS_SECRET_ACCESS_KEY="$(jq -r '.Credentials.SecretAccessKey' <<<"$session_json")"
export AWS_SESSION_TOKEN="$(jq -r '.Credentials.SessionToken' <<<"$session_json")"
export AWS_REGION="${AWS_REGION:-us-east-1}"
session_expiration="$(jq -r '.Credentials.Expiration' <<<"$session_json")"
unset AWS_PROFILE AWS_DEFAULT_PROFILE session_json

caller_arn="$(aws sts get-caller-identity --query Arn --output text)"
echo "Temporary MFA session is active for $caller_arn until $session_expiration."
echo "Credentials were not printed or written to the repository."
echo "When bootstrap is finished, run: unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN"
unset caller_arn mfa_serial session_expiration source_profile user_name
