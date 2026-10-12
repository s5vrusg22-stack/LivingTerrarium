from pathlib import Path
import math
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "tools"))
import upgrade_mantis_glb as glb

doc, binary = glb.read_glb(root / "assets/models/mantis_rigged.glb")
extras = doc["asset"]["extras"]
assert extras["reference_mantis_refinement"] in {"photo_proportions_v7_80_detail", "photo_proportions_v8_forelegs_100", "photo_proportions_v10_photo_forelegs_100", "photo_proportions_v11_two_hinge_forelegs_slim_pronotum", "photo_proportions_v12_long_neck_attached_two_hinge_forelegs", "photo_proportions_v13_prominent_long_coxa", "photo_proportions_v14_forelegs_front_back_flipped"}
assert extras["mantis_v6_geometry"]["wing_length_segments"] == 80
assert extras["mantis_v6_geometry"]["wing_width_segments"] == 24
passes = extras["mantis_v7_detail_passes"]
assert passes["total"] == 80
assert passes["wing_crossvein_paths"] == 56
assert passes["thorax_surface_structures"] == 24
assert passes["base_geometry"].startswith("v3.6")

meshes = {mesh["name"]: mesh for mesh in doc["meshes"]}
nodes = {node["name"]: node for node in doc["nodes"] if "name" in node}
assert {"WingVeinDetail_L", "WingVeinDetail_R", "ThoraxSurfaceDetail",
        "Hindwing_L", "Hindwing_R"}.issubset(meshes)
assert {"WingVeinDetail_L", "WingVeinDetail_R", "ThoraxSurfaceDetail",
        "Hindwing_L", "Hindwing_R"}.issubset(nodes)

for side in "LR":
    base = meshes[f"Wing_{side}"]["primitives"][0]
    assert doc["accessors"][base["attributes"]["POSITION"]]["count"] == 4050
    detail = meshes[f"WingVeinDetail_{side}"]["primitives"][0]
    attrs = detail["attributes"]
    points = glb.read_vectors(doc, binary, attrs["POSITION"])
    assert len(points) >= 28 * 17 * 5
    assert doc["accessors"][detail["indices"]]["count"] >= 28 * 16 * 5 * 6
    joints = glb.read_vectors(doc, binary, attrs["JOINTS_0"])
    weights = glb.read_vectors(doc, binary, attrs["WEIGHTS_0"])
    assert len({int(row[0]) for row in joints}) == 1
    assert all(abs(row[0] - 1.0) < 1e-6 for row in weights)
    hindwing = meshes[f"Hindwing_{side}"]["primitives"][0]
    alpha = glb.read_vectors(doc, binary, hindwing["attributes"]["COLOR_0"])
    assert min(row[3] for row in alpha) < 0.60
    normals = glb.read_vectors(doc, binary, hindwing["attributes"]["NORMAL"])
    assert all(0.95 < math.sqrt(sum(c * c for c in n)) < 1.05 for n in normals)

thorax_base = meshes["Thorax"]["primitives"][0]
assert doc["accessors"][thorax_base["attributes"]["POSITION"]]["count"] == 1946
thorax_detail = meshes["ThoraxSurfaceDetail"]["primitives"][0]
detail_positions = glb.read_vectors(doc, binary, thorax_detail["attributes"]["POSITION"])
assert len(detail_positions) > 1000
assert "matrix" in nodes["WingVeinDetail_L"] and "skin" in nodes["WingVeinDetail_L"]
assert "matrix" in nodes["ThoraxSurfaceDetail"] and "skin" in nodes["ThoraxSurfaceDetail"]
assert len(doc["skins"][0]["joints"]) == 61 and len(doc["animations"]) == 10

main = (root / "scripts/main.gd").read_text()
assert 'part.name.begins_with("WingVeinDetail_")' in main
assert 'part.name.begins_with("Hindwing_")' in main
assert "BaseMaterial3D.TRANSPARENCY_ALPHA" in main
print("v3.7 detail check passed: 56 raised wing cross-vein paths, 24 thorax structures, folded hindwings, and preserved v3.6 meshes")
