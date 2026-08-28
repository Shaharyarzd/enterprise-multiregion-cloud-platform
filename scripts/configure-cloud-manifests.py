#!/usr/bin/env python3
"""Replace non-secret cloud placeholders after Terraform apply."""

import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def checked(pattern, value, label):
    if not re.fullmatch(pattern, value):
        raise ValueError("invalid %s" % label)
    return value


def replace_in(relative_path, replacements):
    path = ROOT / relative_path
    text = path.read_text()
    for old, new in replacements.items():
        text = text.replace(old, new)
    path.write_text(text)


def enable_tls_patch():
    path = ROOT / "k8s/overlays/production/kustomization.yaml"
    text = path.read_text()
    marker = "patches:\n  - target:"
    if "  - path: ingress-tls-patch.yaml\n" not in text:
        if marker not in text:
            raise ValueError("production kustomization patches marker is missing")
        text = text.replace(marker, "patches:\n  - path: ingress-tls-patch.yaml\n  - target:")
        path.write_text(text)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--github-repository", required=True)
    parser.add_argument("--region", required=True)
    parser.add_argument("--cluster-name", required=True)
    parser.add_argument("--vpc-id", required=True)
    parser.add_argument("--secret-arn", required=True)
    parser.add_argument("--workload-security-group", required=True)
    parser.add_argument("--careflow-role-arn", required=True)
    parser.add_argument("--load-balancer-role-arn", required=True)
    parser.add_argument("--ecr-repository", required=True)
    parser.add_argument("--acm-certificate-arn")
    args = parser.parse_args()

    repository = checked(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.github_repository, "GitHub repository")
    region = checked(r"[a-z]{2}(?:-gov)?-[a-z]+-\d", args.region, "AWS region")
    checked(r"vpc-[0-9a-f]+", args.vpc_id, "VPC ID")
    checked(r"sg-[0-9a-f]+", args.workload_security_group, "security group")
    checked(r"arn:[^:]+:iam::[0-9]{12}:role/.+", args.careflow_role_arn, "CareFlow role ARN")
    checked(r"arn:[^:]+:iam::[0-9]{12}:role/.+", args.load_balancer_role_arn, "load balancer role ARN")
    checked(r"arn:[^:]+:secretsmanager:[^:]+:[0-9]{12}:secret:.+", args.secret_arn, "secret ARN")
    if args.acm_certificate_arn:
        checked(r"arn:[^:]+:acm:[^:]+:[0-9]{12}:certificate/.+", args.acm_certificate_arn, "ACM certificate ARN")
    checked(r"[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com/[a-z0-9/_-]+", args.ecr_repository, "ECR repository")

    repo_url = "https://github.com/%s.git" % repository
    for path in [
        "platform/bootstrap/root-application.yaml",
        "platform/argocd/project.yaml",
        "platform/argocd/careflow-application.yaml",
        "platform/argocd/observability-application.yaml",
        "platform/argocd/kyverno-policies-application.yaml",
    ]:
        replace_in(path, {
            "https://github.com/REPLACE_ME/enterprise-multiregion-cloud-platform.git": repo_url
        })

    replace_in("platform/argocd/load-balancer-controller-application.yaml", {
        "REPLACE_ME_EKS_CLUSTER_NAME": args.cluster_name,
        "REPLACE_ME_VPC_ID": args.vpc_id,
        "arn:aws:iam::000000000000:role/REPLACE_ME-aws-load-balancer-controller": args.load_balancer_role_arn,
    })
    replace_in("k8s/overlays/production/external-secret.yaml", {
        "region: us-east-1": "region: %s" % region,
        "REPLACE_ME_RDS_MANAGED_SECRET_ARN": args.secret_arn,
    })
    replace_in("k8s/overlays/production/security-group-policy.yaml", {
        "sg-REPLACE_ME_CAREFLOW_WORKLOAD": args.workload_security_group,
    })
    replace_in("k8s/overlays/production/kustomization.yaml", {
        "000000000000.dkr.ecr.us-east-1.amazonaws.com/careflow-api": args.ecr_repository,
        "arn:aws:iam::000000000000:role/REPLACE_ME-careflow-secrets": args.careflow_role_arn,
    })
    if args.acm_certificate_arn:
        replace_in("k8s/overlays/production/ingress-tls-patch.yaml", {
            "REPLACE_ME_ACM_CERTIFICATE_ARN": args.acm_certificate_arn,
        })
        enable_tls_patch()
        tls_status = "trusted TLS patch enabled"
    else:
        tls_status = "HTTP ALB proof enabled; trusted TLS remains PENDING"
    print("Configured non-secret cloud manifest values (%s). Review the diff before committing." % tls_status)


if __name__ == "__main__":
    main()
