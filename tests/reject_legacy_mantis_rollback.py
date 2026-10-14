"""Reject commits that add or update a GLB back to the known obsolete mantis asset."""
from __future__ import annotations

import subprocess
import sys

OBSOLETE_MANTIS_BLOB_SHA = "4536831ef5925acd706a9f607f30d31043e4173c"


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: reject_legacy_mantis_rollback.py BASE_SHA HEAD_SHA")

    base_sha, head_sha = sys.argv[1:]
    changed_paths = git(
        "diff", "--name-only", base_sha, head_sha, "--", "assets/models"
    ).splitlines()

    rejected = []
    for path in changed_paths:
        if not path.lower().endswith(".glb"):
            continue
        try:
            blob_sha = git("rev-parse", f"{head_sha}:{path}")
        except subprocess.CalledProcessError:
            # A removed file cannot make the obsolete model active.
            continue
        if blob_sha == OBSOLETE_MANTIS_BLOB_SHA:
            rejected.append(path)

    if rejected:
        paths = ", ".join(rejected)
        raise SystemExit(
            f"Refusing obsolete mantis GLB {OBSOLETE_MANTIS_BLOB_SHA} "
            f"reintroduced or updated at: {paths}"
        )

    print("No changed mantis GLB uses the obsolete recovered model.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
