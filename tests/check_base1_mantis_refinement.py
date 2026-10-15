"""Guard Base 1's anatomy, wing surfaces/materials, scene, and life-stage behavior."""
import json
import math
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
assert node_by_name["Head"]["translation"] == [0.0, 1.27, -1.38]

# Read selected accessor bounds directly from the original GLB binary chunk.
bin_header = 20 + json_length
bin_length, bin_kind = struct.unpack_from("<II", model, bin_header)
assert bin_kind == 0x004E4942
binary = model[bin_header + 8 : bin_header + 8 + bin_length]
assert doc["buffers"][0]["byteLength"] <= len(binary)
assert len(binary) - doc["buffers"][0]["byteLength"] <= 3
component_sizes = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
component_widths = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}
for view in doc["bufferViews"]:
    start = view.get("byteOffset", 0)
    assert view["buffer"] == 0 and start + view["byteLength"] <= len(binary)
for accessor in doc["accessors"]:
    if "bufferView" not in accessor:
        continue
    view = doc["bufferViews"][accessor["bufferView"]]
    item = component_sizes[accessor["componentType"]] * component_widths[accessor["type"]]
    stride = view.get("byteStride", item)
    end = view.get("byteOffset", 0) + accessor.get("byteOffset", 0) + (accessor["count"] - 1) * stride + item
    assert end <= view.get("byteOffset", 0) + view["byteLength"]
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
parent_by_node = {child: index for index, node in enumerate(doc["nodes"]) for child in node.get("children", [])}
world_cache = {}
def multiply_matrices(a, b):
    return [[sum(a[row][k] * b[k][column] for k in range(4)) for column in range(4)] for row in range(4)]
def local_matrix(index):
    node = doc["nodes"][index]
    if "matrix" in node:
        values = node["matrix"]
        return [[values[column * 4 + row] for column in range(4)] for row in range(4)]
    x, y, z, w = node.get("rotation", (0.0, 0.0, 0.0, 1.0))
    rotation = (
        (1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)),
        (2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)),
        (2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)),
    )
    scale = node.get("scale", (1.0, 1.0, 1.0))
    translation = node.get("translation", (0.0, 0.0, 0.0))
    return [[rotation[row][column] * scale[column] for column in range(3)] + [translation[row]] for row in range(3)] + [[0.0, 0.0, 0.0, 1.0]]
def world_matrix(index):
    if index not in world_cache:
        local = local_matrix(index)
        parent = parent_by_node.get(index)
        world_cache[index] = multiply_matrices(world_matrix(parent), local) if parent is not None else local
    return world_cache[index]
def transformed_point(matrix, point):
    values = (*point, 1.0)
    return tuple(sum(matrix[row][column] * values[column] for column in range(4)) for row in range(3))
def mean_point(points):
    return tuple(sum(point[axis] for point in points) / len(points) for axis in range(3))

