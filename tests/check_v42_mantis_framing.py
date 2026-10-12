import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text()
assert "const HABITAT_LINEAR_SCALE := 1.71" in main
assert "const HABITAT_WIDTH := 9.6 * HABITAT_LINEAR_SCALE" in main
assert "const HABITAT_DEPTH := 6.8 * HABITAT_LINEAR_SCALE" in main
assert "const HABITAT_CEILING_Y := 3.45 * HABITAT_LINEAR_SCALE" in main
assert "orbit_yaw = 1.43 if close_view else 0.0" in main
assert "orbit_distance = 2.80" in main
assert "1.18 + growth * 0.45" in main
assert "mat.albedo_color = Color(0.43, 0.54, 0.26)" in main
assert "_box(Vector3(HABITAT_WIDTH, HABITAT_WALL_HEIGHT, 0.06)" in main
assert "randf_range(-ROAM_HALF_X, ROAM_HALF_X)" in main
assert "clampf(animal.position.x, -ROAM_HALF_X, ROAM_HALF_X)" in main
assert 'part.name.begins_with("ForeFemur_")' not in main
assert "play_front_leg_animation(selected_frontleg_animation)" in main

bank = json.loads((root / "assets/animations/front_leg_100.json").read_text(encoding="utf-8"))
assert len(bank["animations"]) == 100
assert (root / "assets/reference/mantis_side_reference.png").is_file()
assert (root / "README_v4.1.md").is_file()
assert "README_v8.1.md" in (root / "README.md").read_text()
print("legacy v4.2 regression check passed against the V8 full-project mantis and enclosure")
