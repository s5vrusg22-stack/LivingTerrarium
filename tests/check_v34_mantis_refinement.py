from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "tools"))
import upgrade_mantis_glb as glb

doc, binary = glb.read_glb(root / "assets/models/mantis_rigged.glb")
assert doc["asset"]["extras"]["reference_mantis_refinement"] in {"photo_proportions_v6", "photo_proportions_v7_80_detail", "photo_proportions_v8_forelegs_100", "photo_proportions_v10_photo_forelegs_100", "photo_proportions_v11_two_hinge_forelegs_slim_pronotum", "photo_proportions_v12_long_neck_attached_two_hinge_forelegs", "photo_proportions_v13_prominent_long_coxa", "photo_proportions_v14_forelegs_front_back_flipped"}
meshes = {mesh.get("name"): mesh for mesh in doc["meshes"]}


def dimensions(name):
    accessor = meshes[name]["primitives"][0]["attributes"]["POSITION"]
    points = glb.read_vectors(doc, binary, accessor)
    return tuple(max(point[i] for point in points) - min(point[i] for point in points) for i in range(3))


abdomen = dimensions("Abdomen")
wing = dimensions("Wing_L")
is_v6 = doc["asset"]["extras"]["reference_mantis_refinement"] in {"photo_proportions_v6", "photo_proportions_v7_80_detail", "photo_proportions_v8_forelegs_100", "photo_proportions_v10_photo_forelegs_100", "photo_proportions_v11_two_hinge_forelegs_slim_pronotum", "photo_proportions_v12_long_neck_attached_two_hinge_forelegs", "photo_proportions_v13_prominent_long_coxa", "photo_proportions_v14_forelegs_front_back_flipped"}
is_v9 = "photo_reference_profile_v9" in doc["asset"]["extras"]
if is_v9:
    assert 0.14 < wing[0] < 0.17, wing
elif is_v6:
    assert 0.12 < wing[0] < 0.15, wing
else:
    assert 0.19 < wing[0] < 0.245, wing
assert wing[2] > abdomen[2] * 1.08, (wing, abdomen)
wing_nodes = {node["name"]: node for node in doc["nodes"] if node.get("name") in {"Wing_L", "Wing_R"}}
if is_v9:
    extents = []
    for side in "LR":
        points = glb.read_vectors(doc, binary, meshes[f"Wing_{side}"]["primitives"][0]["attributes"]["POSITION"])
        node = wing_nodes[f"Wing_{side}"]
        offset = node["matrix"][12] if "matrix" in node else node["translation"][0]
        extents.append((min(p[0] for p in points) + offset, max(p[0] for p in points) + offset))
    paired_span = max(extent[1] for extent in extents) - min(extent[0] for extent in extents)
    assert paired_span > abdomen[0] * 1.10, (paired_span, abdomen)
elif is_v6:
    extents = []
    for side in "LR":
        points = glb.read_vectors(doc, binary, meshes[f"Wing_{side}"]["primitives"][0]["attributes"]["POSITION"])
        node = wing_nodes[f"Wing_{side}"]
        offset = node["matrix"][12] if "matrix" in node else node["translation"][0]
        extents.append((min(p[0] for p in points) + offset, max(p[0] for p in points) + offset))
    paired_span = max(extent[1] for extent in extents) - min(extent[0] for extent in extents)
    assert abdomen[0] * .90 < paired_span < abdomen[0] * 1.05, (paired_span, abdomen)
else:
    centers = [node["matrix"][12] if "matrix" in node else node["translation"][0] for node in wing_nodes.values()]
    paired_span = max(center + wing[0] / 2 for center in centers) - min(center - wing[0] / 2 for center in centers)
    assert paired_span > abdomen[0] * 1.18, (paired_span, abdomen)

for side in "LR":
    mesh = meshes[f"Wing_{side}"]
    attrs = mesh["primitives"][0]["attributes"]
    assert "TEXCOORD_0" in attrs
    uv = doc["accessors"][attrs["TEXCOORD_0"]]
    position = doc["accessors"][attrs["POSITION"]]
    assert uv["type"] == "VEC2" and uv["count"] == position["count"]
    assert dimensions(f"Wing_{side}") == wing
    for part in (f"ForeFemur_{side}", f"ForeTibia_{side}"):
        anatomy = meshes[part]["primitives"][0]["attributes"]
        assert "JOINTS_0" in anatomy and "WEIGHTS_0" in anatomy
    if doc["asset"]["extras"]["reference_mantis_refinement"] in {"photo_proportions_v11_two_hinge_forelegs_slim_pronotum", "photo_proportions_v12_long_neck_attached_two_hinge_forelegs", "photo_proportions_v13_prominent_long_coxa", "photo_proportions_v14_forelegs_front_back_flipped"}:
        assert max(dimensions(f"ForeFemur_{side}")) > 0.24
        assert max(dimensions(f"ForeTibia_{side}")) > 0.27
    else:
        assert dimensions(f"ForeFemur_{side}")[0] > 0.28
        assert dimensions(f"ForeFemur_{side}")[1] > 0.22
        assert dimensions(f"ForeTibia_{side}")[1] > 0.27

for texture in (
    "mantis_cuticle_detail_albedo.png",
    "mantis_cuticle_detail_normal.png",
    "mantis_cuticle_detail_roughness.png",
    "mantis_wing_detail.png",
    "mantis_wing_normal.png",
    "mantis_wing_roughness.png",
):
    assert (root / "assets/textures" / texture).is_file(), texture

assert len(doc.get("skins", [])) == 1
assert len(doc.get("animations", [])) == 10
main_script = (root / "scripts/main.gd").read_text()
assert "wing_detail_texture" in main_script and "cuticle_detail_texture" in main_script
assert "femur_shape" in main_script and "spine_i" in main_script
print("mantis refinement check passed: paired leaf wings, texture UVs, raptorial legs, skin, and 10 clips")
