from pathlib import Path
import math
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "tools"))
import upgrade_mantis_glb as glb

doc, binary = glb.read_glb(root / "assets/models/mantis_rigged.glb")
extras = doc["asset"]["extras"]
assert extras["reference_mantis_refinement"] == "photo_proportions_v14_forelegs_front_back_flipped"
visible = extras["mantis_v13_coxa_visibility"]
assert visible["rig_and_animation_preserved"]
flipped = extras["mantis_v14_front_back_flip"]
assert flipped["root_anchors_preserved"]
assert flipped["left_right_and_vertical_coordinates_preserved"]
assert flipped["reflected_axis"] == "Z front-back only"

nodes = {node.get("name"): node for node in doc["nodes"] if node.get("name")}
meshes = {mesh.get("name"): mesh for mesh in doc["meshes"]}
skin = doc["skins"][0]
joint_slot = {doc["nodes"][node_id]["name"]: slot for slot, node_id in enumerate(skin["joints"])}

def distance(a, b):
    return math.dist(a, b)

for suffix in "LR":
    spec = visible["paired_segments"][suffix]
    rest = flipped["rest_pose"][suffix]
    segment = flipped["segments"][suffix]
    assert spec["segment"] == "ForeCoxa_" + suffix
    assert segment["segment_lengths_preserved"]["coxa"] > 0.24
    assert flipped["shaft_thickness_scale"] >= 1.7
    source = segment["source_pose"]
    anchor_z = source["coxa_attach_world"][2]
    for key in ("coxa_attach_world", "first_hinge_world", "second_hinge_world", "tibial_tip_world"):
        old_point = source[key]
        new_point = rest[key]
        assert abs(new_point[0] - old_point[0]) < 1e-7, (suffix, key, old_point, new_point)
        assert abs(new_point[1] - old_point[1]) < 1e-7, (suffix, key, old_point, new_point)
        assert abs(new_point[2] - (2.0 * anchor_z - old_point[2])) < 1e-7, (suffix, key, old_point, new_point)
    assert rest["coxa_attach_world"] == source["coxa_attach_world"]
    assert rest["first_hinge_world"][2] > rest["coxa_attach_world"][2]
    assert rest["second_hinge_world"][2] < rest["first_hinge_world"][2]
    assert rest["tibial_tip_world"][2] > rest["second_hinge_world"][2]
    primitive = meshes[spec["segment"]]["primitives"][0]
    attrs = primitive["attributes"]
    points = glb.read_vectors(doc, binary, attrs["POSITION"])
    uv = glb.read_vectors(doc, binary, attrs["TEXCOORD_0"])
    joints = glb.read_vectors(doc, binary, attrs["JOINTS_0"])
    assert {int(row[0]) for row in joints} == {joint_slot["Rig_Thorax"]}
    node_origin = tuple(nodes[spec["segment"]]["matrix"][12:15])
    world = [tuple(node_origin[i] + p[i] for i in range(3)) for p in points]
    start, end = tuple(rest["coxa_attach_world"]), tuple(rest["first_hinge_world"])
    assert min(distance(p, start) for p in world) < 0.02
    assert min(distance(p, end) for p in world) < 0.025
    mid_radii = []
    for p, tex in zip(world, uv):
        if 0.35 <= tex[0] <= 0.65:
            u = tex[0]
            center = tuple(start[i] + (end[i] - start[i]) * u for i in range(3))
            mid_radii.append(distance(p, center))
    assert max(mid_radii) > 0.016, (suffix, max(mid_radii))

assert len(skin["joints"]) == 61
assert len(doc["animations"]) == 10
assert flipped["imported_clip_rotation_reflection"]["channel_count"] >= 8
assert len(flipped["imported_clip_rotation_reflection"]["channels"]) >= 8
bank = root / "assets/animations/front_leg_100.json"
motion_bank = __import__("json").loads(bank.read_text(encoding="utf-8"))
assert len(motion_bank["animations"]) == 100
assert motion_bank["foreleg_rotation_reflection"]["applied_to_clips"] == 100
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
assert 'preload("res://assets/models/mantis_rigged.glb")' in main
driver = (root / "scripts/rigged_pose_driver.gd").read_text(encoding="utf-8")
assert 'Vector3.RIGHT, -foreleg_offset' in driver
assert 'Vector3.RIGHT, foreleg_offset * 0.48' in driver
assert (root / "previews/mantis_v410_foreleg_front_back.png").is_file()
print("v4.9.1 check passed: full left/right forelegs are Z-reflected, attached, re-skinned and retargeted in all animation paths")
