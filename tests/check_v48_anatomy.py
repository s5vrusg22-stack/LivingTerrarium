from pathlib import Path
import json
import math
import struct
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "tools"))
import upgrade_mantis_glb as glb

doc, binary = glb.read_glb(root / "assets/models/mantis_rigged.glb")
extras = doc["asset"]["extras"]
marker = extras["reference_mantis_refinement"]
assert marker in {"photo_proportions_v13_prominent_long_coxa",
                  "photo_proportions_v14_forelegs_front_back_flipped"}
assert extras["mantis_v16_anatomy"]["pass"] == "photo_proportions_v16_longer_neck_and_forecoxa"
anatomy = extras["mantis_v12_anatomy"]
assert anatomy["two_hinges_per_attached_foreleg"]
assert anatomy["head_and_eye_meshes_repositioned"]
assert anatomy["detail_count_preserved"] == 100

meshes = {mesh["name"]: mesh for mesh in doc["meshes"]}
nodes = {node["name"]: node for node in doc["nodes"] if "name" in node}
node_ids = {node["name"]: i for i, node in enumerate(doc["nodes"]) if "name" in node}
parent = {child: i for i, node in enumerate(doc["nodes"]) for child in node.get("children", [])}


def node_position(node):
    matrix = node.get("matrix")
    return tuple(matrix[12:15]) if matrix else tuple(node.get("translation", (0.0, 0.0, 0.0)))


def transform_mesh_point(node, point):
    matrix = node.get("matrix")
    if not matrix:
        return tuple(node_position(node)[i] + point[i] for i in range(3))
    return (
        matrix[0] * point[0] + matrix[4] * point[1] + matrix[8] * point[2] + matrix[12],
        matrix[1] * point[0] + matrix[5] * point[1] + matrix[9] * point[2] + matrix[13],
        matrix[2] * point[0] + matrix[6] * point[1] + matrix[10] * point[2] + matrix[14],
    )


def global_position(index):
    position = node_position(doc["nodes"][index])
    if index not in parent:
        return position
    base = global_position(parent[index])
    return tuple(base[i] + position[i] for i in range(3))


def distance(a, b):
    return math.sqrt(sum((a[i] - b[i]) ** 2 for i in range(3)))


thorax = meshes["Thorax"]["primitives"][0]
thorax_points = glb.read_vectors(doc, binary, thorax["attributes"]["POSITION"])
front_points = [p for p in thorax_points if p[2] < -0.28]
rear_points = [p for p in thorax_points if p[2] > 0.28]
front_width = max(p[0] for p in front_points) - min(p[0] for p in front_points)
rear_width = max(p[0] for p in rear_points) - min(p[0] for p in rear_points)
front_height = max(p[1] for p in front_points) - min(p[1] for p in front_points)
rear_height = max(p[1] for p in rear_points) - min(p[1] for p in rear_points)
assert front_width < rear_width * 0.65
assert front_height < rear_height * 0.45

head_points = glb.read_vectors(doc, binary, meshes["Head"]["primitives"][0]["attributes"]["POSITION"])
head_origin = node_position(nodes["Head"])
head_rear_z = head_origin[2] + max(p[2] for p in head_points)
thorax_origin = global_position(node_ids["Rig_Thorax"])
thorax_front_z = thorax_origin[2] + min(p[2] for p in thorax_points)
assert 0.045 < thorax_front_z - head_rear_z < 0.09
assert parent[node_ids["Rig_Head"]] == node_ids["Rig_Thorax"]
assert distance(global_position(node_ids["Rig_Head"]), head_origin) < 1e-6

neck_points = glb.read_vectors(doc, binary, meshes["CervicalLink"]["primitives"][0]["attributes"]["POSITION"])
neck_origin = node_position(nodes["CervicalLink"])
neck_world = [transform_mesh_point(nodes["CervicalLink"], p) for p in neck_points]
assert min(p[2] for p in neck_world) < thorax_front_z + 0.03
assert max(p[2] for p in neck_world) > head_rear_z - 0.03
assert max(abs(p[0]) for p in neck_points) < 0.012

# Eye spheres are recessed into the head's eye line instead of floating beside it.
for suffix in "LR":
    eye_center = node_position(nodes["Eye_" + suffix])
    assert abs(abs(eye_center[0]) - 0.091) < 1e-6
    assert abs(eye_center[2] - head_origin[2]) < 0.01
    assert min(p[0] for p in head_points) - 0.02 < eye_center[0] < max(p[0] for p in head_points) + 0.02

