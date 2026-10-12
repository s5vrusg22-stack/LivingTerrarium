from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "tools"))
import upgrade_mantis_glb as glb

doc, binary = glb.read_glb(root / "assets/models/mantis_rigged.glb")
extras = doc.get("asset", {}).get("extras", {})
assert extras.get("reference_mantis_refinement") in {"photo_proportions_v3", "photo_proportions_v4", "photo_proportions_v5", "photo_proportions_v6", "photo_proportions_v7_80_detail", "photo_proportions_v8_forelegs_100", "photo_proportions_v10_photo_forelegs_100", "photo_proportions_v11_two_hinge_forelegs_slim_pronotum", "photo_proportions_v12_long_neck_attached_two_hinge_forelegs", "photo_proportions_v13_prominent_long_coxa", "photo_proportions_v14_forelegs_front_back_flipped"}
meshes = {mesh.get("name"): mesh for mesh in doc.get("meshes", [])}


def dimensions(name):
    mesh = meshes[name]
    accessor = mesh["primitives"][0]["attributes"]["POSITION"]
    points = glb.read_vectors(doc, binary, accessor)
    return tuple(max(point[axis] for point in points) - min(point[axis] for point in points) for axis in range(3))


abdomen = dimensions("Abdomen")
wing = dimensions("Wing_L")
thorax = dimensions("Thorax")
assert wing[2] > abdomen[2] * 1.08, (wing, abdomen)
wing_nodes = {node.get("name"): node for node in doc["nodes"] if node.get("name") in {"Wing_L", "Wing_R"}}
wing_centers = []
for side in "LR":
    node = wing_nodes[f"Wing_{side}"]
    transform = node.get("matrix")
    wing_centers.append(transform[12] if transform else node.get("translation", [0.0])[0])
paired_span = max(center + wing[0] * 0.5 for center in wing_centers) - min(center - wing[0] * 0.5 for center in wing_centers)
if extras.get("reference_mantis_refinement") in {"photo_proportions_v11_two_hinge_forelegs_slim_pronotum", "photo_proportions_v12_long_neck_attached_two_hinge_forelegs", "photo_proportions_v13_prominent_long_coxa", "photo_proportions_v14_forelegs_front_back_flipped"}:
    extents = []
    for side in "LR":
        points = glb.read_vectors(doc, binary, meshes[f"Wing_{side}"]["primitives"][0]["attributes"]["POSITION"])
        center = wing_centers["LR".index(side)]
        extents.append((min(p[0] for p in points) + center, max(p[0] for p in points) + center))
    paired_span = max(extent[1] for extent in extents) - min(extent[0] for extent in extents)
    assert paired_span > abdomen[0] * 1.10, (paired_span, abdomen)
    assert 0.09 < thorax[0] < 0.105 and 0.10 < thorax[1] < 0.13 and thorax[2] > 0.73, thorax
elif "photo_reference_profile_v9" in extras:
    extents = []
    for side in "LR":
        points = glb.read_vectors(doc, binary, meshes[f"Wing_{side}"]["primitives"][0]["attributes"]["POSITION"])
        center = wing_centers["LR".index(side)]
        extents.append((min(p[0] for p in points) + center, max(p[0] for p in points) + center))
    paired_span = max(extent[1] for extent in extents) - min(extent[0] for extent in extents)
    assert paired_span > abdomen[0] * 1.10, (paired_span, abdomen)
    assert 0.115 < thorax[0] < 0.13 and thorax[2] > 0.73, thorax
elif extras.get("reference_mantis_refinement") in {"photo_proportions_v6", "photo_proportions_v7_80_detail", "photo_proportions_v8_forelegs_100", "photo_proportions_v10_photo_forelegs_100", "photo_proportions_v11_two_hinge_forelegs_slim_pronotum", "photo_proportions_v12_long_neck_attached_two_hinge_forelegs", "photo_proportions_v13_prominent_long_coxa", "photo_proportions_v14_forelegs_front_back_flipped"}:
    extents = []
    for side in "LR":
        points = glb.read_vectors(doc, binary, meshes[f"Wing_{side}"]["primitives"][0]["attributes"]["POSITION"])
        center = wing_centers["LR".index(side)]
        extents.append((min(p[0] for p in points) + center, max(p[0] for p in points) + center))
    paired_span = max(extent[1] for extent in extents) - min(extent[0] for extent in extents)
    assert abdomen[0] * .90 < paired_span < abdomen[0] * 1.05, (paired_span, abdomen)
    assert 0.10 < thorax[0] < 0.13 and thorax[2] > 0.64, thorax
else:
    assert paired_span > abdomen[0] * 1.18, (paired_span, abdomen)
    assert thorax[0] > 0.14 and thorax[2] > 0.64, thorax
for side in "LR":
    assert dimensions(f"Wing_{side}") == wing
    if extras.get("reference_mantis_refinement") in {"photo_proportions_v4", "photo_proportions_v5", "photo_proportions_v6", "photo_proportions_v7_80_detail", "photo_proportions_v8_forelegs_100", "photo_proportions_v10_photo_forelegs_100", "photo_proportions_v11_two_hinge_forelegs_slim_pronotum", "photo_proportions_v12_long_neck_attached_two_hinge_forelegs", "photo_proportions_v13_prominent_long_coxa", "photo_proportions_v14_forelegs_front_back_flipped"}:
        attrs = meshes[f"Wing_{side}"]["primitives"][0]["attributes"]
        assert "TEXCOORD_0" in attrs
    if extras.get("reference_mantis_refinement") in {"photo_proportions_v11_two_hinge_forelegs_slim_pronotum", "photo_proportions_v12_long_neck_attached_two_hinge_forelegs", "photo_proportions_v13_prominent_long_coxa", "photo_proportions_v14_forelegs_front_back_flipped"}:
        assert max(dimensions(f"ForeFemur_{side}")) > 0.24
        assert max(dimensions(f"ForeTibia_{side}")) > 0.27
    else:
        assert dimensions(f"ForeFemur_{side}")[0] > 0.24
        assert dimensions(f"ForeTibia_{side}")[1] > 0.24
    for mesh_name in (f"ForeFemur_{side}", f"ForeTibia_{side}"):
        attrs = meshes[mesh_name]["primitives"][0]["attributes"]
        assert "JOINTS_0" in attrs and "WEIGHTS_0" in attrs

assert len(doc.get("skins", [])) == 1
assert len(doc.get("animations", [])) == 10
print("v3.3 mantis proportions pass: wings, pronotum, forelegs, skinning, and 10 clips verified")
