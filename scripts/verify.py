from pathlib import Path
import ast
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []
SKIP_PARTS = {".git", ".runtime", ".terraform", ".venv", "__pycache__"}


def source_files(pattern: str):
    return [path for path in ROOT.rglob(pattern) if not SKIP_PARTS.intersection(path.parts)]

# Python syntax
for path in source_files("*.py"):
    try:
        ast.parse(path.read_text())
    except SyntaxError as exc:
        errors.append(f"Python syntax: {path.relative_to(ROOT)}: {exc}")

# Very lightweight YAML structural checks without third-party dependencies.
for path in source_files("*.yaml") + source_files("*.yml"):
    text = path.read_text()
    if not text.strip():
        errors.append(f"Empty YAML: {path.relative_to(ROOT)}")
    if "	" in text:
        errors.append(f"Tab found in YAML: {path.relative_to(ROOT)}")

# Portfolio safety checks.
for forbidden in ["AK" + "IA", "BEGIN PRIVATE" + " KEY", "password" + " = \""]:
    for path in source_files("*"):
        if path.is_file():
            try:
                txt = path.read_text()
            except UnicodeDecodeError:
                continue
            if forbidden in txt:
                errors.append(f"Potential secret pattern '{forbidden}' in {path.relative_to(ROOT)}")

# Design invariant: CI must never contain terraform apply.
for wf in (ROOT / ".github" / "workflows").glob("*.yml"):
    workflow_text = wf.read_text()
    if "terraform apply" in workflow_text.lower():
        errors.append(f"Unsafe automatic terraform apply reference in {wf.relative_to(ROOT)}")

    for line_number, line in enumerate(workflow_text.splitlines(), start=1):
        match = re.search(r"^\s*-?\s*uses:\s*[^@\s]+@([^\s#]+)", line)
        if match and not re.fullmatch(r"[0-9a-f]{40}", match.group(1)):
            errors.append(
                f"Mutable GitHub Action reference in {wf.relative_to(ROOT)}:{line_number}"
            )

# Cloud mutation must remain confined to wrappers with account/region-bound phrases.
for path in (ROOT / "scripts").glob("*.sh"):
    script_text = path.read_text()
    if re.search(r"\bterraform\b.*\bapply\b", script_text):
        if path.name not in {"aws-bootstrap-apply.sh", "cloud-apply.sh", "cloud-destroy.sh"}:
            errors.append(f"Terraform apply is outside an approved wrapper: {path.relative_to(ROOT)}")
for required_path, required_text in {
    ROOT / "scripts" / "cloud-apply.sh": "APPLY CAREFLOW TO",
    ROOT / "scripts" / "cloud-destroy.sh": "DESTROY CAREFLOW IN",
    ROOT / "scripts" / "cloud-plan.sh": "EXPECTED_AWS_ACCOUNT_ID",
    ROOT / "scripts" / "aws-bootstrap-apply.sh": "CREATE CAREFLOW BOOTSTRAP IN",
}.items():
    if required_text not in required_path.read_text():
        errors.append(f"Cloud safety control missing from {required_path.relative_to(ROOT)}")

# Secure-by-default control-plane invariant.
for path in [
    ROOT / "infra" / "environments" / "primary" / "variables.tf",
    ROOT / "infra" / "environments" / "dr" / "variables.tf",
]:
    if 'default     = ["0.0.0.0/0"]' in path.read_text():
        errors.append(f"Broad EKS API CIDR default in {path.relative_to(ROOT)}")

# Milestone 2 vertical-slice invariants.
production_kustomization = (
    ROOT / "k8s" / "overlays" / "production" / "kustomization.yaml"
).read_text()
if not re.search(r"(?m)^\s*digest:\s+sha256:[0-9a-f]{64}$", production_kustomization):
    errors.append("Production image is not pinned to a syntactically valid sha256 digest")

publication_workflow = (ROOT / ".github" / "workflows" / "publish.yml").read_text()
for required in ["id-token: write", "docker push", "update-image-digest.py"]:
    if required not in publication_workflow:
        errors.append(f"Publication workflow is missing required control: {required}")
if re.search(r"\b(kubectl|helm)\b", publication_workflow):
    errors.append("Publication workflow must not mutate Kubernetes directly")

primary_main = (ROOT / "infra" / "environments" / "primary" / "main.tf").read_text()
primary_variables = (ROOT / "infra" / "environments" / "primary" / "variables.tf").read_text()
if "module.eks[0].node_security_group_id" in primary_main:
    errors.append("RDS access must not trust the shared EKS node security group")
if not re.search(
    r'variable "enable_cloud_resources"\s*\{.*?default\s*=\s*false',
    primary_variables,
    re.DOTALL,
):
    errors.append("Primary cloud resources are not disabled by default")

