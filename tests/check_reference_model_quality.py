from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text()
project = (root / "project.godot").read_text()

assert 'renderer/rendering_method="gl_compatibility"' in project
assert "const AXIAL_STEPS := 48" in main
assert "const RADIAL_STEPS := 36" in main
assert "func _create_prothorax_volume(" in main
assert "LongProthoraxShell" in main
assert "item.name = \"VolumetricSegmentedAbdomen\"" in main
assert "func _make_volumetric_wing_mesh(" in main
assert "var surface_size: int = (longitudinal_steps + 1) * row_width" in main
assert "indices.append_array(PackedInt32Array([a, d, b, d, c, b]))" in main
assert "func _create_wing_veins(" in main
assert "material.vertex_color_use_as_albedo = true" in main
assert 'wing_texture = load("res://assets/textures/mantis_wing_albedo.png")' in main
assert '_apply_pbr(wing_material, "mantis_wing")' in main
assert '"mantis_wing"' in main
assert "Color(0.67, 0.82, 0.53)" in main
assert "CLIMB_BODY_CLEARANCE := 0.190" in main
assert "_walkable_wood(self, climb_branch_start, climb_branch_end, 0.132)" in main
assert "var roam_pause_time := 1.6" in main
assert 'behavior = "잠시 멈춰 주변 관찰"' in main
assert "roam_speed = move_toward(roam_speed, target_speed, dt * 0.075)" in main
assert all(key in main for key in ["KEY_LEFT", "KEY_RIGHT", "KEY_UP", "KEY_DOWN"])
assert all(key in main for key in ["KEY_W", "KEY_A", "KEY_S", "KEY_D", "KEY_Q", "KEY_E"])
assert "CAMERA_MAX_DISTANCE := 17.0" in main
assert "Vector3(6.4, 3.8, 0.06)" in main
assert "for vine_index in range(12):" in main
assert "for leaf_index in range(7):" in main
assert "_create_feeder_insect(prey, 0.70," in main

abdomen_vertices = (48 + 1) * (36 + 1) + 2
assert abdomen_vertices == 1815
wing_vertices = 2 * (32 + 1) * (12 + 1)
assert wing_vertices == 858
prothorax_vertices = (32 + 1) * (24 + 1)
assert prothorax_vertices == 825

texture_dir = root / "assets/textures"
for map_name in ["albedo", "normal", "roughness"]:
    texture_path = texture_dir / f"mantis_wing_{map_name}.png"
    with Image.open(texture_path) as texture:
        assert texture.size == (512, 512)
        assert texture.mode in ("RGB", "L")
assert "build_wing_maps()" in (root / "tools/generate_mantis_cuticle_texture.py").read_text()
print(f"Reference model checks passed: {abdomen_vertices} abdomen vertices, {prothorax_vertices} pronotum vertices, {wing_vertices} vertices per wing, and three 512px wing maps.")
