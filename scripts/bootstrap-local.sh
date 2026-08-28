#!/usr/bin/env bash
set -euo pipefail

command -v docker >/dev/null || { echo "docker is required"; exit 1; }
command -v kind >/dev/null || { echo "kind is required"; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl is required"; exit 1; }
command -v openssl >/dev/null || { echo "openssl is required"; exit 1; }

CLUSTER="${CLUSTER_NAME:-careflow-portfolio}"
IMAGE="${IMAGE:-careflow-api:0.2.0}"

if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER"
fi

docker build -t "$IMAGE" apps/careflow-api
kind load docker-image "$IMAGE" --name "$CLUSTER"
kubectl create namespace careflow --dry-run=client -o yaml | kubectl apply -f -
LOCAL_DB_PASSWORD="$(openssl rand -hex 24)"
LOCAL_DB_JSON="{\"host\":\"careflow-postgres\",\"port\":5432,\"dbname\":\"careflow\",\"username\":\"careflow_local\",\"password\":\"${LOCAL_DB_PASSWORD}\"}"
kubectl -n careflow create secret generic careflow-db-credentials \
  --from-literal=password="${LOCAL_DB_PASSWORD}" \
  --from-literal=database.json="${LOCAL_DB_JSON}" \
  --dry-run=client -o yaml | kubectl apply -f -
unset LOCAL_DB_PASSWORD LOCAL_DB_JSON
kubectl apply -k k8s/overlays/local
kubectl -n careflow rollout status statefulset/careflow-postgres --timeout=120s
kubectl -n careflow rollout status deployment/careflow-api --timeout=120s

echo "Local cluster is ready. Run: make smoke-test"
