#!/usr/bin/env python3
"""Reject live AWS runtime identifiers from tracked or staged public files."""

import argparse
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
EXAMPLE_ACCOUNT_IDS = {"000000000000", "123456789012"}
RESOURCE_ID = re.compile(r"\b(?:vpc|subnet|sg|eni|nat|igw|eipalloc|lt)-[0-9a-f]{8,17}\b")
ACCOUNT_ID = re.compile(r"(?<![0-9])[0-9]{12}(?![0-9])")
RDS_SECRET = re.compile(r"\brds!db-[0-9a-f-]{20,}\b")


def git_bytes(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def selected_files(staged):
    command = ["diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z"] if staged else ["ls-files", "-z"]
    return [Path(item.decode()) for item in git_bytes(*command).split(b"\0") if item]


def contents(path, staged):
    if staged:
        return git_bytes("show", ":" + path.as_posix()).decode(errors="replace")
    return (ROOT / path).read_text(errors="replace")


def findings(path, text):
    results = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        for match in ACCOUNT_ID.finditer(line):
            if match.group() not in EXAMPLE_ACCOUNT_IDS:
                results.append((line_number, "live 12-digit AWS account ID"))
        if RESOURCE_ID.search(line):
            results.append((line_number, "live AWS resource ID"))
        if RDS_SECRET.search(line):
            results.append((line_number, "RDS managed-secret identifier"))
    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--staged", action="store_true")
    args = parser.parse_args()
    errors = []
    for path in selected_files(args.staged):
        try:
            text = contents(path, args.staged)
        except (OSError, subprocess.CalledProcessError):
            continue
        errors.extend((path, line, reason) for line, reason in findings(path, text))
    if errors:
        for path, line, reason in errors:
            print(f"{path}:{line}: blocked public runtime identifier ({reason})")
        return 1
    scope = "staged" if args.staged else "tracked"
    print(f"Public-repository identifier guard passed for {scope} files.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
