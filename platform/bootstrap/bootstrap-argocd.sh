#!/usr/bin/env bash
set -euo pipefail

command -v helm >/dev/null || { echo "helm is required"; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl is required"; exit 1; }
command -v rg >/dev/null || { echo "ripgrep (rg) is required"; exit 1; }

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
ROOT_APPLICATION="${RUNTIME_ROOT_APPLICATION:-$repo_root/.runtime/cloud-manifests/root-application.yaml}"
if [[ ! -f "$ROOT_APPLICATION" ]]; then
  echo "Generate the ignored runtime root Application with scripts/configure-cloud-manifests.py first."
  exit 1
fi
if rg -q 'REPLACE_ME|000000000000' "$ROOT_APPLICATION"; then
  echo "Runtime root Application contains an unresolved placeholder."
  exit 1
fi

echo "Waiting for every EKS worker to be Ready before controller bootstrap."
kubectl wait --for=condition=Ready nodes --all --timeout=10m
echo "Waiting for EKS VPC resource controller trunk-ENI readiness."
if kubectl get crd cninodes.vpcresources.k8s.aws >/dev/null 2>&1; then
  # VPC CNI 1.15+ publishes security-groups-for-pods readiness through CNINode.
  kubectl wait \
    --for=jsonpath='{.spec.features[?(@.name=="SecurityGroupsForPods")].name}'=SecurityGroupsForPods \
    cninode --all --timeout=10m
else
  # Compatibility fallback for VPC CNI releases older than 1.15.
  kubectl wait \
    --for=jsonpath='{.metadata.labels.vpc\.amazonaws\.com/has-trunk-attached}'=true \
    nodes --all --timeout=10m
fi

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update argo
helm upgrade --install argocd argo/argo-cd \
  --version 10.4.0 \
  --namespace argocd \
  --create-namespace \
  --values "$(dirname "$0")/argocd-values.yaml" \
  --wait \
  --timeout 10m

kubectl apply -f "$ROOT_APPLICATION"
kubectl -n argocd wait --for=condition=Available deployment/argocd-server --timeout=5m
