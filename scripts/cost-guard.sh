#!/usr/bin/env bash
set -euo pipefail

echo "This legacy yes/no guard is retired because it does not bind approval to an account and region."
echo "Use scripts/cloud-plan.sh, then scripts/cloud-apply.sh with its exact typed phrase."
exit 1
