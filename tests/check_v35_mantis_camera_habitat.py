from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "tools"))
import upgrade_mantis_glb as glb


doc, binary = glb.read_glb(root / "assets/models/mantis_rigged.glb")
assert doc["asset"]["extras"]["reference_mantis_refinement"] in {"photo_proportions_v6", "photo_proportions_v7_80_detail", "photo_proportions_v8_forelegs_100", "photo_proportions_v10_photo_forelegs_100", "photo_proportions_v11_two_hinge_forelegs_slim_pronotum", "photo_proportions_v12_long_neck_attached_two_hinge_forelegs", "photo_proportions_v13_prominent_long_coxa", "photo_proportions_v14_forelegs_front_back_flipped"}
meshes = {mesh.get("name"): mesh for mesh in doc.get("meshes", [])}

for side in "LR":
    mesh = meshes[f"Wing_{side}"]
    attributes = mesh["primitives"][0]["attributes"]
    position_index = attributes["POSITION"]
    points = glb.read_vectors(doc, binary, position_index)
    assert "TEXCOORD_0" in attributes
    uv = doc["accessors"][attributes["TEXCOORD_0"]]
    assert uv["type"] == "VEC2" and uv["count"] == len(points)
    assert uv["min"][0] >= 0.0 and uv["max"][0] <= 1.0
    assert uv["min"][1] >= 0.0 and uv["max"][1] <= 1.0
    mid = [p[0] for p in points if abs(p[2]) < 0.35]
    ends = [p[0] for p in points if abs(p[2]) > 0.41]
    assert max(mid) - min(mid) > (max(ends) - min(ends)) * 1.35
    assert "NORMAL" in attributes
assert doc["asset"]["extras"]["mantis_v6_geometry"]["wing_length_segments"] == 80

for side in "LR":
    assert meshes[f"ForeFemur_{side}"]["primitives"][0]["attributes"].get("JOINTS_0") is not None
    assert meshes[f"ForeTibia_{side}"]["primitives"][0]["attributes"].get("WEIGHTS_0") is not None
assert len(doc.get("skins", [])) == 1 and len(doc.get("animations", [])) == 10

for name in ("foliage_albedo.png", "foliage_normal.png", "foliage_roughness.png"):
    assert (root / "assets/textures" / name).is_file(), name

main = (root / "scripts/main.gd").read_text()
pose = (root / "scripts/rigged_pose_driver.gd").read_text()
assert "Vector3(HABITAT_WIDTH, 0.2, HABITAT_DEPTH)" in main
assert "SurfaceTool.new()" in main and "foliage_normal_texture" in main
assert "orbit_distance := 3.15" in main and "follow_animal := true" in main
assert "clampf(orbit_pitch + motion.y * 0.006, -1.52, 1.52)" in main
assert "var habitat_size := _current_habitat_size()" in main and "habitat_framing = not close_view" in main
assert "_set_camera_preset(true)" in main and "_set_camera_preset(false)" in main
assert "1.18 + growth * 0.45" in main
assert '"Rig_Abdomen"' in pose and "torso_breath" in pose and "antenna_sway" in pose
print("v3.7 integration check passed: 80-step wings, raptorial limbs, textured foliage, body sway, closer camera, and larger habitat")
