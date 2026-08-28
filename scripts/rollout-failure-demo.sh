#!/usr/bin/env bash
set -euo pipefail

command -v kubectl >/dev/null || { echo "kubectl is required"; exit 1; }

namespace=careflow
deployment=careflow-api
evidence_dir="${EVIDENCE_DIR:-}"
traffic_file="$(mktemp "${TMPDIR:-/tmp}/careflow-traffic.XXXXXX")"
port_forward_log="$(mktemp "${TMPDIR:-/tmp}/careflow-port-forward.XXXXXX")"
traffic_pid=""
port_forward_pid=""

cleanup() {
  [[ -z "$traffic_pid" ]] || kill "$traffic_pid" >/dev/null 2>&1 || true
  [[ -z "$port_forward_pid" ]] || kill "$port_forward_pid" >/dev/null 2>&1 || true
  rm -f "$traffic_file" "$port_forward_log"
}
trap cleanup EXIT

if [[ -n "$evidence_dir" ]]; then
  mkdir -p "$evidence_dir"
fi

echo "Confirming that release v1 is available..."
kubectl -n "$namespace" rollout status "deployment/$deployment" --timeout=120s
kubectl -n "$namespace" get deployment "$deployment"

echo "Applying release v2, which deliberately fails readiness..."
kubectl -n "$namespace" port-forward "service/$deployment" 18081:80 >"$port_forward_log" 2>&1 &
port_forward_pid=$!
for _ in {1..30}; do
  curl --fail --silent http://127.0.0.1:18081/api/v1/appointments >/dev/null 2>&1 && break
  sleep 1
done
(
  while true; do
    if curl --fail --silent --max-time 2 http://127.0.0.1:18081/api/v1/appointments >/dev/null; then
      echo PASS >> "$traffic_file"
    else
      echo FAIL >> "$traffic_file"
    fi
    sleep 0.5
  done
) &
traffic_pid=$!
kubectl apply -k k8s/scenarios/readiness-failure

if kubectl -n "$namespace" rollout status "deployment/$deployment" --timeout=60s; then
  echo "Unexpected result: the deliberately broken release became ready."
  exit 1
fi

echo "Expected result: v2 did not become ready. Checking that v1 still serves traffic..."
kubectl -n "$namespace" get pods -l app.kubernetes.io/name=careflow-api
PORT_FORWARD_PORT=18082 PORT_FORWARD_LOG="$port_forward_log.smoke" bash scripts/smoke-test.sh

echo "Recovering the previous Deployment revision..."
kubectl -n "$namespace" rollout undo "deployment/$deployment"
kubectl -n "$namespace" rollout status "deployment/$deployment" --timeout=120s
PORT_FORWARD_PORT=18082 PORT_FORWARD_LOG="$port_forward_log.smoke" bash scripts/smoke-test.sh

kill "$traffic_pid" >/dev/null 2>&1 || true
wait "$traffic_pid" 2>/dev/null || true
traffic_pid=""
total_requests="$(wc -l < "$traffic_file" | tr -d ' ')"
failed_requests="$(grep -c '^FAIL$' "$traffic_file" || true)"
[[ "$total_requests" -gt 0 ]] || { echo "Continuous traffic generator recorded no requests."; exit 1; }
[[ "$failed_requests" -eq 0 ]] || {
  echo "Old-replica availability failed: $failed_requests of $total_requests requests failed."
  exit 1
}

if [[ -n "$evidence_dir" ]]; then
  cp "$traffic_file" "$evidence_dir/continuous-traffic.txt"
  kubectl -n "$namespace" get deployment,pods -o wide > "$evidence_dir/workloads-after-rollback.txt"
  python3 - "$evidence_dir/rollout-summary.json" "$total_requests" "$failed_requests" <<'PY'
import json
import pathlib
import sys

pathlib.Path(sys.argv[1]).write_text(json.dumps({
    "schema_version": 1,
    "status": "PASS",
    "forced_readiness_failure_rejected": True,
    "old_replica_requests": int(sys.argv[2]),
    "old_replica_failures": int(sys.argv[3]),
    "rollback": "PASS",
    "contains_secrets": False,
}, indent=2) + "\n")
PY
fi

echo "Rollback drill passed with $total_requests continuous requests and zero failures."
