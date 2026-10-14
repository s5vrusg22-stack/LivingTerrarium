"""Pin the exact mantis model from the known-good v8.3 APK."""
from hashlib import sha1
from pathlib import Path

root = Path(__file__).resolve().parents[1]
model = root / "assets/models/mantis_v7_animated.glb"
data = model.read_bytes()
git_blob_sha = sha1(f"blob {len(data)}\\0".encode("ascii") + data).hexdigest()
assert git_blob_sha == "11f382981fb1afd2b0506a8ddee16b52a55c8259", git_blob_sha
assert (root / "assets/models/mantis_v7_animated.glb.import").is_file()

project = (root / "project.godot").read_text(encoding="utf-8")
presets = (root / "export_presets.cfg").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
workflow = (root / ".github/workflows/android.yml").read_text(encoding="utf-8")
assert 'config/version="8.3.0"' in project
assert 'version/code=83' in presets and 'version/name="8.3.0"' in presets
assert 'export_path="build/LivingTerrarium3D-v8.3-ARM64.apk"' in presets
assert main.count('preload("res://assets/models/mantis_v7_animated.glb")') == 2
assert "mantis_latest.glb" not in main
assert "mantis_latest.glb" not in workflow
assert "refine_v83_mantis_glb.py" not in workflow
mantis_models = sorted(path.name for path in (root / "assets/models").glob("mantis*.glb"))
assert "mantis_v7_animated.glb" in mantis_models, mantis_models

for species_script in (
    "aquarium_system.gd",
    "blue_crayfish_habitat.gd",
    "butterfly_system.gd",
    "hermit_crab_system.gd",
    "stream_valley_system.gd",
):
    assert (root / "scripts" / species_script).is_file(), species_script

print("v8.3 baseline passed: exact known-good V7 GLB, runtime references, Android version, and habitat scripts")
