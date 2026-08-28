#!/usr/bin/env bash
set -euo pipefail

port="${PORT_FORWARD_PORT:-18080}"
log_file="${PORT_FORWARD_LOG:-/tmp/careflow-port-forward.log}"
kubectl -n careflow port-forward "svc/careflow-api" "$port:80" >"$log_file" 2>&1 &
PID=$!
trap 'kill $PID >/dev/null 2>&1 || true' EXIT
sleep 2

curl --fail --silent "http://127.0.0.1:$port/healthz"
printf '
'
curl --fail --silent "http://127.0.0.1:$port/api/v1/appointments"
printf '
Smoke test passed.
'
