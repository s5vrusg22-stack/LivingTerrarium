from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text()
project = (root / "project.godot").read_text()

assert 'renderer/rendering_method="gl_compatibility"' in project
assert "const AXIAL_STEPS := 64" in main
assert "const RADIAL_STEPS := 48" in main
assert "const AXIAL_STEPS := 40" in main
assert "const RADIAL_STEPS := 32" in main
assert "func _create_prothorax_volume(" in main
assert "LongProthoraxShell" in main
assert "item.name = \"VolumetricSegmentedAbdomen\"" in main
assert "func _create_triangular_head_volume(" in main
assert "TriangularCompoundEyeHeadShell" in main
assert "func _make_volumetric_wing_mesh(" in main
assert "var segments := 48" in main
assert "_make_volumetric_wing_mesh(segments, 18, side" in main
assert "var surface_size: int = (longitudinal_steps + 1) * row_width" in main
assert "indices.append_array(PackedInt32Array([a, d, b, d, c, b]))" in main
assert "func _create_wing_veins(" in main
assert "material.vertex_color_use_as_albedo = true" in main
assert 'wing_texture = load("res://assets/textures/mantis_wing_albedo.png")' in main
assert '_apply_pbr(wing_material, "mantis_wing")' in main
assert '"mantis_wing"' in main
assert "Color(0.67, 0.82, 0.53)" in main
assert "CLIMB_BODY_CLEARANCE := 0.205" in main
assert "_walkable_wood(self, climb_branch_start, climb_branch_end, 0.145)" in main
assert "var roam_pause_time := 2.4" in main
assert 'behavior = "잠시 멈춰 주변 관찰"' in main
assert "roam_speed = move_toward(roam_speed, target_speed, dt * 0.060)" in main
assert "climb_midpoint_pause_used" in main
assert all(key in main for key in ["KEY_LEFT", "KEY_RIGHT", "KEY_UP", "KEY_DOWN"])
assert all(key in main for key in ["KEY_W", "KEY_A", "KEY_S", "KEY_D", "KEY_Q", "KEY_E"])
assert "CAMERA_MAX_DISTANCE := 22.0" in main
assert "Vector3(7.2, 5.8, 0.06)" in main
assert "box_shape.size = Vector3(7.2, 0.2, 5.2)" in main
assert "for y in [-0.53, 5.20]" in main
assert "for vine_index in range(18):" in main
assert "for leaf_index in range(9):" in main
assert "_create_feeder_insect(prey, 0.70," in main

abdomen_vertices = (64 + 1) * (48 + 1) + 2
assert abdomen_vertices == 3187
wing_vertices = 2 * (48 + 1) * (18 + 1)
assert wing_vertices == 1862
prothorax_vertices = (40 + 1) * (32 + 1)
assert prothorax_vertices == 1353
head_vertices = (32 + 1) * (36 + 1)
assert head_vertices == 1221

texture_dir = root / "assets/textures"
for map_name in ["albedo", "normal", "roughness"]:
    texture_path = texture_dir / f"mantis_wing_{map_name}.png"
    with Image.open(texture_path) as texture:
        assert texture.size == (1024, 1024)
        assert texture.mode in ("RGB", "L")
assert "build_wing_maps()" in (root / "tools/generate_mantis_cuticle_texture.py").read_text()
print(f"Reference model checks passed: {head_vertices} head, {abdomen_vertices} abdomen, {prothorax_vertices} pronotum, {wing_vertices} wing vertices, with 1024px cuticle and wing maps.")
