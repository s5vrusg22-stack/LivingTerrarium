from pathlib import Path
import json
import struct

root = Path(__file__).resolve().parents[1]
asset = root / "assets/models/mantis_detailed_game_asset.glb"
source = (root / "scripts/main.gd").read_text()
raw = asset.read_bytes()
magic, version, declared_size = struct.unpack_from("<III", raw, 0)
assert magic == 0x46546C67 and version == 2 and declared_size == len(raw)

offset = 12
document = None
binary = None
while offset < len(raw):
    chunk_size, chunk_type = struct.unpack_from("<II", raw, offset)
    offset += 8
    chunk = raw[offset : offset + chunk_size]
    offset += chunk_size
    if chunk_type == 0x4E4F534A:
        document = json.loads(chunk.decode("utf-8"))
    elif chunk_type == 0x004E4942:
        binary = chunk

assert document is not None and binary is not None
nodes = document["nodes"]
node_names = {node.get("name", "") for node in nodes}
assert len(nodes) >= 320
assert len(document["meshes"]) >= 300
assert not document.get("animations") and not document.get("skins")
for name in [
    "world",
    "head_capsule",
    "compound_eye",
    "left_forewing",
    "right_forewing",
    "abdomen_segmented_core",
    "raptorial_femur",
    "raptorial_tibia",
    "walking_femur_1",
    "walking_femur_2",
    "walking_femur_4",
    "walking_femur_5",
]:
    assert name in node_names, name

materials = document.get("materials", [])
assert len(materials) >= 80
for material in materials:
    pbr = material.get("pbrMetallicRoughness", {})
    assert pbr.get("metallicFactor", 0.0) == 0.0
    assert pbr.get("roughnessFactor", 0.0) >= 0.65

for marker in [
    'preload("res://assets/models/mantis_detailed_game_asset.glb")',
    'var visual_model_scale := 0.64',
    'rigged_visual.basis = Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, -PI * 0.5)',
    'var leg_indices := [1, 4, 2, 5]',
    'if walking_index == 0 or walking_index == 3:',
    'part_name == "head_capsule"',
    'func _create_source_triangular_head(',
    'func _create_source_hindwing(',
    'func _update_source_model_pose(state: String)',
    'source_walking_knees[i].rotation.y',
    'surface.append_from(part.mesh, surface_index, transform_to_target)',
    'func _soften_source_materials(',
]:
    assert marker in source, marker

triangle_count = 0
for mesh in document["meshes"]:
    for primitive in mesh["primitives"]:
        accessor = document["accessors"][primitive["indices"]]
        triangle_count += accessor["count"] // 3
assert triangle_count >= 45_000

print(
    f"Detailed mantis GLB checks passed ({len(nodes)} nodes, "
    f"{triangle_count:,} triangles, four walking-leg pivots)."
)