for required in [
    '"production-target"',
    '"free-plan-demo"',
    'var.node_instance_types[0] == "c7i-flex.large"',
    "database_backup_retention_days == 1",
]:
    if required not in primary_main and required not in primary_variables:
        errors.append(f"Primary profile guard is missing required constraint: {required}")

account_guard = (ROOT / "scripts" / "check-account-plan-profile.sh").read_text()
for required in ["freetier get-account-plan-state", "FreeTierEligible", "production-target"]:
    if required not in account_guard:
        errors.append(f"Account-plan guard is missing required control: {required}")

argocd_kustomization = (ROOT / "platform" / "argocd" / "kustomization.yaml").read_text()
for required in ["kyverno-application.yaml", "kyverno-policies-application.yaml"]:
    if required not in argocd_kustomization:
        errors.append(f"Argo CD bootstrap is missing required policy component: {required}")

# Fourth-run regression guards: pod ENIs require the AWS-designated cluster-role
# policy, while hardened IMDS requires explicit ALB controller dependencies.
eks_module = (ROOT / "infra" / "modules" / "eks" / "main.tf").read_text()
if 'ENABLE_POD_ENI                    = "true"' in eks_module:
    for required in [
        "iam_role_additional_policies",
        'AmazonEKSVPCResourceController = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"',
    ]:
        if required not in eks_module:
            errors.append(f"Pod security groups are enabled without cluster-role prerequisite: {required}")
if "http_put_response_hop_limit = 1" not in eks_module or 'http_tokens                 = "required"' not in eks_module:
    errors.append("Worker IMDS hardening must retain hop-limit 1 and required IMDSv2 tokens")

alb_application = (
    ROOT / "platform" / "argocd" / "load-balancer-controller-application.yaml"
).read_text()
for required in ["region: us-east-1", "vpcId: REPLACE_ME_VPC_ID"]:
    if required not in alb_application:
        errors.append(f"ALB Controller lacks explicit hardened-IMDS dependency: {required}")
cloud_configurator = (ROOT / "scripts" / "configure-cloud-manifests.py").read_text()
for required in ['parser.add_argument("--vpc-id", required=True)', '"REPLACE_ME_VPC_ID": args.vpc_id']:
    if required not in cloud_configurator:
        errors.append(f"ALB Controller VPC injection path is incomplete: {required}")

expected_waves = {
    "external-secrets-application.yaml": "-50",
    "load-balancer-controller-application.yaml": "-40",
    "kyverno-application.yaml": "-30",
    "kyverno-policies-application.yaml": "-29",
    "metrics-server-application.yaml": "-20",
    "observability-application.yaml": "-10",
    "careflow-application.yaml": "10",
}
for filename, wave in expected_waves.items():
    application_text = (ROOT / "platform" / "argocd" / filename).read_text()
    if f'argocd.argoproj.io/sync-wave: "{wave}"' not in application_text:
        errors.append(f"Argo dependency order is incorrect for {filename}; expected wave {wave}")

argocd_bootstrap = (ROOT / "platform" / "bootstrap" / "bootstrap-argocd.sh").read_text()
for required in ["--for=condition=Ready nodes --all", "vpc\\.amazonaws\\.com/has-trunk-attached"]:
    if required not in argocd_bootstrap:
        errors.append(f"Argo bootstrap lacks EKS networking readiness gate: {required}")

production_ingress = (ROOT / "k8s" / "overlays" / "production" / "ingress.yaml").read_text()
tls_patch = (ROOT / "k8s" / "overlays" / "production" / "ingress-tls-patch.yaml").read_text()
if 'alb.ingress.kubernetes.io/listen-ports: \'[{"HTTP":80}]\'' not in production_ingress:
    errors.append("Default cloud runtime proof must expose an HTTP ALB listener without requiring a domain")
if "certificate-arn" in production_ingress or "ssl-redirect" in production_ingress:
    errors.append("Trusted TLS must remain an optional patch when no owner-controlled domain exists")
for required in ["certificate-arn: REPLACE_ME_ACM_CERTIFICATE_ARN", 'ssl-redirect: "443"']:
    if required not in tls_patch:
        errors.append(f"Optional trusted-TLS patch is incomplete: {required}")
if "  - path: ingress-tls-patch.yaml" in production_kustomization:
    errors.append("Optional TLS patch must not be enabled before an ACM certificate is supplied")

external_secret = (
    ROOT / "k8s" / "overlays" / "production" / "external-secret.yaml"
).read_text()
if "serviceAccountRef:" not in external_secret or "refreshInterval: 5m" not in external_secret:
    errors.append("External Secrets workload identity/rotation contract is incomplete")

if errors:
    print("Verification failed:")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)

print(
    "Verification passed: Python syntax, YAML hygiene, secret patterns, "
    "immutable Actions, digest GitOps, workload identity, blast radius, "
    "no-op cloud defaults, and account/region-bound cloud mutation wrappers."
)
