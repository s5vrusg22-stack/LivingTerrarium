"""Guard Base 1's approved scene, improved proportions, and new save/life-stage behavior."""
import json
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
model = (root / "assets/models/base1.glb").read_bytes()
magic, version, total = struct.unpack_from("<III", model, 0)
assert (magic, version, total) == (0x46546C67, 2, len(model))
json_length, json_kind = struct.unpack_from("<II", model, 12)
assert json_kind == 0x4E4F534A
doc = json.loads(model[20 : 20 + json_length].decode("utf-8").rstrip(" \0"))
nodes = {index: node.get("name", "") for index, node in enumerate(doc["nodes"])}
node_by_name = {node.get("name"): node for node in doc["nodes"]}
assert {"MantisRoot", "Pronotum", "Head", "Raptor_L_Coxa", "Raptor_R_Coxa"} <= set(node_by_name)
assert len(doc["nodes"]) == 38
clips = {animation.get("name", "").upper() for animation in doc.get("animations", [])}
assert clips == {"IDLE", "WALK", "ALERT", "STRIKE", "GROOM", "FEED"}
walk = next(animation for animation in doc["animations"] if animation.get("name", "").upper() == "WALK")
assert not any(
    nodes[channel["target"]["node"]] == "Head" and channel["target"]["path"] == "rotation"
    for channel in walk["channels"]
)
assert abs(node_by_name["Head"]["translation"][2] + 0.14) < 1e-6

# Read selected accessor bounds directly from the original GLB binary chunk.
bin_header = 20 + json_length
bin_length, bin_kind = struct.unpack_from("<II", model, bin_header)
assert bin_kind == 0x004E4942
binary = model[bin_header + 8 : bin_header + 8 + bin_length]
def accessor_values(accessor_index):
    accessor = doc["accessors"][accessor_index]
    view = doc["bufferViews"][accessor["bufferView"]]
    component = {5126: ("f", 4), 5123: ("H", 2), 5125: ("I", 4)}[accessor["componentType"]]
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    stride = view.get("byteStride", component[1] * width)
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    return [
        struct.unpack_from("<" + component[0] * width, binary, offset + i * stride)
        for i in range(accessor["count"])
    ]
def primitive_positions(node_name, primitive_index=0):
    mesh = doc["meshes"][node_by_name[node_name]["mesh"]]
    return accessor_values(mesh["primitives"][primitive_index]["attributes"]["POSITION"])
pronotum_z = [point[2] for point in primitive_positions("Pronotum")]
assert min(pronotum_z) < -1.14, min(pronotum_z)
for side in ("L", "R"):
    coxa_y = [point[1] for point in primitive_positions(f"Raptor_{side}_Coxa")]
    assert max(coxa_y) > 0.65
    femur_y = node_by_name[f"Raptor_{side}_Femur"]["translation"][1]
    assert femur_y > 0.65

materials = {material["name"]: material["pbrMetallicRoughness"] for material in doc["materials"]}
assert materials["cuticle"]["baseColorFactor"] == [0.31, 0.49, 0.22, 1.0]
assert materials["cuticle"]["roughnessFactor"] >= 0.58
assert materials["wing"]["baseColorFactor"] == [0.46, 0.62, 0.33, 1.0]

# Restore the V7 green palette per surface and add cuticle detail without flattening differences.
style = main.split("func _style_rigged_materials", 1)[1].split("func _find_rigged_player", 1)[0]
assert "part.material_override = null" in style
assert "part.set_surface_override_material(surface_index, mat)" in style
assert "mat.detail_enabled = true" in style
assert 'mat.albedo_color = Color(0.39, 0.66, 0.22)' in style
assert 'mat.albedo_color = Color(0.52, 0.73, 0.31)' in style
assert "Color(0.43, 0.54, 0.26)" not in style

# The six nymph stages remain selectable, visibly scaled, and distinct from adults.
assert 'LIFE_STAGES: Array[String] = ["1령 약충", "2령 약충", "3령 약충", "4령 약충", "5령 약충", "6령 약충", "성체"]' in main
assert "NYMPH_SIZE_FACTORS: Array[float] = [0.23, 0.30, 0.40, 0.52, 0.67, 0.84]" in main
assert "buds.visible = is_juvenile" in main
assert 'part.visible = not is_juvenile' in main

# Enclosure volume grows ~30x from the previous 1.71 scale; plants reach high into it.
assert "const HABITAT_LINEAR_SCALE := 5.31" in main
assert "const CAMERA_MAX_DISTANCE := 110.0" in main
assert "HABITAT_CEILING_Y * 0.58" in main and "HABITAT_CEILING_Y * 0.88" in main
assert 'leaf.name = "ClimbPlantLeaf_' in main
assert 'leaf_material.albedo_texture = foliage_texture' in main
assert 'mat.albedo_color = Color(0.82, 0.67, 0.48)' in main
assert 'env.ambient_light_energy = 0.58' in main
assert 'sun.shadow_opacity = 0.56' in main

# More than one named mantis is stored in a separate, bounded collection file.
assert 'MANTIS_COLLECTION_PATH := "user://mantis_collection_v1.json"' in main
assert "const MAX_SAVED_MANTISES := 24" in main
for function_name in (
    "_capture_mantis_state", "_load_mantis_collection", "_write_mantis_collection",
    "_save_current_mantis_profile", "_load_selected_mantis_profile",
    "_update_selected_mantis_profile", "_delete_selected_mantis_profile",
):
    assert f"func {function_name}" in main
assert '"mantises": saved_mantises' in main

print("Base 1 refinement check passed: original rig/clips retained, neck and foreleg proportions adjusted, six instars and multi-mantis saves verified.")
