from pathlib import Path
import json
import math
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "tools"))
import upgrade_mantis_glb as glb


doc, binary = glb.read_glb(root / "assets/models/mantis_rigged.glb")
extras = doc["asset"]["extras"]
assert extras["reference_mantis_refinement"] == "photo_proportions_v14_forelegs_front_back_flipped"
flip = extras["mantis_v14_front_back_flip"]
assert flip["coordinate_rule"] == "x'=x, y'=y, z'=2*z_root-z"
assert flip["root_anchors_preserved"] and flip["left_right_and_vertical_coordinates_preserved"]
assert flip["reflected_axis"] == "Z front-back only"

nodes = {node["name"]: node for node in doc["nodes"] if node.get("name")}
node_ids = {node["name"]: i for i, node in enumerate(doc["nodes"]) if node.get("name")}
parents = {child: i for i, node in enumerate(doc["nodes"]) for child in node.get("children", [])}


def position(node):
    matrix = node.get("matrix")
    return tuple(matrix[12:15]) if matrix else tuple(node.get("translation", (0.0, 0.0, 0.0)))


def global_position(node_id):
    local = position(doc["nodes"][node_id])
    if node_id not in parents:
        return local
    parent = global_position(parents[node_id])
    return tuple(parent[i] + local[i] for i in range(3))


def close(a, b, tolerance=2e-5):
    return all(abs(a[i] - b[i]) < tolerance for i in range(3))


meshes = {mesh["name"]: mesh for mesh in doc["meshes"]}
skin = doc["skins"][0]
joint_slot = {doc["nodes"][node_id]["name"]: slot for slot, node_id in enumerate(skin["joints"])}
thorax_id = node_ids["Rig_Thorax"]
assert len(skin["joints"]) == 61 and len(doc["animations"]) == 10

for side, suffix in ((-1.0, "L"), (1.0, "R")):
    spec = flip["segments"][suffix]
    old = spec["source_pose"]
    pose = spec["rest_pose"]
    anchor_z = old["coxa_attach_world"][2]
    for key in ("coxa_attach_world", "first_hinge_world", "second_hinge_world", "tibial_tip_world"):
        before, after = old[key], pose[key]
        assert abs(after[0] - before[0]) < 1e-7, (suffix, key, before, after)
        assert abs(after[1] - before[1]) < 1e-7, (suffix, key, before, after)
        assert abs(after[2] - (2.0 * anchor_z - before[2])) < 1e-7, (suffix, key, before, after)
    assert pose["coxa_attach_world"] == old["coxa_attach_world"]
    assert pose["first_hinge_world"][2] > anchor_z
    assert pose["second_hinge_world"][2] < pose["first_hinge_world"][2]
    assert pose["tibial_tip_world"][2] > pose["second_hinge_world"][2]

    femur_id = node_ids["Rig_ForeFemur_" + suffix]
    tibia_id = node_ids["Rig_ForeTibia_" + suffix]
    assert parents[femur_id] == thorax_id and parents[tibia_id] == femur_id
    assert close(global_position(femur_id), pose["first_hinge_world"])
    assert close(global_position(tibia_id), pose["second_hinge_world"])

    for mesh_name, joint_name, expected_end in (
        ("ForeCoxa_" + suffix, "Rig_Thorax", pose["first_hinge_world"]),
        ("ForeFemur_" + suffix, "Rig_ForeFemur_" + suffix, pose["second_hinge_world"]),
        ("ForeTibia_" + suffix, "Rig_ForeTibia_" + suffix, pose["tibial_tip_world"]),
    ):
        primitive = meshes[mesh_name]["primitives"][0]
        attrs = primitive["attributes"]
        points = glb.read_vectors(doc, binary, attrs["POSITION"])
        joints = glb.read_vectors(doc, binary, attrs["JOINTS_0"])
        expected_slot = joint_slot[joint_name]
        assert {int(row[0]) for row in joints} == {expected_slot}
        node_origin = position(nodes[mesh_name])
        world_points = [tuple(node_origin[i] + p[i] for i in range(3)) for p in points]
        start = pose["coxa_attach_world"] if mesh_name.startswith("ForeCoxa") else position(nodes[mesh_name])
        assert min(math.dist(point, start) for point in world_points) < 0.025
        assert min(math.dist(point, expected_end) for point in world_points) < 0.03

ibm = doc["accessors"][skin["inverseBindMatrices"]]
view = doc["bufferViews"][ibm["bufferView"]]
offset = view.get("byteOffset", 0) + ibm.get("byteOffset", 0)
stride = view.get("byteStride", 64)
import struct
for name in ("Rig_ForeFemur_L", "Rig_ForeFemur_R", "Rig_ForeTibia_L", "Rig_ForeTibia_R"):
    matrix = struct.unpack_from("<16f", binary, offset + joint_slot[name] * stride)
    world = global_position(node_ids[name])
    assert close(tuple(-matrix[12 + i] for i in range(3)), world)

clip_records = flip["imported_clip_rotation_reflection"]["channels"]
assert len(clip_records) >= 8
channels = {}
for animation in doc["animations"]:
    for channel in animation.get("channels", []):
        name = doc["nodes"][channel["target"]["node"]].get("name")
        if name and name.startswith(("Rig_ForeFemur_", "Rig_ForeTibia_")) and channel["target"].get("path") == "rotation":
            sampler = animation["samplers"][channel["sampler"]]
            channels[(animation.get("name", ""), name, sampler["output"])] = True
for record in clip_records:
    before, after = record["sample_before"], record["sample_after"]
    assert all(abs(after[i] - value) < 1e-6 for i, value in enumerate((-before[0], -before[1], before[2], before[3])))
    accessor = glb.read_vectors(doc, binary, record["output_accessor"])[0]
    assert all(abs(accessor[i] - after[i]) < 1e-6 for i in range(4))
    assert (record["animation"], record["joint"], record["output_accessor"]) in channels

bank = json.loads((root / "assets/animations/front_leg_100.json").read_text(encoding="utf-8"))
assert len(bank["animations"]) == 100 and bank["keyframe_count"] == 9
assert bank["foreleg_rotation_reflection"]["applied_to_clips"] == 100
sample = bank["animations"][0]["keyframes"][0]
expected = [0.035, 0.095, 0.0, -0.4107, 0.0, 0.0,
            0.010016, -0.104626, 0.008328, -0.422076, 0.017846, -0.005609]
assert all(abs(sample[i] - expected[i]) < 1e-6 for i in range(12))

driver = (root / "scripts/rigged_pose_driver.gd").read_text(encoding="utf-8")
assert "Vector3.RIGHT, -foreleg_offset" in driver
assert "Vector3.RIGHT, foreleg_offset * 0.48" in driver
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
assert 'preload("res://assets/models/mantis_rigged.glb")' in main
preview = root / "previews/mantis_v410_foreleg_front_back.png"
assert preview.is_file() and preview.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"
print("v4.9.1 front/back check passed: whole-arm Z mirror, fixed roots, correct skin/bind matrices, and all procedural/imported animation paths")
