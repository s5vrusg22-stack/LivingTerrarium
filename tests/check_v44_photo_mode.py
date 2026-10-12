from hashlib import sha256
from pathlib import Path


root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text()
aquarium = (root / "scripts/aquarium_system.gd").read_text()
interactions = (root / "scripts/habitat_interactions.gd").read_text()
photo = root / "assets/reference/1000157363(3).jpg"

assert photo.is_file()
assert sha256(photo.read_bytes()).hexdigest() == (
    "8f877b0905b4bac7270e42ef318ebeed549717cbda18b38c6d2a7fc77e4b7948"
)
assert "var use_photo_visual := false" in main
assert "_initialize_photo_visual()" in main
assert "_set_species_mode(0, false)" in main
assert 'photo_visual.name = "LatestMantisSidePhotoCutout"' in main
assert 'preload("res://assets/photo_cutouts/mantis_side_photo.png")' in main
assert 'preload("res://assets/photo_cutouts/mantis_dorsal_photo.png")' in main
assert "photo_visual.billboard = BaseMaterial3D.BILLBOARD_ENABLED" in main
assert "photo_visual_dorsal.rotation_degrees.x = -90.0" in main
assert "use_latest_mantis_visual := false" in main
assert "_update_photo_visual(0.0 if simulation_paused else minf(delta, 0.1))" in main
assert '_button(mantis_controls, "첨부 사진 보기 / 3D 복귀"' in main
assert '_button(mantis_controls, "실물 사진과 구조 비교"' in main
assert "var show_photo := use_photo_visual and photo_visual != null" in main
assert 'behavior = "원본 사진 정지 관찰"' in main
assert "var crayfish_cycle := 0" in aquarium
assert "var spot_x: float =" in aquarium
assert "var parent_id: int =" in interactions
assert "var diff: Vector3 = prey.position - other.position" in interactions
assert "README_v4.3.md" in (root / "README.md").read_text()
assert (root / "assets/reference/mantis_side_reference.png").is_file()
assert (root / "assets/animations/front_leg_100.json").is_file()
print("v4.4 photo-mode integration checks passed")
