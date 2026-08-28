#!/usr/bin/env python3
"""Generate an ignored Argo root Application with runtime-only AWS identifiers."""

import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / ".runtime" / "cloud-manifests" / "root-application.yaml"


def checked(pattern, value, label):
    if not re.fullmatch(pattern, value):
        raise ValueError("invalid %s" % label)
    return value


def quoted(value):
    return json.dumps(value)


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
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    repository = checked(
        r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+",
        args.github_repository,
        "GitHub repository",
    )
    region = checked(r"[a-z]{2}(?:-gov)?-[a-z]+-\d", args.region, "AWS region")
    cluster_name = checked(r"[A-Za-z0-9][A-Za-z0-9_-]+", args.cluster_name, "cluster name")
    vpc_id = checked(r"vpc-[0-9a-f]+", args.vpc_id, "VPC ID")
    workload_security_group = checked(
        r"sg-[0-9a-f]+", args.workload_security_group, "security group"
    )
    careflow_role_arn = checked(
        r"arn:[^:]+:iam::[0-9]{12}:role/.+", args.careflow_role_arn, "CareFlow role ARN"
    )
    load_balancer_role_arn = checked(
        r"arn:[^:]+:iam::[0-9]{12}:role/.+",
        args.load_balancer_role_arn,
        "load balancer role ARN",
    )
    secret_arn = checked(
        r"arn:[^:]+:secretsmanager:[^:]+:[0-9]{12}:secret:.+",
        args.secret_arn,
        "secret ARN",
    )
    ecr_repository = checked(
        r"[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com/[a-z0-9/_-]+",
        args.ecr_repository,
        "ECR repository",
    )
    if args.acm_certificate_arn:
        certificate_arn = checked(
            r"arn:[^:]+:acm:[^:]+:[0-9]{12}:certificate/.+",
            args.acm_certificate_arn,
            "ACM certificate ARN",
        )
    else:
        certificate_arn = None

    repo_url = "https://github.com/%s.git" % repository
    tls_patch = ""
    if certificate_arn:
        tls_patch = f"""
                  - target:
                      kind: Ingress
                      name: careflow-api
                    patch: |-
                      - op: add
                        path: /metadata/annotations/alb.ingress.kubernetes.io~1listen-ports
                        value: '[{{\"HTTP\":80}},{{\"HTTPS\":443}}]'
                      - op: add
                        path: /metadata/annotations/alb.ingress.kubernetes.io~1ssl-redirect
                        value: \"443\"
                      - op: add
                        path: /metadata/annotations/alb.ingress.kubernetes.io~1certificate-arn
                        value: {quoted(certificate_arn)}
                      - op: add
                        path: /metadata/annotations/alb.ingress.kubernetes.io~1ssl-policy
                        value: ELBSecurityPolicy-TLS13-1-2-2021-06"""

    template = (ROOT / "platform" / "bootstrap" / "root-application.yaml").read_text()
    template = template.replace(
        "https://github.com/REPLACE_ME/enterprise-multiregion-cloud-platform.git",
        repo_url,
    )
    marker = "    path: platform/argocd\n"
    if marker not in template:
        raise ValueError("root Application source marker is missing")

    runtime_patches = f"""    kustomize:
      patches:
        - target:
            kind: AppProject
            name: careflow-platform
          patch: |-
            - op: replace
              path: /spec/sourceRepos/0
              value: {quoted(repo_url)}
        - target:
            kind: Application
            name: careflow-kyverno-policies
          patch: |-
            - op: replace
              path: /spec/source/repoURL
              value: {quoted(repo_url)}
        - target:
            kind: Application
            name: careflow-observability
          patch: |-
            - op: replace
              path: /spec/sources/1/repoURL
              value: {quoted(repo_url)}
        - target:
            kind: Application
            name: aws-load-balancer-controller
          patch: |-
            - op: replace
              path: /spec/source/helm/valuesObject/clusterName
              value: {quoted(cluster_name)}
            - op: replace
              path: /spec/source/helm/valuesObject/region
              value: {quoted(region)}
            - op: replace
              path: /spec/source/helm/valuesObject/vpcId
              value: {quoted(vpc_id)}
            - op: replace
              path: /spec/source/helm/valuesObject/serviceAccount/annotations/eks.amazonaws.com~1role-arn
              value: {quoted(load_balancer_role_arn)}
        - target:
            kind: Application
            name: careflow-api
          patch: |-
            - op: replace
              path: /spec/source/repoURL
              value: {quoted(repo_url)}
            - op: add
              path: /spec/source/kustomize
              value:
                images:
                  - careflow-api={ecr_repository}
                patches:
                  - target:
                      kind: ExternalSecret
                      name: careflow-database
                    patch: |-
                      - op: replace
                        path: /spec/dataFrom/0/extract/key
                        value: {quoted(secret_arn)}
                  - target:
                      kind: SecurityGroupPolicy
                      name: careflow-api
                    patch: |-
                      - op: replace
                        path: /spec/securityGroups/groupIds/0
                        value: {quoted(workload_security_group)}
                  - target:
                      kind: ServiceAccount
                      name: careflow-api
                    patch: |-
                      - op: add
                        path: /metadata/annotations
                        value:
                          eks.amazonaws.com/role-arn: {quoted(careflow_role_arn)}{tls_patch}
"""
    rendered = template.replace(marker, marker + runtime_patches)
    if "REPLACE_ME" in rendered or "000000000000" in rendered:
        raise ValueError("runtime root Application still contains an unresolved placeholder")

    output = args.output.resolve()
    runtime_root = (ROOT / ".runtime").resolve()
    if runtime_root not in output.parents:
        raise ValueError("runtime output must remain under the ignored .runtime directory")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(rendered)
    output.chmod(0o600)
    tls_status = "trusted TLS runtime patch enabled" if certificate_arn else "HTTP proof; trusted TLS PENDING"
    print("Generated ignored runtime Argo configuration (%s): %s" % (tls_status, output))


if __name__ == "__main__":
    main()
