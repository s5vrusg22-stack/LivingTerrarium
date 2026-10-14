"""Pin Base 1 and release 1.0.0 to the exact approved model binary."""
from hashlib import sha1
from pathlib import Path

root = Path(__file__).resolve().parents[1]
models = root / "assets/models"
model = models / "base1.glb"
data = model.read_bytes()
git_blob_sha = sha1(b"blob " + str(len(data)).encode("ascii") + bytes([0]) + data).hexdigest()
assert git_blob_sha == "11f382981fb1afd2b0506a8ddee16b52a55c8259", git_blob_sha

sidecar_path = models / "base1.glb.import"
assert sidecar_path.is_file()
sidecar = sidecar_path.read_text(encoding="utf-8")
assert 'source_file="res://assets/models/base1.glb"' in sidecar
assert 'nodes/root_name="Base1"' in sidecar

project = (root / "project.godot").read_text(encoding="utf-8")
presets = (root / "export_presets.cfg").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
workflow = (root / ".github/workflows/android.yml").read_text(encoding="utf-8")
assert 'config/version="1.0.0"' in project
assert 'version/code=84' in presets and 'version/name="1.0.0"' in presets
assert 'export_path="build/LivingTerrarium3D-Base1-v1.0.0-ARM64.apk"' in presets
assert main.count('preload("res://assets/models/base1.glb")') == 2
assert 'base1_mantis_visual.name = "Base1"' in main
assert "mantis_v7_animated.glb" not in main
assert "mantis_latest.glb" not in main
assert "LatestMantis" not in main and "latest_mantis" not in main
assert "mantis_v7_animated.glb" not in workflow
assert "LivingTerrarium3D-Base1-v1.0.0-ARM64.apk" in workflow

model_files = sorted(path.name for path in models.glob("*.glb"))
assert model_files == ["base1.glb", "blue_yabby.glb"], model_files
assert not (models / "mantis_v7_animated.glb").exists()
assert not (models / "mantis_latest.glb").exists()
assert not (models / "mantis_rigged.glb").exists()

for species_script in (
    "aquarium_system.gd",
    "blue_crayfish_habitat.gd",
    "butterfly_system.gd",
    "hermit_crab_system.gd",
    "stream_valley_system.gd",
):
    assert (root / "scripts" / species_script).is_file(), species_script

print("Base 1 release check passed: exact approved GLB, Base1 import/runtime name, and Android version 1.0.0.")