skin = doc["skins"][0]
joint_slot = {node_id: slot for slot, node_id in enumerate(skin["joints"])}
for side, suffix in ((-1.0, "L"), (1.0, "R")):
    femur_bone = node_ids["Rig_ForeFemur_" + suffix]
    tibia_bone = node_ids["Rig_ForeTibia_" + suffix]
    assert parent[femur_bone] == node_ids["Rig_Thorax"]
    assert parent[tibia_bone] == femur_bone
    shoulder = global_position(femur_bone)
    knee = global_position(tibia_bone)
    tip = anatomy["leg_rest_pose"][suffix]["tibial_tip_world"]
    attach = anatomy["leg_rest_pose"][suffix]["coxa_attach_world"]
    assert abs(shoulder[0] * side) > 0.12
    assert abs(knee[0]) > abs(shoulder[0]) + 0.15
    assert abs(tip[0]) < abs(knee[0]) - 0.15
    assert knee[1] < shoulder[1]
    assert tip[1] < knee[1]
    if marker == "photo_proportions_v14_forelegs_front_back_flipped":
        assert knee[2] < shoulder[2] and tip[2] > knee[2]
    else:
        assert knee[2] > shoulder[2] and tip[2] < knee[2]

    for part_name, bone_id in (("ForeFemur_" + suffix, femur_bone),
                               ("ForeTibia_" + suffix, tibia_bone)):
        primitive = meshes[part_name]["primitives"][0]
        attrs = primitive["attributes"]
        points = glb.read_vectors(doc, binary, attrs["POSITION"])
        joints = glb.read_vectors(doc, binary, attrs["JOINTS_0"])
        weights = glb.read_vectors(doc, binary, attrs["WEIGHTS_0"])
        assert len(points) > 1500
        assert {int(row[0]) for row in joints} == {joint_slot[bone_id]}
        assert all(abs(row[0] - 1.0) < 1e-6 for row in weights)

    coxa = meshes["ForeCoxa_" + suffix]["primitives"][0]
    coxa_attrs = coxa["attributes"]
    coxa_points = glb.read_vectors(doc, binary, coxa_attrs["POSITION"])
    coxa_joints = glb.read_vectors(doc, binary, coxa_attrs["JOINTS_0"])
    assert {int(row[0]) for row in coxa_joints} == {joint_slot[node_ids["Rig_Thorax"]]}
    coxa_world = [transform_mesh_point(nodes["ForeCoxa_" + suffix], p) for p in coxa_points]
    assert min(distance(p, shoulder) for p in coxa_world) < 0.02
    assert min(distance(p, attach) for p in coxa_world) < 0.02

# The bind transforms must match the revised head, eyes, antennae, and hinge bones.
ibm = doc["accessors"][skin["inverseBindMatrices"]]
view = doc["bufferViews"][ibm["bufferView"]]
offset = view.get("byteOffset", 0) + ibm.get("byteOffset", 0)
stride = view.get("byteStride", 64)
for name in ("Rig_Head", "Rig_Eye_L", "Rig_Eye_R", "Rig_Antenna_L", "Rig_Antenna_R",
             "Rig_ForeFemur_L", "Rig_ForeFemur_R", "Rig_ForeTibia_L", "Rig_ForeTibia_R"):
    matrix = struct.unpack_from("<16f", binary, offset + joint_slot[node_ids[name]] * stride)
    position = global_position(node_ids[name])
    assert all(abs(matrix[12 + i] + position[i]) < 2e-5 for i in range(3)), (name, matrix[12:15], position)

assert len(skin["joints"]) == 61
assert len(doc["animations"]) == 10
bank = json.loads((root / "assets/animations/front_leg_100.json").read_text(encoding="utf-8"))
assert len(bank["animations"]) == 100 and bank["keyframe_count"] == 9
driver = (root / "scripts/rigged_pose_driver.gd").read_text(encoding="utf-8")
assert "Rig_ForeFemur_" in driver and "Rig_ForeTibia_" in driver
assert "_advance_front_leg_animation(dt)" in driver
for filename in ("mantis_v48_overview.png", "mantis_v48_forelegs.png",
                 "mantis_v48_forelegs_side.png", "mantis_v48_head_neck.png"):
    assert (root / "previews" / filename).is_file()

print("v4.8 anatomy check passed: slim thorax tip, separate head, attached V-shaped two-hinge forelegs")
