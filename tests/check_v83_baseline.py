"""Pin the approved v8.3 model and verify photo details preserve its rig."""
import copy
import hashlib
import json
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]
model = root / "assets/models/mantis_latest.glb"
data = model.read_bytes()

assert data[:4] == b"glTF"
assert struct.unpack_from("<I", data, 4)[0] == 2
assert struct.unpack_from("<I", data, 8)[0] == len(data)
json_length, json_type = struct.unpack_from("<II", data, 12)
assert json_type == 0x4E4F534A
document = json.loads(data[20:20 + json_length].decode("utf-8"))
bin_header = 20 + json_length
bin_length, bin_type = struct.unpack_from("<II", data, bin_header)
assert bin_type == 0x004E4942
binary = data[bin_header + 8:bin_header + 8 + bin_length]

canonical = lambda value: json.dumps(
    value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
).encode("utf-8")
digest = lambda value: hashlib.sha256(canonical(value)).hexdigest()

# The v8.3 source BIN and all animation data must remain unchanged.
source_bin_length = 3_573_776
assert hashlib.sha256(binary[:source_bin_length]).hexdigest() == (
    "e3fe7743b601b11d2734278905ce377e95fa3862d323d9384f37d42df69bb904"
)
assert len(document["meshes"]) == 229
assert len(document["nodes"]) == 292
assert len(document["materials"]) == 9
assert len(document["accessors"]) == 3_251
assert len(document["bufferViews"]) == 3_251
assert digest(document["meshes"][:225]) == (
    "885094a66ef2f825f74ab74a698df08f6ffb0d141b3895a90f01e11653e52b82"
)
assert digest(document["materials"][:8]) == (
    "296ebc26997e9f45dc619da6c8a4c81c4f4775c1174b3e6b61301c783e14f6f4"
)
assert digest(document["accessors"][:3_231]) == (
    "1b5eb507e1a7f5a8abfe337a0949563fe656b146e66acd58f922befe65b254c9"
)
assert digest(document["bufferViews"][:3_231]) == (
    "e5dc610279cd05b2dc0ec41662ee7458fab27ed9dd1bb61c13c8421e6412b538"
)
assert digest(document["skins"]) == (
    "78cf770861b723f83b058a11208d45cf7297e406e7b7320442ece9d0113ea26c"
)
assert digest(document["animations"]) == (
    "fa911fcc9cb56733285c4604ade67eaca80ea930853a2c36359d5eae58ff4150"
)

# Only the four refinement nodes may be added under the original rig root.
original_nodes = copy.deepcopy(document["nodes"][:288])
rig_root = next(node for node in original_nodes if node.get("name") == "MantisRig")
rig_root["children"] = [index for index in rig_root.get("children", []) if index < 288]
assert digest(original_nodes) == (
    "4a8d860890b94b110623f0b958e53a87dd7cb1036fd6211e4f398004d3cba3b4"
)
added_names = {
    "PhotoEyeFacet_L", "PhotoEyeFacet_R",
    "WingVeinDetail_Fine_L", "WingVeinDetail_Fine_R",
}
assert {node.get("name") for node in document["nodes"][288:]} == added_names
assert {mesh.get("name") for mesh in document["meshes"][225:]} == added_names
assert set(rig_root["children"]) <= set(range(288))
root_node = next(node for node in document["nodes"] if node.get("name") == "MantisRig")
assert set(range(288, 292)) <= set(root_node.get("children", []))

skin_count = max(len(skin.get("joints", [])) for skin in document.get("skins", []))
clips = {animation.get("name", "").upper() for animation in document.get("animations", [])}
assert skin_count == 62
assert clips == {
    "IDLE", "WALK", "ALERT", "GROOM", "HUNT", "STRIKE",
    "SCAN", "FEED", "CLIMB", "DEFEND", "FLY",
}

extras = document.get("asset", {}).get("extras", {}).get("mantisPhotoRefinement", {})
assert extras.get("revision") == "v8.3-base-photo-refinement-1"
assert extras.get("sourceModelGitBlob") == "4536831ef5925acd706a9f607f30d31043e4173c"
assert extras.get("sourceModelPath") == "assets/models/mantis_latest.glb at 1bdf2ee"
assert extras.get("animationData") == "retained byte-for-byte from the v8.3 source GLB"
assert extras.get("newEyeFacetCount") == 158
assert extras.get("fineCrossVeinRowsByWing") == {"L": 14, "R": 14}
eye_facets = 0
for mesh in document["meshes"][225:227]:
    index_accessor = document["accessors"][mesh["primitives"][0]["indices"]]
    eye_facets += index_accessor["count"] // 18
assert eye_facets == 158

model_glbs = sorted(path.name for path in (root / "assets/models").glob("mantis*.glb"))
assert model_glbs == ["mantis_latest.glb"], model_glbs
obsolete_paths = (
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
    "tools/generate_mantis_photo_refined_blender.py",
    "tools/blender_source/mantis_photo_refined.blend.gz",
    "README_v8.4.md",
    "tests/check_v84_photo_model.py",
)
for relative_path in obsolete_paths:
    assert not (root / relative_path).exists(), relative_path

project = (root / "project.godot").read_text(encoding="utf-8")
presets = (root / "export_presets.cfg").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
assert 'config/version="8.3.0"' in project
assert 'version/code=83' in presets and 'version/name="8.3.0"' in presets
assert 'export_path="build/LivingTerrarium3D-v8.3-ARM64.apk"' in presets
assert 'const LATEST_MANTIS_SCENE: PackedScene = preload("res://assets/models/mantis_latest.glb")' in main
assert 'const RIGGED_MANTIS_SCENE: PackedScene = preload("res://assets/models/mantis_latest.glb")' in main
assert "_style_rigged_materials(latest_mantis_visual)" in main
assert "preserve_imported_materials" not in main
workflow = (root / ".github/workflows/android.yml").read_text(encoding="utf-8")
assert "python3 tools/refine_v83_mantis_glb.py" in workflow
assert "git diff --exit-code -- assets/models/mantis_latest.glb" in workflow
assert "check_v83_baseline.py" in workflow
assert "v8.4" not in workflow

print("v8.3 photo refinement passed: pinned source, unchanged rig and clips, 158 eye facets, 28 wing cross-veins, one canonical model")
