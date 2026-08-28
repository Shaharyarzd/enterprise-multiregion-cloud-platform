#!/usr/bin/env bash
set -euo pipefail

echo "Compatibility wrapper: use scripts/cloud-plan.sh directly for new instructions."
exec bash "$(dirname "$0")/cloud-plan.sh" primary
