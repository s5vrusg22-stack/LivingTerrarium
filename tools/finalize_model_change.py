"""Write a reviewable lineage record for an intentional Base1 model edit."""
import argparse
import json
import subprocess
from pathlib import Path

MODEL_PATH = "assets/models/base1.glb"


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=root, text=True).strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary", required=True, help="Short description of the requested, reviewed model changes")
    args = parser.parse_args()
    summary = " ".join(args.summary.split())
    if len(summary) < 12 or summary.lower().startswith("pending"):
        parser.error("--summary must describe the actual model edits (at least 12 characters)")

    root = Path(git(Path.cwd(), "rev-parse", "--show-toplevel"))
    record_path = Path(git(root, "rev-parse", "--git-path", "mantis-model-source.json"))
    if not record_path.is_absolute():
        record_path = root / record_path
    if not record_path.is_file():
        raise SystemExit("STOP: source lock is missing. Run bash tools/start_mantis_model_edit.sh first.")

    source = json.loads(record_path.read_text(encoding="utf-8"))
    if source.get("source_path") != MODEL_PATH:
        raise SystemExit(f"STOP: source lock points to unexpected path: {source.get('source_path')}")

    model = root / MODEL_PATH
    if not model.is_file():
        raise SystemExit(f"STOP: canonical model is missing: {MODEL_PATH}")
    output_blob = git(root, "hash-object", MODEL_PATH)
    if output_blob == source.get("source_git_blob_sha"):
        raise SystemExit("STOP: Base1 is byte-identical to the source; there is no model edit to record.")

    source_commit = source.get("source_commit", "")
    if not source_commit or subprocess.run(
        ["git", "merge-base", "--is-ancestor", source_commit, "HEAD"], cwd=root
    ).returncode != 0:
        raise SystemExit("STOP: checked-out work does not descend from the recorded GitHub-main source commit.")

    report = {
        "source_commit": source_commit,
        "source_path": MODEL_PATH,
        "source_git_blob_sha": source["source_git_blob_sha"],
        "output_git_blob_sha": output_blob,
        "change_summary": summary,
    }
    (root / "MODEL_CHANGE.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print("Wrote MODEL_CHANGE.json.")
    print(f"Source commit: {source_commit}")
    print(f"Source blob:   {source['source_git_blob_sha']}")
    print(f"Output blob:   {output_blob}")
    print("Commit MODEL_CHANGE.json with the reviewed model and updated baseline checks.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
