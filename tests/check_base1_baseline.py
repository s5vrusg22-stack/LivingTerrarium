"""Pin Base 1 and make the source-of-truth instructions part of CI."""
from hashlib import sha1
from pathlib import Path

root = Path(__file__).resolve().parents[1]
models = root / "assets/models"
model = models / "base1.glb"
data = model.read_bytes()
approved_git_blob_sha = "98981e073f8a4fffb00efb71e669f6232c45b08d"
git_blob_sha = sha1(b"blob " + str(len(data)).encode("ascii") + bytes([0]) + data).hexdigest()
assert len(data) == 2_779_864, len(data)
assert git_blob_sha == approved_git_blob_sha, git_blob_sha

# Keep the agent instructions, human-facing provenance, executable model,
# and CI expectations tied to the same approved source.
agent_rules = (root / "AGENTS.md").read_text(encoding="utf-8")
readme = (root / "README_v8.3.md").read_text(encoding="utf-8")
for required in (
    "Read this file and `README_v8.3.md`.",
    "`assets/models/base1.glb`",
    approved_git_blob_sha,
    "known-good v8.3 APK",
    "Do not begin model or simulation edits until",
    "Do not add a fallback",
    "Never substitute another mantis",
    "Never change the expected SHA merely to make a failing check pass.",
    "## Mandatory gate before any mantis modeling",
    "`bash tools/start_mantis_model_edit.sh`",
    "`python3 tools/finalize_model_change.py --summary",
    "A changed model without a matching lineage record fails CI.",
):
    assert required in agent_rules, f"AGENTS.md is missing required source rule: {required}"
assert approved_git_blob_sha in readme
assert "known-good v8.3 APK" in readme
assert "assets/models/base1.glb" in readme

sidecar_path = models / "base1.glb.import"
assert sidecar_path.is_file()
sidecar = sidecar_path.read_text(encoding="utf-8")
assert 'source_file="res://assets/models/base1.glb"' in sidecar
assert 'nodes/root_name="Base1"' in sidecar

project = (root / "project.godot").read_text(encoding="utf-8")
presets = (root / "export_presets.cfg").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
workflow = (root / ".github/workflows/android.yml").read_text(encoding="utf-8")
runtime_check = (root / "tests/check_mantis_model_default.gd").read_text(encoding="utf-8")
assert 'config/version="1.0.0"' in project
assert 'version/code=84' in presets and 'version/name="1.0.0"' in presets
assert 'export_path="build/LivingTerrarium3D-Base1-v1.0.0-ARM64.apk"' in presets
assert main.count('preload("res://assets/models/base1.glb")') == 2
assert 'base1_mantis_visual.name = "Base1"' in main

legacy_model_files = (
    "mantis_v7_animated.glb",
    "mantis_latest.glb",
    "mantis_detailed.glb",
    "mantis_rigged.glb",
)
for legacy_file in legacy_model_files:
    assert legacy_file not in main, f"Runtime code references a prohibited model: {legacy_file}"
    assert legacy_file not in workflow, f"CI workflow references a prohibited model: {legacy_file}"

model_files = sorted(path.name for path in models.glob("*.glb"))
assert model_files == ["base1.glb", "blue_yabby.glb"], model_files
for legacy_file in legacy_model_files:
    assert not (models / legacy_file).exists(), f"Prohibited model file exists: {legacy_file}"

assert 'python3 tests/check_base1_baseline.py' in workflow
assert 'model-baseline-guard:' in workflow
assert 'needs: model-baseline-guard' in workflow
assert 'python3 tests/check_model_lineage.py' in workflow
assert (root / 'tests/check_model_lineage.py').is_file()
assert (root / 'tools/start_mantis_model_edit.sh').is_file()
assert (root / 'tools/finalize_model_change.py').is_file()
assert 'godot --headless --path . --script res://tests/check_mantis_model_default.gd' in workflow
assert 'python3 tests/check_base1_apk.py build/LivingTerrarium3D-Base1-v1.0.0-ARM64.apk' in workflow

for runtime_guard in (
    'if app.get("use_base1_mantis_visual") != true:',
    'if app.get("use_photo_visual") != false:',
    "A procedural fallback mesh is visible instead of the Base 1 GLB",
    "Expected selectable instars 1 through 6 and adult",
    "A second mantis visual is visible alongside the Base 1 GLB",
):
    assert runtime_guard in runtime_check, (
        f"Runtime regression test is missing a required source-of-truth guard: {runtime_guard}"
    )

print(
    "Base 1 source contract passed: exact approved V7-derived GLB bytes, recorded "
    "model lineage, matching agent and human documentation, canonical runtime path, "
    "no legacy model substitution, and CI/runtime guards."
)
