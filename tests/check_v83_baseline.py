"""Guard the v8.3 project baseline and canonical latest mantis model."""
import hashlib
import json
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]
model = root / "assets/models/mantis_latest.glb"
binary = model.read_bytes()
assert len(binary) == 4_280_964, len(binary)
git_blob_sha = hashlib.sha1(b"blob " + str(len(binary)).encode("ascii") + b"\\0" + binary).hexdigest()
assert git_blob_sha == "4536831ef5925acd706a9f607f30d31043e4173c", git_blob_sha
assert binary[:4] == b"glTF"
assert struct.unpack_from("<I", binary, 8)[0] == len(binary)
json_length, json_type = struct.unpack_from("<II", binary, 12)
assert json_type == 0x4E4F534A
document = json.loads(binary[20:20 + json_length].decode("utf-8"))
joint_count = max((len(skin.get("joints", [])) for skin in document.get("skins", [])), default=0)
clips = {item.get("name", "").upper() for item in document.get("animations", [])}
assert joint_count == 62, joint_count
assert len(document.get("meshes", [])) == 247, len(document.get("meshes", []))
required_clips = {"IDLE", "WALK", "ALERT", "GROOM", "HUNT", "STRIKE", "SCAN", "FEED", "CLIMB", "DEFEND"}
required_clips.add("FLY")
assert len(clips) == 11, clips
assert required_clips <= clips, required_clips - clips
legacy_paths = (
    "assets/models/mantis_rigged.glb",
    "assets/models/mantis_rigged.glb.import",
    "assets/models/mantis_detailed.glb",
    "assets/models/mantis_detailed.glb.import",
    "assets/models/mantis_v7_animated.glb",
    "assets/models/mantis_v7_animated.glb.import",
    "scenes/mantis_model_preview.tscn",
    "scenes/mantis_rigged_preview.tscn",
    "scripts/rigged_mantis_preview.gd",
    "tools/generate_latest_mantis_blender.py",
)
for relative_path in legacy_paths:
    assert not (root / relative_path).exists(), relative_path

project = (root / "project.godot").read_text(encoding="utf-8")
presets = (root / "export_presets.cfg").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
assert 'config/version="8.3.0"' in project
assert 'version/code=83' in presets and 'version/name="8.3.0"' in presets
assert 'export_path="build/LivingTerrarium3D-v8.3-ARM64.apk"' in presets
assert 'current_species = ["mantis", "fish", "crayfish", "butterfly", "hermit_crab", "stream_salamander"]' in main
assert 'const LATEST_MANTIS_SCENE: PackedScene = preload("res://assets/models/mantis_latest.glb")' in main
assert 'const RIGGED_MANTIS_SCENE: PackedScene = preload("res://assets/models/mantis_latest.glb")' in main
assert "var use_rigged_visual := false" in main
assert "var use_latest_mantis_visual := true" in main
assert 'var use_photo_visual := false' in main
assert "part.visible = false" in main
assert "mantis_rigged.glb" not in main
workflow = (root / ".github/workflows/android.yml").read_text(encoding="utf-8")
assert "generate_latest_mantis_blender.py" not in workflow
assert "Commit generated latest mantis model" not in workflow
for species_script in (
    "aquarium_system.gd",
    "butterfly_system.gd",
    "hermit_crab_system.gd",
    "stream_valley_system.gd",
):
    assert (root / "scripts" / species_script).is_file()

print("v8.3 baseline passed: recovered canonical GLB is pinned; legacy mantis assets and build-time regeneration are absent")
