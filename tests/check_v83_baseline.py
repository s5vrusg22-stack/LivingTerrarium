"""Pin the model selected by the successful v8.3 APK and verify its refinement."""
import copy
import hashlib
import json
import struct
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "assets/models/mantis_latest.glb"
SOURCE_COMMIT = "bb32cf56b468a1a9b441bbade3d447e6b36e2416"
SOURCE_PATH = "assets/models/mantis_v7_animated.glb"
SOURCE_BLOB_SHA1 = "11f382981fb1afd2b0506a8ddee16b52a55c8259"


def parse_glb(data: bytes) -> tuple[dict, bytes]:
    assert data[:4] == b"glTF"
    version, total_length = struct.unpack_from("<II", data, 4)
    assert version == 2 and total_length == len(data)
    offset = 12
    document = binary = None
    while offset < len(data):
        length, chunk_type = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk = data[offset:offset + length]
        offset += length
        if chunk_type == 0x4E4F534A:
            document = json.loads(chunk.decode("utf-8"))
        elif chunk_type == 0x004E4942:
            binary = chunk
    assert document is not None and binary is not None
    return document, binary


def git_blob_sha1(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()


source_data = subprocess.check_output(
    ["git", "show", f"{SOURCE_COMMIT}:{SOURCE_PATH}"], cwd=ROOT
)
assert git_blob_sha1(source_data) == SOURCE_BLOB_SHA1
source_doc, source_bin = parse_glb(source_data)
data = MODEL.read_bytes()
document, binary = parse_glb(data)

# The model actually used by the 8.3 APK remains the geometry/material/animation
# base. The only new geometry is parented beneath its two existing wing nodes.
assert binary.startswith(source_bin)
assert len(document["meshes"]) == len(source_doc["meshes"]) + 2
assert len(document["nodes"]) == len(source_doc["nodes"]) + 2
assert len(document["materials"]) == len(source_doc["materials"])
assert len(document["accessors"]) == len(source_doc["accessors"]) + 6
assert len(document["bufferViews"]) == len(source_doc["bufferViews"]) + 6
assert document["meshes"][:len(source_doc["meshes"])] == source_doc["meshes"]
assert document["materials"] == source_doc["materials"]
assert document["animations"] == source_doc["animations"]
assert document.get("skins", []) == source_doc.get("skins", [])
assert document["accessors"][:len(source_doc["accessors"])] == source_doc["accessors"]
assert document["bufferViews"][:len(source_doc["bufferViews"])] == source_doc["bufferViews"]

original_nodes = copy.deepcopy(document["nodes"][:len(source_doc["nodes"])])
for node in original_nodes:
    if node.get("name") in {"Wing_L", "Wing_R"}:
        node["children"] = [child for child in node.get("children", [])
                            if child < len(source_doc["nodes"])]
assert original_nodes == source_doc["nodes"]

added_names = {"WingVeinDetail_Fine_L", "WingVeinDetail_Fine_R"}
assert {node.get("name") for node in document["nodes"][len(source_doc["nodes"]):]} == added_names
assert {mesh.get("name") for mesh in document["meshes"][len(source_doc["meshes"]):]} == added_names
for side in ("L", "R"):
    parent = next(node for node in document["nodes"] if node.get("name") == f"Wing_{side}")
    assert len(parent.get("children", [])) == 1
    child = document["nodes"][parent["children"][0]]
    assert child.get("name") == f"WingVeinDetail_Fine_{side}"

clips = {animation.get("name", "").upper() for animation in document["animations"]}
assert clips == {"IDLE", "WALK", "ALERT", "STRIKE", "GROOM", "FEED"}
head = next(node for node in document["nodes"] if node.get("name") == "Head")
head_mesh = document["meshes"][head["mesh"]]
material_names = {material.get("name") for material in document["materials"]}
assert {"eye", "eye_facet", "face_mark", "mouth", "vein"} <= material_names
assert any(document["materials"][primitive["material"]]["name"] == "eye_facet"
           and document["accessors"][primitive["attributes"]["POSITION"]]["count"] >= 5000
           for primitive in head_mesh["primitives"])

extras = document.get("asset", {}).get("extras", {}).get("mantisPhotoRefinement", {})
assert extras.get("revision") == "v8.3-apk-model-photo-refinement-1"
assert extras.get("sourceModelGitBlob") == SOURCE_BLOB_SHA1
assert extras.get("sourceModelPath") == f"{SOURCE_PATH} at bb32cf5"
assert extras.get("animationData") == "all six v8.3 animation clips retained byte-for-byte"
assert extras.get("fineCrossVeinRowsByWing") == {"L": 14, "R": 14}

model_glbs = sorted(path.name for path in (ROOT / "assets/models").glob("mantis*.glb"))
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
    assert not (ROOT / relative_path).exists(), relative_path

project = (ROOT / "project.godot").read_text(encoding="utf-8")
presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
assert 'config/version="8.3.0"' in project
assert 'version/code=83' in presets and 'version/name="8.3.0"' in presets
assert 'export_path="build/LivingTerrarium3D-v8.3-ARM64.apk"' in presets
canonical = 'res://assets/models/mantis_latest.glb'
assert f'const LATEST_MANTIS_SCENE: PackedScene = preload("{canonical}")' in main
assert f'const RIGGED_MANTIS_SCENE: PackedScene = preload("{canonical}")' in main
assert "_style_rigged_materials(latest_mantis_visual, true)" in main
assert "_style_rigged_materials(social_partner, true)" in main
assert "preserve_imported_materials" in main
workflow = (ROOT / ".github/workflows/android.yml").read_text(encoding="utf-8")
assert "python3 tools/refine_v83_mantis_glb.py" in workflow
assert "git diff --exit-code -- assets/models/mantis_latest.glb" in workflow
assert "check_v83_baseline.py" in workflow
assert "v8.4" not in workflow
readme = (ROOT / "README.md").read_text(encoding="utf-8")
assert SOURCE_BLOB_SHA1 in readme and "mantis_v7_animated.glb" in readme
assert "62-joint rig" not in readme

print("v8.3 APK model check passed: pinned source, preserved original mesh/materials/six clips, 28 wing cross-veins, one canonical model")
