#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

bash scripts/preflight.sh local

run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
evidence_dir="${EVIDENCE_DIR:-$repo_root/artifacts/runtime-evidence/local-$run_id}"
image="careflow-api:runtime-evidence-$run_id"
test_image="careflow-api:test-evidence-$run_id"
network="careflow-evidence-$run_id"
volume="careflow-pgdata-$run_id"
postgres_container="careflow-postgres-$run_id"
api_container="careflow-api-$run_id"
runtime_temp_root="$repo_root/.runtime"
mkdir -p "$runtime_temp_root"
secret_dir="$(mktemp -d "$runtime_temp_root/careflow-secret.XXXXXX")"
secret_file="$secret_dir/database.json"
postgres_password_file="$secret_dir/postgres-password"
kind_cluster="careflow-evidence-${run_id//T/t}"
kind_cluster="${kind_cluster//Z/z}"
kind_started=0

mkdir -p "$evidence_dir"

cleanup() {
  docker rm -f "$api_container" "$postgres_container" >/dev/null 2>&1 || true
  docker network rm "$network" >/dev/null 2>&1 || true
  docker volume rm "$volume" >/dev/null 2>&1 || true
  docker image rm "$image" "$test_image" >/dev/null 2>&1 || true
  if (( kind_started == 1 )); then
    kind delete cluster --name "$kind_cluster" >/dev/null 2>&1 || true
  fi
  find "$secret_dir" -type f -exec chmod u+w {} + 2>/dev/null || true
  rm -rf "$secret_dir"
}
trap cleanup EXIT

record_summary() {
  local kind_status="$1"
  python3 - "$evidence_dir/summary.json" "$run_id" "$kind_status" <<'PY'
import json
import pathlib
import subprocess
import sys
from datetime import datetime, timezone

def output(*command):
    return subprocess.run(command, check=True, capture_output=True, text=True).stdout.strip()

path = pathlib.Path(sys.argv[1])
payload = {
    "schema_version": 1,
    "run_id": sys.argv[2],
    "completed_at_utc": datetime.now(timezone.utc).isoformat(),
    "scope": "local-runtime",
    "status": "PASS",
    "tools": {
        "docker_client": output("docker", "version", "--format", "{{.Client.Version}}"),
        "trivy": output("trivy", "--version").splitlines()[0],
    },
    "checks": {
        "container_test_target": "PASS",
        "runtime_image_build": "PASS",
        "runtime_image_trivy_scan": "PASS",
        "postgres_migration_and_api": "PASS",
        "persistence_after_app_and_database_restart": "PASS",
        "local_secret_rotation": "PASS",
        "metrics_endpoint": "PASS",
        "kind_rollout_failure_and_rollback": sys.argv[3],
    },
    "contains_secrets": False,
}
path.write_text(json.dumps(payload, indent=2) + "\n")
PY
}

wait_for_url() {
  local url="$1"
  local attempts="${2:-60}"
  for ((i = 1; i <= attempts; i++)); do
    if curl --fail --silent --show-error --max-time 2 "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for $url"
  return 1
}

echo "[1/8] Build and run the container test target"
docker build --target test --tag "$test_image" apps/careflow-api | tee "$evidence_dir/image-test-build.log"
docker run --rm "$test_image" | tee "$evidence_dir/container-tests.log"

echo "[2/8] Build the runtime image"
docker build --target runtime --tag "$image" apps/careflow-api | tee "$evidence_dir/image-build.log"

echo "[3/8] Scan the actual runtime image"
trivy image --scanners vuln,secret --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "$image" \
  | tee "$evidence_dir/trivy-image.log"

echo "[4/8] Start PostgreSQL with an isolated volume"
docker network create "$network" >/dev/null
docker volume create "$volume" >/dev/null
database_password="$(openssl rand -hex 24)"
printf '{"host":"%s","port":5432,"dbname":"careflow","username":"careflow_local","password":"%s"}\n' \
  "$postgres_container" "$database_password" > "$secret_file"
printf '%s' "$database_password" > "$postgres_password_file"
chmod 755 "$secret_dir"
chmod 444 "$secret_file" "$postgres_password_file"
docker run --detach --name "$postgres_container" --network "$network" \
  --env POSTGRES_DB=careflow --env POSTGRES_USER=careflow_local \
  --env POSTGRES_PASSWORD_FILE=/run/careflow/postgres-password \
  --mount "type=bind,source=$postgres_password_file,target=/run/careflow/postgres-password,readonly" \
  --volume "$volume:/var/lib/postgresql/data" postgres:17.6-alpine3.22 >/dev/null
