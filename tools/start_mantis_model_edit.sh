#!/usr/bin/env bash
set -euo pipefail

EXPECTED_MODEL_BLOB_SHA="11f382981fb1afd2b0506a8ddee16b52a55c8259"
MODEL_PATH="assets/models/base1.glb"
REPOSITORY_SUFFIX="s5vrusg22-stack/LivingTerrarium"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "STOP: this directory is not inside the LivingTerrarium Git repository." >&2
  exit 2
}
cd "$repo_root"

origin_url="$(git remote get-url origin 2>/dev/null || true)"
case "$origin_url" in
  *github.com:s5vrusg22-stack/LivingTerrarium*|*github.com/s5vrusg22-stack/LivingTerrarium*) ;;
  *)
    echo "STOP: origin is not $REPOSITORY_SUFFIX (found: $origin_url)." >&2
    exit 2
    ;;
esac

if [[ -n "$(git status --porcelain --untracked-files=all)" ]]; then
  echo "STOP: working tree is not clean. Save or remove changes before starting a new model branch." >&2
  git status --short >&2
  exit 2
fi

git fetch --no-tags origin main
source_commit="$(git rev-parse refs/remotes/origin/main^{commit})"
source_model_blob="$(git rev-parse "$source_commit:$MODEL_PATH")"

if [[ "$source_model_blob" != "$EXPECTED_MODEL_BLOB_SHA" ]]; then
  echo "STOP: GitHub main does not contain the approved locked Base1 model." >&2
  echo "Expected blob: $EXPECTED_MODEL_BLOB_SHA" >&2
  echo "Found blob:    $source_model_blob" >&2
  echo "Do not pick another model. Reconcile the baseline lock explicitly first." >&2
  exit 3
fi

legacy_paths="$(git ls-tree -r --name-only "$source_commit" assets/models | grep -E '(^|/)(mantis_v7_animated|mantis_latest|mantis_detailed|mantis_rigged)\.glb$' || true)"
if [[ -n "$legacy_paths" ]]; then
  echo "STOP: forbidden legacy mantis assets exist in the source commit:" >&2
  echo "$legacy_paths" >&2
  exit 3
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
branch_name="codex/mantis-model-edit-$timestamp-$$"
git switch --create "$branch_name" "$source_commit"

record_path="$(git rev-parse --git-path mantis-model-source.json)"
mkdir -p "$(dirname "$record_path")"
python3 - "$record_path" "$source_commit" "$MODEL_PATH" "$source_model_blob" <<'PY'
import json
import sys

path, commit, asset_path, blob_sha = sys.argv[1:]
with open(path, "w", encoding="utf-8") as f:
    json.dump({
        "source_commit": commit,
        "source_path": asset_path,
        "source_git_blob_sha": blob_sha,
    }, f, indent=2)
    f.write("\n")
PY

model_size="$(git cat-file -s "$source_commit:$MODEL_PATH")"
echo "MODEL SOURCE LOCKED"
echo "Repository: $REPOSITORY_SUFFIX"
echo "Branch:     $branch_name"
echo "Commit:     $source_commit"
echo "Model:      $MODEL_PATH"
echo "Git blob:   $source_model_blob"
echo "Bytes:      $model_size"
echo "Edit this checked-out Base1 only. After a requested model edit, run:"
echo "  python3 tools/finalize_model_change.py --summary 'Describe the reviewed changes'"
