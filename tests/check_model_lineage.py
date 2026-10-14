"""Fail a model-changing PR unless its exact Base1 source lineage is recorded."""
import json
import subprocess
import sys
from pathlib import Path

MODEL_PATH = "assets/models/base1.glb"
CHANGE_RECORD = "MODEL_CHANGE.json"


def git(*args: str, check: bool = True) -> str:
    result = subprocess.run(
        ["git", *args], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    if check and result.returncode != 0:
        raise SystemExit(f"STOP: git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def blob(commit: str, path: str) -> str:
    return git("rev-parse", f"{commit}:{path}")


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("Usage: python3 tests/check_model_lineage.py BASE_SHA HEAD_SHA")
    base, head = sys.argv[1:]
    base_model = blob(base, MODEL_PATH)
    head_model = blob(head, MODEL_PATH)

    if base_model == head_model:
        print("Base1 was not changed; no model lineage record is required.")
        return 0

    changed_record = subprocess.run(
        ["git", "diff", "--quiet", base, head, "--", CHANGE_RECORD]
    ).returncode
    if changed_record == 0:
        raise SystemExit(
            f"STOP: {MODEL_PATH} changed without updating {CHANGE_RECORD}. "
            "Run tools/start_mantis_model_edit.sh before editing and "
            "tools/finalize_model_change.py after editing."
        )
    if changed_record != 1:
        raise SystemExit("STOP: could not compare the model lineage record.")

    try:
        record = json.loads(git("show", f"{head}:{CHANGE_RECORD}"))
    except (json.JSONDecodeError, SystemExit) as exc:
        raise SystemExit(f"STOP: {CHANGE_RECORD} is missing or invalid: {exc}") from exc

    required = {
        "source_commit",
        "source_path",
        "source_git_blob_sha",
        "output_git_blob_sha",
        "change_summary",
    }
    missing = sorted(required.difference(record))
    if missing:
        raise SystemExit(f"STOP: {CHANGE_RECORD} is missing fields: {', '.join(missing)}")
    if record["source_path"] != MODEL_PATH:
        raise SystemExit(f"STOP: lineage source path must be {MODEL_PATH}.")
    if not isinstance(record["change_summary"], str) or len(record["change_summary"].strip()) < 12:
        raise SystemExit("STOP: lineage record needs a specific summary of the actual model edits.")

    source_commit = record["source_commit"]
    ancestor = subprocess.run(
        ["git", "merge-base", "--is-ancestor", source_commit, base]
    )
    if ancestor.returncode != 0:
        raise SystemExit("STOP: recorded model source commit is not an ancestor of the PR base.")

    source_blob = blob(source_commit, MODEL_PATH)
    if source_blob != record["source_git_blob_sha"]:
        raise SystemExit("STOP: recorded source blob does not match the model at source_commit.")
    if base_model != source_blob:
        raise SystemExit(
            "STOP: the PR base model differs from the recorded input model. "
            "Restart the edit from the current GitHub main Base1."
        )
    if head_model != record["output_git_blob_sha"]:
        raise SystemExit("STOP: recorded output blob does not match the model in the PR.")
    if head_model == source_blob:
        raise SystemExit("STOP: output model is identical to its recorded source.")

    print("Base1 lineage check passed.")
    print(f"Source commit: {source_commit}")
    print(f"Source blob:   {source_blob}")
    print(f"Output blob:   {head_model}")
    print(f"Change:        {record['change_summary']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
