from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text()
project = (root / "project.godot").read_text()

assert "window/handheld/orientation=0" in project, "Android should start in landscape"
assert 'zoom_in.text = "+"' in main and 'zoom_out.text = "−"' in main
assert "func _set_camera_zoom(" in main and "InputEventScreenDrag" in main
assert "CAMERA_MIN_DISTANCE" in main and "CAMERA_MAX_DISTANCE" in main

assert "for i in range(2):" in main
assert 'joint.name = "WalkingLeg_%d_%d"' in main
assert 'foreleg.name = "RaptorialForeleg_%d"' in main
assert "tarsomeres: Array[MeshInstance3D]" in main
assert "range(5):" in main and 'tarsal_claw.name = "TarsalClaw_' in main
assert "func _create_mantis_wing(" in main
assert '"HindwingPivot" if hindwing else "ForewingPivot"' in main
assert 'wing_pivots.append(wing_pivot)' in main and 'wing_pivot.rotation.z' in main
assert "BaseMaterial3D.TRANSPARENCY_ALPHA" in main
assert "surface_factor" in main and "for facet in range(14):" in main
assert "Antenna_%d" in main and "ocellus_side" in main
assert "Color(0.46, 0.74, 0.61)" in main

assert "plant_clusters[rng.randi_range" in main
assert "branch_clusters[branch_rng.randi_range" in main
assert "litter_clusters[rng.randi_range" in main
assert "Vector2(0.22, -0.98)" in main

assert (root / "scenes/main.tscn").exists()
assert len(list((root / "assets/textures").glob("*.png"))) >= 15
print("Mantid/habitat and landscape zoom source checks passed (not an engine runtime test).")
