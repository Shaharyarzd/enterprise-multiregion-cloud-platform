#!/usr/bin/env python3
"""Update only the production CareFlow ECR repository and immutable digest."""

import argparse
from pathlib import Path
import re


def update(path, repository, digest):
    if not re.fullmatch(r"[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com/[a-z0-9/_-]+", repository):
        raise ValueError("repository must be a private Amazon ECR repository URL")
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        raise ValueError("digest must be an immutable sha256 digest")

    text = path.read_text()
    text, repository_count = re.subn(
        r"(?m)^(\s*newName:)\s+.*$", rf"\1 {repository}", text, count=1
    )
    text, digest_count = re.subn(
        r"(?m)^(\s*digest:)\s+.*$", rf"\1 {digest}", text, count=1
    )
    if repository_count != 1 or digest_count != 1:
        raise ValueError("production image fields were not found exactly once")
    path.write_text(text)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository", required=True)
    parser.add_argument("--digest", required=True)
    parser.add_argument(
        "--file",
        type=Path,
        default=Path("k8s/overlays/production/kustomization.yaml"),
    )
    args = parser.parse_args()
    update(args.file, args.repository, args.digest)


if __name__ == "__main__":
    main()
