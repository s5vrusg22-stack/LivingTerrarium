"""Pin the photo-refined v8.4 mantis model and Android project baseline."""
import hashlib
import json
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]
model = root / "assets/models/mantis_latest.glb"
binary = model.read_bytes()
assert len(binary) == 4_782_804, len(binary)
git_blob_sha = hashlib.sha1(b"blob " + str(len(binary)).encode("ascii") + b"\0" + binary).hexdigest()
assert git_blob_sha == "89e011d132e9e2d5c0c0fc456336481dbbf5296a", git_blob_sha
assert binary[:4] == b"glTF"
assert struct.unpack_from("<I", binary, 8)[0] == len(binary)
json_length, json_type = struct.unpack_from("<II", binary, 12)
assert json_type == 0x4E4F534A
document = json.loads(binary[20:20 + json_length].decode("utf-8"))

joint_count = max((len(skin.get("joints", [])) for skin in document.get("skins", [])), default=0)
clips = {item.get("name", "").upper() for item in document.get("animations", [])}
assert joint_count == 62, joint_count
assert len(document.get("meshes", [])) == 85, len(document.get("meshes", []))
material_names = {material.get("name", "") for material in document.get("materials", [])}
assert len(material_names) == 17, len(material_names)
assert "Compound eye | deep jade pseudopupil" in material_names
assert "Wing | translucent hindwing" in material_names
assert len(clips) == 11, clips
assert {"IDLE", "WALK", "ALERT", "GROOM", "HUNT", "STRIKE", "SCAN", "FEED", "CLIMB", "DEFEND", "FLY"} <= clips

extras = document.get("asset", {}).get("extras", {})
assert extras.get("title") == "Photo-refined adult mantis"
assert extras.get("revision") == "2026-10-14-photo-refined-v1"
assert {"front", "dorsal", "rear", "left", "right"} <= set(extras.get("referenceViews", []))
assert extras.get("rig") == {"jointCount": 62, "animationClips": 11}
structures = set(extras.get("visibleStructures", []))
assert {
    "compound eyes and pseudopupils", "three ocelli", "curved antennae",
    "pronotum keel and lateral margins", "segmented tergites and sternites",
    "paired spiracles", "folded forewings with branching venation",
    "hindwing membranes", "spined raptorial femora and tibiae",
    "segmented tarsi and terminal claws",
} <= structures

nodes = {node.get("name"): node for node in document.get("nodes", []) if "name" in node}
required_nodes = {
    "DetailPack_Rig_Head", "DetailPack_Rig_Thorax", "DetailPack_Rig_Abdomen",
    "DetailPack_Rig_Wing_L", "DetailPack_Rig_Wing_R",
    "ForeFemur_L", "ForeFemur_R", "ForeTibia_L", "ForeTibia_R",
}
for side in "LR":
    for index in range(3):
        required_nodes.update({f"Coxa_{side}{index}", f"Joint_{side}{index}", f"Tibia_{side}{index}"})
assert required_nodes <= nodes.keys(), required_nodes - nodes.keys()
assert all("mesh" in nodes[name] for name in required_nodes), "A required anatomical node has no mesh"

assert (root / "tools/blender_source/mantis_photo_refined.blend.gz").is_file()
assert (root / "tools/generate_mantis_photo_refined_blender.py").is_file()
assert not (root / "tools/blender_source/mantis_photo_refined.blend1").exists()

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
assert 'config/version="8.4.0"' in project
assert 'version/code=84' in presets and 'version/name="8.4.0"' in presets
assert 'export_path="build/LivingTerrarium3D-v8.4-ARM64.apk"' in presets
assert 'const LATEST_MANTIS_SCENE: PackedScene = preload("res://assets/models/mantis_latest.glb")' in main
assert "_style_rigged_materials(latest_mantis_visual, true)" in main
assert 'part.name.begins_with("DetailPack_Rig_Wing_")' in main
workflow = (root / ".github/workflows/android.yml").read_text(encoding="utf-8")
assert "generate_latest_mantis_blender.py" not in workflow
assert "Commit generated latest mantis model" not in workflow

print("v8.4 photo model passed: 62 joints, 11 clips, distinct anatomical materials, editable source, and Android baseline")