# Keep zero-area faces out of the canonical model. These collapsed triangles
# can produce invalid normals during Godot LOD generation and flickering seams.
for mesh_index, mesh in enumerate(doc["meshes"]):
    mesh_nodes = [node.get("name", "") for node in doc["nodes"] if node.get("mesh") == mesh_index]
    for primitive_index, primitive in enumerate(mesh.get("primitives", [])):
        if primitive.get("mode", 4) != 4 or "indices" not in primitive:
            continue
        positions = accessor_values(primitive["attributes"]["POSITION"])
        indices = [row[0] for row in accessor_values(primitive["indices"])]
        assert len(indices) % 3 == 0
        for start in range(0, len(indices), 3):
            a, b, c = (positions[indices[start + offset]] for offset in range(3))
            ab = tuple(b[axis] - a[axis] for axis in range(3))
            ac = tuple(c[axis] - a[axis] for axis in range(3))
            cross = (
                ab[1] * ac[2] - ab[2] * ac[1],
                ab[2] * ac[0] - ab[0] * ac[2],
                ab[0] * ac[1] - ab[1] * ac[0],
            )
            assert all(math.isfinite(value) for value in cross)
            area_squared = sum(value * value for value in cross)
            assert area_squared > 1e-20, (mesh_nodes, primitive_index, start // 3)

pronotum_points = primitive_positions("Pronotum")
pronotum_z = [point[2] for point in pronotum_points]
assert min(pronotum_z) < -1.56, min(pronotum_z)
neck_tip = [point for point in pronotum_points if point[2] < -1.55]
assert max(point[0] for point in neck_tip) - min(point[0] for point in neck_tip) < 0.16
abdomen_points = primitive_positions("Abdomen", 0) + primitive_positions("Abdomen", 1)
abdomen_x = [point[0] for point in abdomen_points]
abdomen_y = [point[1] for point in abdomen_points]
abdomen_z = [point[2] for point in abdomen_points]
assert max(abdomen_x) - min(abdomen_x) < 0.70
assert max(abdomen_y) - min(abdomen_y) < 0.50
assert max(abdomen_z) - min(abdomen_z) > 2.45
abdomen = doc["meshes"][node_by_name["Abdomen"]["mesh"]]["primitives"][0]
abdomen_vertices = accessor_values(abdomen["attributes"]["POSITION"])
abdomen_colors = accessor_values(abdomen["attributes"]["COLOR_0"])
assert len(abdomen_vertices) > 3000  # subdivided from the existing Base 1 shell for soft segment grooves
abdomen_sections = {}
for point, color in zip(abdomen_vertices, abdomen_colors):
    z = round(point[2], 4)
    row = abdomen_sections.setdefault(z, [[], []])
    center_y = 0.84 - 0.012 * min(max(point[2], 0.0), 2.0)
    row[0].append((point[0] ** 2 + (point[1] - center_y) ** 2) ** 0.5)
    row[1].append(sum(color[:3]) / 3.0)
abdomen_rows = sorted(abdomen_sections)
segment_grooves = 0
for z in (0.3920, 0.6272, 0.8624, 1.0976, 1.3328, 1.5680, 1.8032):
    key = min(abdomen_rows, key=lambda value: abs(value - z))
    i = abdomen_rows.index(key)
    radius = sum(abdomen_sections[key][0]) / len(abdomen_sections[key][0])
    color = sum(abdomen_sections[key][1]) / len(abdomen_sections[key][1])
    adjacent_radius = (
        sum(abdomen_sections[abdomen_rows[i - 1]][0]) / len(abdomen_sections[abdomen_rows[i - 1]][0])
        + sum(abdomen_sections[abdomen_rows[i + 1]][0]) / len(abdomen_sections[abdomen_rows[i + 1]][0])
    ) / 2.0
    adjacent_color = (
        sum(abdomen_sections[abdomen_rows[i - 1]][1]) / len(abdomen_sections[abdomen_rows[i - 1]][1])
        + sum(abdomen_sections[abdomen_rows[i + 1]][1]) / len(abdomen_sections[abdomen_rows[i + 1]][1])
    ) / 2.0
    if radius < adjacent_radius * 0.98 and color < adjacent_color * 0.95:
        segment_grooves += 1
assert segment_grooves >= 6, segment_grooves
for side in ("L", "R"):
    coxa_y = [point[1] for point in primitive_positions(f"Raptor_{side}_Coxa")]
    assert max(coxa_y) > 0.78
    femur_y = node_by_name[f"Raptor_{side}_Femur"]["translation"][1]
    assert femur_y > 0.78
    femur_name = f"Raptor_{side}_Femur"
    femur_index = next(index for index, node in enumerate(doc["nodes"]) if node.get("name") == femur_name)
    femur_world = world_matrix(femur_index)
    femur_center = transformed_point(femur_world, mean_point(primitive_positions(femur_name, 0)))
    inward_sign = 1 if side == "L" else -1
    for primitive_index in (2, 3):
        spine_center = transformed_point(femur_world, mean_point(primitive_positions(femur_name, primitive_index)))
        inward_delta = spine_center[0] - femur_center[0]
        assert inward_sign * inward_delta > 0.01, (side, primitive_index, inward_delta)
    tibia_name = f"Raptor_{side}_Tibia"
    tibia_index = next(index for index, node in enumerate(doc["nodes"]) if node.get("name") == tibia_name)
    tibia_world = world_matrix(tibia_index)
    tibia_center = transformed_point(tibia_world, mean_point(primitive_positions(tibia_name, 0)))
    teeth_center = transformed_point(tibia_world, mean_point(primitive_positions(tibia_name, 2)))
    assert inward_sign * (teeth_center[0] - tibia_center[0]) > 0.01, (side, "tibial teeth")
    assert node_by_name[f"Raptor_{side}_Coxa"]["translation"][2] <= -0.48

animation_by_name = {animation["name"].upper(): animation for animation in doc["animations"]}
for clip in ("IDLE", "WALK", "ALERT", "STRIKE", "GROOM", "FEED"):
    animation = animation_by_name[clip]
    head_rotation = next(
        channel for channel in animation["channels"]
        if nodes[channel["target"]["node"]] == "Head"
        and channel["target"]["path"] == "rotation"
    )
    head_quats = accessor_values(animation["samplers"][head_rotation["sampler"]]["output"])
    assert min(value[1] for value in head_quats) < -0.08
    assert max(value[1] for value in head_quats) > 0.08

images = doc.get("images", [])
textures = doc.get("textures", [])
assert len(images) == 4 and len(textures) == 4
for image in images:
    assert image["mimeType"] == "image/png"
    view = doc["bufferViews"][image["bufferView"]]
    start = view.get("byteOffset", 0)
    assert binary[start:start + 8] == b"\x89PNG\r\n\x1a\n"
    assert struct.unpack_from(">II", binary, start + 16) == (1024, 2048)
assert [image["name"] for image in images] == [
    "Base1_Forewing_Albedo", "Base1_Hindwing_Albedo",
    "Base1_Forewing_Normal", "Base1_Hindwing_Normal",
]
for side in ("L", "R"):
    wing_mesh = doc["meshes"][node_by_name[f"Wing_{side}"]["mesh"]]
    assert len(wing_mesh["primitives"]) == 2  # discard the overlapping dark triangle-strip veins
    fore_positions = accessor_values(wing_mesh["primitives"][0]["attributes"]["POSITION"])
    hind_positions = accessor_values(wing_mesh["primitives"][1]["attributes"]["POSITION"])
    for primitive in wing_mesh["primitives"]:
        attributes = primitive["attributes"]
        assert {"POSITION", "NORMAL", "TEXCOORD_0", "COLOR_0"} <= set(attributes)
        positions = accessor_values(attributes["POSITION"])
        normals = accessor_values(attributes["NORMAL"])
        assert len(positions) == len(normals) == 31 * 91
        assert all(abs(sum(component*component for component in normal) - 1.0) < 0.015 for normal in normals)
        indices = accessor_values(primitive["indices"])
        assert doc["accessors"][primitive["indices"]]["componentType"] in (5121, 5123, 5125)
        assert len(indices) % 3 == 0 and max(index[0] for index in indices) < len(positions)
    assert len(fore_positions) == len(hind_positions)
    assert all(fore_positions[i][1] > hind_positions[i][1] + 0.02 for i in range(len(fore_positions)))
    if side == "L":
        assert max(point[0] for point in fore_positions) < 0.0
    else:
        assert min(point[0] for point in fore_positions) > 0.0
    assert max(abs(point[0]) for point in hind_positions) > max(abs(point[0]) for point in fore_positions) + 0.03

materials = {material["name"]: material for material in doc["materials"]}
assert materials["cuticle"]["pbrMetallicRoughness"]["baseColorFactor"] == [0.31, 0.49, 0.22, 1.0]
assert materials["cuticle"]["pbrMetallicRoughness"]["roughnessFactor"] == 0.43
fore = materials["wing"]
hind = materials["hindwing"]
assert fore["alphaMode"] == hind["alphaMode"] == "BLEND"
assert fore["doubleSided"] and hind["doubleSided"]
assert fore["pbrMetallicRoughness"]["baseColorFactor"] == [1.0, 1.0, 1.0, 0.94]
assert hind["pbrMetallicRoughness"]["baseColorFactor"] == [1.0, 1.0, 1.0, 0.66]
assert fore["pbrMetallicRoughness"]["roughnessFactor"] == 0.36
assert hind["pbrMetallicRoughness"]["roughnessFactor"] == 0.43
assert fore["pbrMetallicRoughness"]["metallicFactor"] == 0.025
assert fore["pbrMetallicRoughness"]["baseColorTexture"]["index"] != hind["pbrMetallicRoughness"]["baseColorTexture"]["index"]
assert fore["normalTexture"]["index"] != hind["normalTexture"]["index"]
assert fore["normalTexture"]["scale"] > 0.0 and hind["normalTexture"]["scale"] > 0.0
assert all(sampler.get("minFilter") == 9987 for sampler in doc["samplers"])

# Preserve the authored material palette and avoid high-frequency overlays on the imported model.
style = main.split("func _style_rigged_materials", 1)[1].split("func _find_rigged_player", 1)[0]
assert "part.material_override = null" in style
assert "part.set_surface_override_material(surface_index, mat)" in style
assert "mat.detail_enabled = true" not in style
assert "mat.roughness = minf(mat.roughness, 0.46)" in style
assert "mat.roughness = minf(mat.roughness, 0.48)" in style
assert 'mat.albedo_color = Color(0.39, 0.66, 0.22)' not in style
assert 'mat.albedo_color = Color(0.52, 0.73, 0.31)' not in style
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
assert 'env.ambient_light_energy = 0.38' in main
assert 'sun.light_energy = 0.68' in main
assert 'leaf_material.normal_scale = 0.10' in main
assert 'sun.shadow_opacity = 0.48' in main
assert 'sun.shadow_blur = 1.2' in main
assert 'mipmaps/generate=true' in (root / "assets/textures/foliage_albedo.png.import").read_text()
assert 'mipmaps/generate=true' in (root / "assets/textures/foliage_normal.png.import").read_text()

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

print("Base 1 refinement check passed: inward raptorial teeth, clean triangles, existing rig/clips, photo proportions, detailed wings and abdomen, and six instars verified.")
