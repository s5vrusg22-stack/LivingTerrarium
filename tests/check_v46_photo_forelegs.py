import json
import math
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "tools"))
import upgrade_mantis_glb as glb

doc, binary = glb.read_glb(root / "assets/models/mantis_rigged.glb")
extras = doc["asset"]["extras"]
assert extras["reference_mantis_refinement"] in {
    "photo_proportions_v12_long_neck_attached_two_hinge_forelegs",
    "photo_proportions_v13_prominent_long_coxa", "photo_proportions_v14_forelegs_front_back_flipped",
}
profile = extras["photo_reference_profile_v9"]
assert profile["wing_cover_width_scale"] == 1.14
assert profile["foreleg_details_preserved"] == 100
details = extras["mantis_v10_frontleg_geometry"]
assert details["total_foreleg_render_details"] == 100
assert details["discrete_grasping_spines"] == 36
assert details["discrete_tibial_teeth"] == 28
assert details["raised_cuticle_striae"] == 36
assert details["femur_half_length_scale"] == 1.22
assert details["femur_cross_section"] == "flattened superellipse n=3, face aligned to lateral view"
assert details["tibia_cross_section"] == "slender curved sickle n=2.15"

meshes = {mesh["name"]: mesh for mesh in doc["meshes"]}
for side in "LR":
    for part, minimum in ((f"ForeFemur_{side}", 2100), (f"ForeTibia_{side}", 1550)):
        primitive = meshes[part]["primitives"][0]
        attrs = primitive["attributes"]
        points = glb.read_vectors(doc, binary, attrs["POSITION"])
        normals = glb.read_vectors(doc, binary, attrs["NORMAL"])
        joints = glb.read_vectors(doc, binary, attrs["JOINTS_0"])
        weights = glb.read_vectors(doc, binary, attrs["WEIGHTS_0"])
        indices = glb.read_indices(doc, binary, primitive["indices"])
        assert len(points) >= minimum and max(indices) < len(points)
        assert len(points) == len(normals) == len(joints) == len(weights)
        assert max(max(abs(v) for v in p) for p in points) > 0.12
        assert all(0.98 < math.sqrt(sum(v*v for v in n)) < 1.02 for n in normals)
        assert len({int(row[0]) for row in joints}) == 1
        assert all(abs(sum(row) - 1.0) < 1e-6 for row in weights)

assert len(doc["skins"][0]["joints"]) == 61
assert len(doc["animations"]) == 10
bank = json.loads((root / "assets/animations/front_leg_100.json").read_text(encoding="utf-8"))
assert bank["keyframe_count"] == 9 and len(bank["animations"]) == 100
assert "README_v4.6.md" in (root / "README.md").read_text(encoding="utf-8")
for preview_name in ("mantis_v48_overview.png", "mantis_v48_forelegs.png", "mantis_v48_forelegs_side.png", "mantis_v48_head_neck.png"):
    preview = root / "previews" / preview_name
    assert preview.is_file() and preview.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"
assert "README_v4.8.md" in (root / "README.md").read_text(encoding="utf-8")
print("v4.6 photo detail check passed: 100 details, 100 animation clips and v4.5 profile retained")
