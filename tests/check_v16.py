from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text()
project = (root / "project.godot").read_text()

assert "window/handheld/orientation=0" in project, "Android should start in landscape"
assert 'zoom_in.text = "+"' in main and 'zoom_out.text = "−"' in main
assert "func _set_camera_zoom(" in main and "InputEventScreenDrag" in main
assert "CAMERA_MIN_DISTANCE" in main and "CAMERA_MAX_DISTANCE" in main
assert "Vector3(5.2, 0.2, 3.8)" in main, "Keep enough enclosure space around the larger mantis"
assert "const BASE_MANTIS_SCALE := 0.60" in main
assert "animal.scale = Vector3.ONE * (BASE_MANTIS_SCALE * (0.80 + growth * 0.30))" in main
assert "orbit_distance := 4.45" in main and "CAMERA_MAX_DISTANCE := 16.0" in main
assert "orbit_distance = 4.45" in main, "Camera reset should match the larger default mantis framing"

assert "for i in range(2):" in main
assert 'joint.name = "WalkingLeg_%d_%d"' in main
assert 'foreleg.name = "RaptorialForeleg_%d"' in main
assert "tarsomeres: Array[MeshInstance3D]" in main
assert "range(5):" in main and 'tarsal_claw.name = "TarsalClaw_' in main
assert "func _create_mantis_wing(" in main
assert "var max_width: float = 0.42 if hindwing else 0.215" in main
assert "gait_joints.append([hip_joint, knee_joint, ankle_joint])" in main
assert "leg_spurs.append(tibial_spurs)" in main
assert "counter_sway * 0.045" in main and "gait_sway * 0.070" in main
assert '"HindwingPivot" if hindwing else "ForewingPivot"' in main
assert 'wing_pivots.append(wing_pivot)' in main and 'wing_pivot.rotation.z' in main
assert "BaseMaterial3D.TRANSPARENCY_ALPHA" in main
assert "surface_factor" in main and "for facet in range(14):" in main
assert "Antenna_%d" in main and "ocellus_side" in main
assert "Color(0.42, 0.60, 0.24)" in main

assert "plant_clusters[rng.randi_range" in main
assert "branch_clusters[branch_rng.randi_range" in main
assert "litter_clusters[rng.randi_range" in main
assert "for i in range(56):" in main and "FernFrond_%d" in main
assert "for i in range(216):" in main
assert "for vine_index in range(11):" in main
assert "Vector2(-2.22, -1.46)" in main
assert "var longitudinal_stations := 28" in main and "var lateral_stations := 24" in main
assert "for vein_index in range(21):" in main
assert "sun.directional_shadow_max_distance = 7.5" in main
assert "env.tonemap_mode = Environment.TONE_MAPPER_FILMIC" in main
assert "leaf_mesh_cache[variant] = mesh" in main
assert "TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC" in main
assert "textures/default_filters/anisotropic_filtering_level=3" in project

assert (root / "scenes/main.tscn").exists()
assert len(list((root / "assets/textures").glob("*.png"))) >= 15
print("Mantid/habitat and landscape zoom source checks passed (not an engine runtime test).")

