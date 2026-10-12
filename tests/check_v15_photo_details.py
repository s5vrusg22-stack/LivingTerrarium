from pathlib import Path
import json
import struct
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "tools"))
import upgrade_mantis_glb as glb

doc, binary = glb.read_glb(root / "assets/models/mantis_rigged.glb")
extras = doc["asset"]["extras"]
assert extras["reference_mantis_refinement"] == "photo_proportions_v14_forelegs_front_back_flipped"
details = extras["mantis_v15_photo_details"]
assert details["pass"] == "photo_details_v15"
assert details["foreleg_flip_preserved"] == extras["mantis_v14_front_back_flip"]
assert (root / details["reference_photo"]).is_file()
assert details["abdomen_body_scale_xyz"] == [0.88, 0.92, 1.06]
assert details["abdomen_plate_scale_xyz"] == [0.86, 0.92, 1.0]
assert details["head_front_taper"] == 0.13
assert details["head_lower_face_taper"] == 0.50 and details["head_point_shift"] == -0.012
assert details["ocelli_scale"] == 0.62
assert details["bone_count"] == 61 and details["imported_clip_count"] == 10
assert details["surface_detail_count"] == 100

nodes = {node.get("name"): node for node in doc["nodes"] if node.get("name")}
node_ids = {node.get("name"): i for i, node in enumerate(doc["nodes"]) if node.get("name")}
meshes = {mesh.get("name"): mesh for mesh in doc["meshes"]}
skin = doc["skins"][0]
joint_slot = {doc["nodes"][node_id]["name"]: slot for slot, node_id in enumerate(skin["joints"])}

def translation(node):
    matrix = node.get("matrix")
    return tuple(matrix[12:15]) if matrix else tuple(node.get("translation", (0.0, 0.0, 0.0)))

def close(a, b, tolerance=2e-5):
    return all(abs(a[i] - b[i]) < tolerance for i in range(3))

head_points = glb.read_vectors(doc, binary, meshes["Head"]["primitives"][0]["attributes"]["POSITION"])
lower_face = [point for point in head_points if point[1] < -0.04]
upper_face = [point for point in head_points if point[1] > 0.04]
lower_width = max(point[0] for point in lower_face) - min(point[0] for point in lower_face)
upper_width = max(point[0] for point in upper_face) - min(point[0] for point in upper_face)
assert lower_width < upper_width * 0.65

for side, suffix in ((-1.0, "L"), (1.0, "R")):
    antenna = "Antenna_" + suffix
    bone = "Rig_Antenna_" + suffix
    primitive = meshes[antenna]["primitives"][0]
    attrs = primitive["attributes"]
    points = glb.read_vectors(doc, binary, attrs["POSITION"])
    joints = glb.read_vectors(doc, binary, attrs["JOINTS_0"])
    assert len(points) == 570
    assert {int(row[0]) for row in joints} == {joint_slot[bone]}
    node_origin = translation(nodes[antenna])
    world_points = [tuple(node_origin[i] + point[i] for i in range(3)) for point in points]
    assert max(point[1] for point in world_points) > 0.84
    assert min(point[2] for point in world_points) < -1.20
    layout = details["antennae"][suffix]
    assert layout["tapered"] and layout["tube_samples"] == 56
    assert close(translation(nodes[bone]), tuple(layout["base_world"]))
    assert close(translation(nodes[antenna]), tuple(layout["base_world"]))

    for name in ("EyePupil_" + suffix, "EyeGlint_" + suffix):
        node = nodes[name]
        assert node.get("skin") == 0
        patch = meshes[name]["primitives"][0]
        patch_joints = glb.read_vectors(doc, binary, patch["attributes"]["JOINTS_0"])
        assert {int(row[0]) for row in patch_joints} == {joint_slot["Rig_Eye_" + suffix]}
        assert len(glb.read_vectors(doc, binary, patch["attributes"]["POSITION"])) == 220

ibm = doc["accessors"][skin["inverseBindMatrices"]]
view = doc["bufferViews"][ibm["bufferView"]]
offset = view.get("byteOffset", 0) + ibm.get("byteOffset", 0)
stride = view.get("byteStride", 64)
for suffix in "LR":
    name = "Rig_Antenna_" + suffix
    matrix = struct.unpack_from("<16f", binary, offset + joint_slot[name] * stride)
    world = translation(nodes[name])
    assert close(tuple(-matrix[12 + i] for i in range(3)), world)

bank = json.loads((root / "assets/animations/front_leg_100.json").read_text(encoding="utf-8"))
assert len(bank["animations"]) == 100 and bank["foreleg_rotation_reflection"]["applied_to_clips"] == 100
assert len(doc["animations"]) == 10
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
assert "var use_photo_visual := false" in main
assert 'load("res://assets/reference/1000157363(3).jpg")' in main
assert 'load("res://assets/textures/mantis_eye_albedo_v49.png")' in main
assert "EyePupil_" in main and "EyeGlint_" in main
driver = (root / "scripts/rigged_pose_driver.gd").read_text(encoding="utf-8")
assert 'Vector3.RIGHT, -foreleg_offset' in driver
print("v4.9 photo-detail check passed: latest image, sculpted silhouette, curved antennae, eye details and preserved foreleg flip")
