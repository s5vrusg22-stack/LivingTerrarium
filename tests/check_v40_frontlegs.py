from collections import Counter
import json
import math
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "tools"))
import upgrade_mantis_glb as glb

doc, binary = glb.read_glb(root / "assets/models/mantis_rigged.glb")
extras = doc["asset"]["extras"]
assert extras["reference_mantis_refinement"] in {"photo_proportions_v11_two_hinge_forelegs_slim_pronotum", "photo_proportions_v12_long_neck_attached_two_hinge_forelegs", "photo_proportions_v13_prominent_long_coxa", "photo_proportions_v14_forelegs_front_back_flipped"}
assert extras["mantis_v7_detail_passes"]["total"] == 80
details = extras["mantis_v10_frontleg_geometry"]
assert details["total_foreleg_render_details"] == 100
assert details["discrete_grasping_spines"] == 36
assert details["discrete_tibial_teeth"] == 28
assert details["raised_cuticle_striae"] == 36
meshes = {mesh["name"]: mesh for mesh in doc["meshes"]}
assert {"WingVeinDetail_L", "WingVeinDetail_R", "ThoraxSurfaceDetail", "Hindwing_L", "Hindwing_R"}.issubset(meshes)

for side in "LR":
    for name, min_vertices, min_indices in (
        (f"ForeFemur_{side}", 2000, 11000),
        (f"ForeTibia_{side}", 1450, 8200),
    ):
        primitive = meshes[name]["primitives"][0]
        attrs = primitive["attributes"]
        positions = glb.read_vectors(doc, binary, attrs["POSITION"])
        normals = glb.read_vectors(doc, binary, attrs["NORMAL"])
        uv = glb.read_vectors(doc, binary, attrs["TEXCOORD_0"])
        joints = glb.read_vectors(doc, binary, attrs["JOINTS_0"])
        weights = glb.read_vectors(doc, binary, attrs["WEIGHTS_0"])
        indices = glb.read_indices(doc, binary, primitive["indices"])
        assert len(positions) >= min_vertices and len(indices) >= min_indices
        assert len(normals) == len(positions) == len(uv)
        assert max(indices) < len(positions)
        assert all(0.98 < math.sqrt(sum(c * c for c in n)) < 1.02 for n in normals)
        assert all(0.0 <= p[0] <= 1.0 and 0.0 <= p[1] <= 1.0 for p in uv)
        assert len({int(round(j[0])) for j in joints}) == 1
        assert all(abs(sum(w) - 1.0) < 1e-6 for w in weights)

assert len(doc["skins"][0]["joints"]) == 61
assert len(doc["animations"]) == 10

bank = json.loads((root / "assets/animations/front_leg_100.json").read_text(encoding="utf-8"))
clips = bank["animations"]
assert bank["keyframe_count"] == 9 and len(bank["channels"]) == 12 and len(clips) == 100
assert [clip["name"] for clip in clips] == [f"Foreleg_{i:03d}" for i in range(1, 101)]
assert Counter(clip["family"] for clip in clips) == {"probe": 20, "grasp": 20, "groom": 20, "display": 20, "strike": 20}
signatures = set()
for clip in clips:
    assert clip["loop"] and clip["duration"] > 0.0
    assert len(clip["keyframes"]) == 9 and all(len(frame) == 12 for frame in clip["keyframes"])
    assert clip["keyframes"][0] == clip["keyframes"][-1]
    signatures.add(tuple(tuple(frame) for frame in clip["keyframes"]))
assert len(signatures) == 100

driver = (root / "scripts/rigged_pose_driver.gd").read_text()
main = (root / "scripts/main.gd").read_text()
assert "FRONT_LEG_ANIMATION_COUNT := 100" in driver
assert "_advance_front_leg_animation(dt)" in driver
assert "Rig_ForeFemur_" in driver and "Rig_ForeTibia_" in driver
assert "앞다리 동작 다음" in main and "앞다리 동작 이전" in main
assert "play_front_leg_animation(selected_frontleg_animation)" in main
assert (root / "scripts/aquarium_system.gd").is_file()
assert (root / "README_v3.9.md").is_file()
assert "README_v4.0.md" in (root / "README.md").read_text()
print("v4.0 check passed: 100 foreleg details, 100 unique clips, retained 80 mantis details, and v3.9 species")
