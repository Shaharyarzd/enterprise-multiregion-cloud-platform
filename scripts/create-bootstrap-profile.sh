#!/usr/bin/env bash
set -euo pipefail

source_profile="${BOOTSTRAP_SOURCE_PROFILE:-careflow-preflight}"
session_profile="careflow-bootstrap-session"
user_name="careflow-portfolio-admin"
session_duration_seconds="${BOOTSTRAP_SESSION_DURATION_SECONDS:-3600}"

command -v aws >/dev/null || { echo "AWS CLI is required."; exit 1; }
command -v jq >/dev/null || { echo "jq is required."; exit 1; }
[[ -z "${AWS_ACCESS_KEY_ID:-}${AWS_SECRET_ACCESS_KEY:-}${AWS_SESSION_TOKEN:-}" ]] || {
  echo "Blocked: clear existing AWS credential environment variables first."
  exit 1
}
[[ "$session_duration_seconds" =~ ^[0-9]+$ ]] || {
  echo "Blocked: BOOTSTRAP_SESSION_DURATION_SECONDS must be an integer."
  exit 1
}
(( session_duration_seconds >= 3600 && session_duration_seconds <= 129600 )) || {
  echo "Blocked: session duration must be between 3600 and 129600 seconds."
  exit 1
}

mfa_serial="$(aws iam list-mfa-devices \
  --profile "$source_profile" \
  --user-name "$user_name" \
  --query 'MFADevices[0].SerialNumber' \
  --output text)"

if [[ -z "$mfa_serial" || "$mfa_serial" == "None" ]]; then
  echo "Blocked: $user_name has no visible MFA device."
  exit 1
fi

printf "Enter the current six-digit MFA code for %s: " "$user_name"
IFS= read -r -s mfa_code
echo
[[ "$mfa_code" =~ ^[0-9]{6}$ ]] || { echo "The MFA code must contain exactly six digits."; unset mfa_code; exit 1; }

session_json="$(aws sts get-session-token \
  --profile "$source_profile" \
  --serial-number "$mfa_serial" \
  --token-code "$mfa_code" \
  --duration-seconds "$session_duration_seconds" \
  --output json)"
unset mfa_code

access_key_id="$(jq -r '.Credentials.AccessKeyId' <<<"$session_json")"
secret_access_key="$(jq -r '.Credentials.SecretAccessKey' <<<"$session_json")"
session_token="$(jq -r '.Credentials.SessionToken' <<<"$session_json")"
session_expiration="$(jq -r '.Credentials.Expiration' <<<"$session_json")"

aws configure set aws_access_key_id "$access_key_id" --profile "$session_profile"
aws configure set aws_secret_access_key "$secret_access_key" --profile "$session_profile"
aws configure set aws_session_token "$session_token" --profile "$session_profile"
aws configure set region us-east-1 --profile "$session_profile"

caller_arn="$(aws sts get-caller-identity --profile "$session_profile" --query Arn --output text)"
echo "Temporary MFA profile $session_profile is active for $caller_arn until $session_expiration."
echo "Credentials were not printed or written to the repository."
echo "After bootstrap, run: bash scripts/clear-bootstrap-profile.sh"

unset access_key_id caller_arn mfa_serial secret_access_key session_expiration session_json session_token
