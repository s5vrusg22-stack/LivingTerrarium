import json
import math
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "tools"))
import upgrade_mantis_glb as glb

doc, binary = glb.read_glb(root / "assets/models/mantis_rigged.glb")
extras = doc["asset"]["extras"]
assert extras["reference_mantis_refinement"] in {"photo_proportions_v10_photo_forelegs_100", "photo_proportions_v11_two_hinge_forelegs_slim_pronotum", "photo_proportions_v12_long_neck_attached_two_hinge_forelegs", "photo_proportions_v13_prominent_long_coxa", "photo_proportions_v14_forelegs_front_back_flipped"}
profile = extras["photo_reference_profile_v9"]
assert profile["wing_cover_width_scale"] == 1.14
assert profile["wing_cover_length_scale"] == 1.06
assert profile["wing_cover_posterior_offset"] == 0.18
assert profile["legacy_spine_nodes_detached"] == 14
assert profile["foreleg_details_preserved"] == 100

meshes = {mesh["name"]: mesh for mesh in doc["meshes"]}
nodes = {node["name"]: node for node in doc["nodes"] if "name" in node}
for side in "LR":
    wing = meshes[f"Wing_{side}"]["primitives"][0]
    points = glb.read_vectors(doc, binary, wing["attributes"]["POSITION"])
    assert max(p[2] for p in points) - min(p[2] for p in points) > 1.08
    assert max(p[0] for p in points) - min(p[0] for p in points) > 0.15
    assert min(p[2] for p in points) < -0.30 and max(p[2] for p in points) > 0.70
    for part in (f"ForeFemur_{side}", f"ForeTibia_{side}"):
        primitive = meshes[part]["primitives"][0]
        attrs = primitive["attributes"]
        positions = glb.read_vectors(doc, binary, attrs["POSITION"])
        normals = glb.read_vectors(doc, binary, attrs["NORMAL"])
        joints = glb.read_vectors(doc, binary, attrs["JOINTS_0"])
        weights = glb.read_vectors(doc, binary, attrs["WEIGHTS_0"])
        assert len(positions) > 1450
        assert all(0.98 < math.sqrt(sum(c*c for c in n)) < 1.02 for n in normals)
        assert len({int(row[0]) for row in joints}) == 1
        assert all(abs(sum(row) - 1.0) < 1e-6 for row in weights)

abdomen = glb.read_vectors(doc, binary, meshes["Abdomen"]["primitives"][0]["attributes"]["POSITION"])
assert max(p[1] for p in abdomen) - min(p[1] for p in abdomen) < 0.17
thorax = glb.read_vectors(doc, binary, meshes["Thorax"]["primitives"][0]["attributes"]["POSITION"])
assert max(p[2] for p in thorax) - min(p[2] for p in thorax) > 0.73

head = glb.read_vectors(doc, binary, meshes["Head"]["primitives"][0]["attributes"]["POSITION"])
front = [p for p in head if p[2] < -0.025]
rear = [p for p in head if p[2] > 0.025]
front_width = max(p[0] for p in front) - min(p[0] for p in front)
rear_width = max(p[0] for p in rear) - min(p[0] for p in rear)
assert front_width < rear_width * 0.90
for side in "LR":
    eye = glb.read_vectors(doc, binary, meshes[f"Eye_{side}"]["primitives"][0]["attributes"]["POSITION"])
    assert max(p[0] for p in eye) - min(p[0] for p in eye) < 0.07

mouth = meshes["MouthpartDetail"]["primitives"][0]
assert doc["accessors"][mouth["attributes"]["POSITION"]]["count"] > 300
assert nodes["MouthpartDetail"]["skin"] == nodes["Head"]["skin"]
for side in "LR":
    for index in range(7):
        assert "mesh" not in nodes[f"Spine_{side}{index}"]

assert len(doc["skins"][0]["joints"]) == 61
assert len(doc["animations"]) == 10
bank = json.loads((root / "assets/animations/front_leg_100.json").read_text())
assert len(bank["animations"]) == 100
main = (root / "scripts/main.gd").read_text()
assert "mat.albedo_texture = eye_texture" in main
assert "mat.vertex_color_use_as_albedo = false" in main
assert "mat.normal_scale = 0.22" in main
assert "README_v4.5.md" in (root / "README.md").read_text()
assert (root / "assets/reference/mantis_side_reference.png").is_file()
print("v4.5 check passed: photo-shaped body, rear-set full covers, attached face details, and retained v4.0/v4.1 systems")
