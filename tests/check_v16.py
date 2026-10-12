from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text()
project = (root / "project.godot").read_text()

assert "window/handheld/orientation=0" in project, "Android should start in landscape"
assert 'zoom_in.text = "+"' in main and 'zoom_out.text = "−"' in main
assert "func _set_camera_zoom(" in main and "InputEventScreenDrag" in main
assert all(key in main for key in ["KEY_LEFT", "KEY_RIGHT", "KEY_UP", "KEY_DOWN", "KEY_W", "KEY_A", "KEY_S", "KEY_D"])
assert "CAMERA_MIN_DISTANCE" in main and "CAMERA_MAX_DISTANCE" in main
assert "Vector3(6.4, 0.2, 4.8)" in main and "Vector3(6.4, 3.8, 0.06)" in main, "Enclosure should be wide and tall"
assert "animal.scale = Vector3.ONE * (0.42 * (0.90 + growth * 0.30))" in main
assert "orbit_distance := 6.4" in main and "CAMERA_MAX_DISTANCE := 17.0" in main

assert "for i in range(2):" in main
assert 'joint.name = "WalkingLeg_%d_%d"' in main
assert 'foreleg.name = "RaptorialForeleg_%d"' in main
assert "tarsomeres: Array[MeshInstance3D]" in main
assert "range(5):" in main and 'tarsal_claw.name = "TarsalClaw_' in main
assert "func _create_mantis_wing(" in main
assert "func _create_abdomen_volume(" in main and "VolumetricSegmentedAbdomen" in main
assert "func _make_volumetric_wing_mesh(" in main and "func _volumetric_wing_point(" in main
assert '"HindwingPivot" if hindwing else "ForewingPivot"' in main
assert 'wing_pivots.append(wing_pivot)' in main and 'wing_pivot.rotation.z' in main
assert "BaseMaterial3D.TRANSPARENCY_ALPHA" in main
assert "surface_factor" in main and "for facet in range(42):" in main
assert "Antenna_%d" in main and "ocellus_side" in main
assert "var mint := Color(0.42, 0.60, 0.24)" in main

assert "plant_clusters[rng.randi_range" in main
assert "branch_clusters[branch_rng.randi_range" in main
assert "litter_clusters[rng.randi_range" in main
assert "for i in range(56):" in main and "FernFrond_%d" in main
assert "for i in range(168):" in main
assert "for vine_index in range(12):" in main
assert "CLIMB_BODY_CLEARANCE := 0.190" in main and "_walkable_wood(self, climb_branch_start, climb_branch_end, 0.132)" in main
assert "var roam_pause_time := 1.6" in main and "roam_pause_time = randf_range(1.8, 4.0)" in main
assert "Vector2(-2.22, -1.46)" in main
assert "var stations := 24" in main and "for vein_index in range(25):" in main

assert (root / "scenes/main.tscn").exists()
assert len(list((root / "assets/textures").glob("*.png"))) >= 15
print("Mantid/habitat and landscape zoom source checks passed (not an engine runtime test).")
