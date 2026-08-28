#!/usr/bin/env python3
"""Promote only an immutable digest; runtime injects the private ECR URL."""

import argparse
from pathlib import Path
import re


def update(path, digest):
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        raise ValueError("digest must be an immutable sha256 digest")

    text = path.read_text()
    text, digest_count = re.subn(
        r"(?m)^(\s*digest:)\s+.*$", rf"\1 {digest}", text, count=1
    )
    if digest_count != 1:
        raise ValueError("production image digest was not found exactly once")
    path.write_text(text)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--digest", required=True)
    parser.add_argument(
        "--file",
        type=Path,
        default=Path("k8s/overlays/production/kustomization.yaml"),
    )
    args = parser.parse_args()
    update(args.file, args.digest)


if __name__ == "__main__":
    main()