for _ in {1..60}; do
  if docker exec "$postgres_container" pg_isready -U careflow_local -d careflow >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
docker exec "$postgres_container" pg_isready -U careflow_local -d careflow | tee "$evidence_dir/postgres-ready.log"

echo "[5/8] Run migrations through readiness and verify API data"
docker run --detach --name "$api_container" --network "$network" --publish 127.0.0.1:18080:8080 \
  --env DB_SECRET_FILE=/run/careflow/database.json --env DB_SSLMODE=disable \
  --env ALLOW_INSECURE_LOCAL_DATABASE=true --env APP_VERSION=runtime-evidence \
  --mount "type=bind,source=$secret_file,target=/run/careflow/database.json,readonly" \
  "$image" >/dev/null
wait_for_url http://127.0.0.1:18080/readyz
curl --fail --silent --show-error http://127.0.0.1:18080/readyz | tee "$evidence_dir/readyz.json"
curl --fail --silent --show-error http://127.0.0.1:18080/api/v1/appointments | tee "$evidence_dir/appointments-before.json"
printf '\n'

echo "[6/8] Add synthetic data, restart app/database, and prove PostgreSQL persistence"
docker exec -i "$postgres_container" psql -v ON_ERROR_STOP=1 -U careflow_local -d careflow >/dev/null <<'SQL'
INSERT INTO patients (synthetic_id) VALUES ('patient-demo-persistence') ON CONFLICT DO NOTHING;
INSERT INTO appointments (synthetic_id, patient_id, status)
SELECT 'apt-demo-persistence', id, 'scheduled'
FROM patients WHERE synthetic_id = 'patient-demo-persistence'
ON CONFLICT DO NOTHING;
SQL
docker restart "$api_container" >/dev/null
wait_for_url http://127.0.0.1:18080/readyz
curl --fail --silent --show-error http://127.0.0.1:18080/api/v1/appointments \
  | tee "$evidence_dir/appointments-after-restart.json" | grep -q 'apt-demo-persistence'
docker restart "$postgres_container" >/dev/null
for _ in {1..60}; do
  if docker exec "$postgres_container" pg_isready -U careflow_local -d careflow >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
wait_for_url http://127.0.0.1:18080/readyz
curl --fail --silent --show-error http://127.0.0.1:18080/api/v1/appointments \
  | tee "$evidence_dir/appointments-after-database-restart.json" | grep -q 'apt-demo-persistence'

echo "[7/8] Rotate the local password and verify pool recovery without source changes"
rotated_password="$(openssl rand -hex 24)"
printf "ALTER ROLE careflow_local PASSWORD '%s';\n" "$rotated_password" \
  | docker exec -i "$postgres_container" psql -v ON_ERROR_STOP=1 -U careflow_local -d careflow >/dev/null
chmod u+w "$secret_file"
printf '{"host":"%s","port":5432,"dbname":"careflow","username":"careflow_local","password":"%s"}\n' \
  "$postgres_container" "$rotated_password" > "$secret_file"
chmod 444 "$secret_file"
unset database_password rotated_password
wait_for_url http://127.0.0.1:18080/readyz
curl --fail --silent --show-error http://127.0.0.1:18080/readyz | tee "$evidence_dir/readyz-after-rotation.json"
curl --fail --silent --show-error http://127.0.0.1:18080/metrics \
  | tee "$evidence_dir/metrics.txt" | grep -q 'careflow_database_dependency_healthy 1'

echo "[8/8] Run kind failure/rollback evidence when kind and kubectl are both installed"
kind_status="N/A"
if command -v kind >/dev/null 2>&1 && command -v kubectl >/dev/null 2>&1; then
  kind_started=1
  CLUSTER_NAME="$kind_cluster" bash scripts/bootstrap-local.sh
  EVIDENCE_DIR="$evidence_dir/kind" bash scripts/rollout-failure-demo.sh
  kind_status="PASS"
else
  echo "kind and/or kubectl unavailable; Kubernetes runtime evidence remains PENDING."
  kind_status="PENDING"
fi

record_summary "$kind_status"
echo "Local runtime proof passed. Redacted evidence: $evidence_dir"
