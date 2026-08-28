#!/usr/bin/env bash
set -euo pipefail

profile="careflow-bootstrap-session"
aws configure set aws_access_key_id "" --profile "$profile"
aws configure set aws_secret_access_key "" --profile "$profile"
aws configure set aws_session_token "" --profile "$profile"
echo "Local temporary credentials were cleared from profile $profile."

