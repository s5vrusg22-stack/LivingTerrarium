from pathlib import Path
import math
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "tools"))
import upgrade_mantis_glb as glb

doc, binary = glb.read_glb(root / "assets/models/mantis_rigged.glb")
extras = doc["asset"]["extras"]
assert extras["reference_mantis_refinement"] in {"photo_proportions_v6", "photo_proportions_v7_80_detail", "photo_proportions_v8_forelegs_100", "photo_proportions_v10_photo_forelegs_100", "photo_proportions_v11_two_hinge_forelegs_slim_pronotum", "photo_proportions_v12_long_neck_attached_two_hinge_forelegs", "photo_proportions_v13_prominent_long_coxa", "photo_proportions_v14_forelegs_front_back_flipped"}
assert extras["mantis_v6_geometry"]["wing_length_segments"] == 80
assert extras["mantis_v6_geometry"]["wing_width_segments"] == 24
meshes = {mesh["name"]: mesh for mesh in doc["meshes"]}

for side in "LR":
    primitive = meshes[f"Wing_{side}"]["primitives"][0]
    attrs = primitive["attributes"]
    pos_accessor = doc["accessors"][attrs["POSITION"]]
    uv_accessor = doc["accessors"][attrs["TEXCOORD_0"]]
    index_accessor = doc["accessors"][primitive["indices"]]
    assert pos_accessor["count"] == 4050, pos_accessor
    assert uv_accessor["count"] == pos_accessor["count"] and uv_accessor["min"] == [0.0, 0.0]
    assert index_accessor["count"] == 24288
    positions = glb.read_vectors(doc, binary, attrs["POSITION"])
    profile_v9 = extras.get("photo_reference_profile_v9")
    offset = profile_v9["wing_cover_posterior_offset"] if profile_v9 else 0.0
    if profile_v9:
        relative_z = [p[2] - offset for p in positions]
        assert min(relative_z) < -0.50 and max(relative_z) > 0.50
        assert max(p[2] for p in positions) - min(p[2] for p in positions) > 1.08
    else:
        assert min(p[2] for p in positions) < -0.50 and max(p[2] for p in positions) > 0.50
    assert max(p[1] for p in positions) - min(p[1] for p in positions) > 0.02
    indices = glb.read_indices(doc, binary, primitive["indices"])
    assert min(indices) == 0 and max(indices) < len(positions)
    normals = glb.read_vectors(doc, binary, attrs["NORMAL"])
    assert all(0.98 < math.sqrt(sum(c * c for c in n)) < 1.02 for n in normals)
    joints = glb.read_vectors(doc, binary, attrs["JOINTS_0"])
    weights = glb.read_vectors(doc, binary, attrs["WEIGHTS_0"])
    assert len(set(int(row[0]) for row in joints)) == 1
    assert all(abs(row[0] - 1.0) < 1e-6 for row in weights)
    mid_width = max(p[0] for p in positions if abs(p[2] - offset) < 0.05) - min(p[0] for p in positions if abs(p[2] - offset) < 0.05)
    tip_threshold = 0.52 if profile_v9 else 0.49
    tip_width = max(p[0] for p in positions if abs(p[2] - offset) > tip_threshold) - min(p[0] for p in positions if abs(p[2] - offset) > tip_threshold)
    assert tip_width < mid_width * 0.12, (tip_width, mid_width)

thorax = meshes["Thorax"]["primitives"][0]
thorax_attrs = thorax["attributes"]
assert doc["accessors"][thorax_attrs["POSITION"]]["count"] == 1946
thorax_points = glb.read_vectors(doc, binary, thorax_attrs["POSITION"])
thorax_size = tuple(max(p[i] for p in thorax_points) - min(p[i] for p in thorax_points) for i in range(3))
if extras.get("reference_mantis_refinement") in {"photo_proportions_v11_two_hinge_forelegs_slim_pronotum", "photo_proportions_v12_long_neck_attached_two_hinge_forelegs", "photo_proportions_v13_prominent_long_coxa", "photo_proportions_v14_forelegs_front_back_flipped"}:
    assert 0.09 < thorax_size[0] < 0.105 and 0.10 < thorax_size[1] < 0.13 and thorax_size[2] > 0.73, thorax_size
elif extras.get("photo_reference_profile_v9"):
    assert 0.115 < thorax_size[0] < 0.13 and thorax_size[2] > 0.73, thorax_size
else:
    assert 0.11 < thorax_size[0] < 0.12 and thorax_size[2] > 0.67, thorax_size
assert len(doc["skins"][0]["joints"]) == 61 and len(doc["animations"]) == 10
print("v3.6 base geometry passed: 80x24 tapered tegmina, raised vein relief, and a sculpted pronotum")
